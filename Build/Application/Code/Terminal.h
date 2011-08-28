/*!	\file Terminal.h
	\brief Terminal screen buffer and emulators.
	
	MacTerm splits terminals into two primary concepts.  The
	first is the Screen, which this file implements, consisting
	of a screen buffer and underlying emulator that parses all
	data inserted into the terminal.  The second is the View
	(see TerminalView.h), which is essentially the one or more
	Mac OS window controls that render a terminal screen.
	
	Simply put, a Screen drives the back-end, and a View drives
	the front-end.  There is no longer any practical limit on
	how many views can share a screen buffer, or vice-versa, so
	this will enable features like split-pane views and windows
	that can dump more than one session’s terminal output.
*/
/*###############################################################

	MacTerm
		© 1998-2011 by Kevin Grant.
		© 2001-2003 by Ian Anderson.
		© 1986-1994 University of Illinois Board of Trustees
		(see About box for full list of U of I contributors).
	
	This program is free software; you can redistribute it or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version
	2 of the License, or (at your option) any later version.
	
	This program is distributed in the hope that it will be
	useful, but WITHOUT ANY WARRANTY; without even the implied
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	PURPOSE.  See the GNU General Public License for more
	details.
	
	You should have received a copy of the GNU General Public
	License along with this program; if not, write to:
	
		Free Software Foundation, Inc.
		59 Temple Place, Suite 330
		Boston, MA  02111-1307
		USA

###############################################################*/

#include "UniversalDefines.h"

#ifndef __TERMINAL__
#define __TERMINAL__

// standard-C++ includes
#include <vector>

// library includes
#include "ListenerModel.h"

// application includes
#include "Preferences.h"
#include "SessionRef.typedef.h"
#include "TerminalSpeaker.h"
#include "TerminalTextAttributes.typedef.h"
#include "VTKeys.h"



#pragma mark Constants

/*!
Possible return values from certain APIs in this module.
*/
enum Terminal_Result
{
	kTerminal_ResultOK = 0,						//!< no error
	kTerminal_ResultInvalidID = -1,				//!< a given "TerminalScreenRef" does not correspond to any known screen
	kTerminal_ResultInvalidIterator = -2,		//!< a given "Terminal_LineRef" does not correspond to any known row
	kTerminal_ResultParameterError = -3,		//!< invalid input (e.g. a null pointer)
	kTerminal_ResultNotEnoughMemory = -4,		//!< there is not enough memory to allocate required data structures
	kTerminal_ResultIteratorCannotAdvance = -5,	//!< attempt to advance iterator past the end of its list
	kTerminal_ResultNoListeningSession = -6,	//!< cannot send result anywhere because no session is currently listening
};

/*!
Setting changes that MacTerm allows other modules to “listen” for, via
Terminal_StartMonitoring().
*/
typedef FourCharCode Terminal_Change;
enum
{
	kTerminal_ChangeAudioEvent			= 'Bell',	//!< terminal bell triggered (context: TerminalScreenRef)
	kTerminal_ChangeAudioState			= 'BEnD',	//!< terminal bell enabled or disabled (context: TerminalScreenRef);
													//!  use Terminal_BellIsEnabled() to determine the new state
	kTerminal_ChangeCursorLocation		= 'Curs',	//!< cursor has moved; new position can be found with
													//!  Terminal_CursorGetLocation() (context:
													//!  TerminalScreenRef)
	kTerminal_ChangeCursorState			= 'CurV',	//!< cursor has been shown or hidden; new state can be
													//!  found with Terminal_CursorIsVisible() (context:
													//!  TerminalScreenRef)
	kTerminal_ChangeExcessiveErrors		= 'Errr',	//!< a very exceptional number of data errors have now occurred;
													//!  this message is sent just once, if ever, at an arbitrary time,
													//!  and is intended to allow a user warning (context:
													//!  TerminalScreenRef)
	kTerminal_ChangeFileCaptureBegun	= 'CapB',	//!< file capture started (context: TerminalScreenRef)
	kTerminal_ChangeFileCaptureEnding	= 'CapE',	//!< capture about to stop (context: TerminalScreenRef)
	kTerminal_ChangeLineFeedNewLineMode	= 'LFNL',	//!< terminal has changed the expected behavior of the
													//!  Return key; use Terminal_LineFeedNewLineMode()
													//!  to determine the new mode (context: TerminalScreenRef)
	kTerminal_ChangeNewLEDState			= 'LEDS',	//!< the state of at least one LED in a monitored
													//!  Terminal has changed (context: TerminalScreenRef)
	kTerminal_ChangeReset				= 'Rset',	//!< terminal was explicitly reset (context:
													//!  TerminalScreenRef)
	kTerminal_ChangeScreenSize			= 'SSiz',	//!< number of columns or rows has changed
													//!  (context: TerminalScreenRef)
	kTerminal_ChangeScrollActivity		= '^v<>',	//!< screen or scrollback changes that would affect a scroll bar
													//!  have occurred (context: Terminal_ScrollDescriptionConstPtr)
	kTerminal_ChangeTextEdited			= 'UpdT',	//!< text has changed, requiring an update (context:
													//!  Terminal_RangeDescriptionConstPtr)
	kTerminal_ChangeTextRemoved			= 'DelT',	//!< scrollback text is about to be completely destroyed (context:
													//!  Terminal_RangeDescriptionConstPtr)
	kTerminal_ChangeVideoMode			= 'RevV',	//!< terminal has toggled between normal and reverse
													//!  video modes; use Terminal_ReverseVideoIsEnabled()
													//!  to determine the new mode (context: TerminalScreenRef)
	kTerminal_ChangeWindowFrameTitle	= 'WinT',	//!< terminal received a new title meant for its window;
													//!  use Terminal_CopyTitleForWindow() to determine title
													//!  (context: TerminalScreenRef)
	kTerminal_ChangeWindowIconTitle		= 'IcnT',	//!< terminal received a new title meant for its icon;
													//!  use Terminal_CopyTitleForIcon() to determine title
													//!  (context: TerminalScreenRef)
	kTerminal_ChangeWindowMinimization	= 'MnmR',	//!< terminal received a request to minimize or restore;
													//!  use Terminal_WindowIsToBeMinimized() for more info
													//!  (context: TerminalScreenRef)
	kTerminal_ChangeXTermColor			= 'XTCl'	//!< a new value has been set for some color in the table of 256
													//!  XTerm colors (context: Terminal_XTermColorDescriptionConstPtr)
};

#ifndef REZ
typedef UInt32 Terminal_Emulator;
typedef UInt32 Terminal_EmulatorType; // part of Terminal_Emulator
typedef UInt32 Terminal_EmulatorVariant; // part of Terminal_Emulator
#endif

enum
{
	// These masks chop up the 16-bit emulator type into two parts,
	// the terminal type and the variant of it; this allows up to 256
	// terminal types, and 256 variants (for example, VT is a type,
	// and VT100 and VT220 are variants of the VT terminal type).
	//
	// Standardizing on this approach will make it *much* easier to
	// implement future terminal types - for example, many variants
	// of terminals share identical features, so you can check if
	// ANY variant of a particular terminal is in use just by
	// isolating the upper byte.  For convenience, two macros below
	// are included to isolate the upper or lower byte for you.
	// Use them!!!
	kTerminal_EmulatorTypeByteShift		= 8,
	kTerminal_EmulatorTypeMask			= (0x000000FF << kTerminal_EmulatorTypeByteShift),
	kTerminal_EmulatorVariantByteShift	= 0,
	kTerminal_EmulatorVariantMask		= (0x000000FF << kTerminal_EmulatorVariantByteShift)
};
enum
{
	// use these constants only when you need to determine the terminal emulator family
	// (and if you add support for new terminal types, add constants to this list in
	// the same way as shown below)
	kTerminal_EmulatorTypeVT = ((0 << kTerminal_EmulatorTypeByteShift) & kTerminal_EmulatorTypeMask),
		kTerminal_EmulatorVariantVT100 = ((0x00 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantVT102 = ((0x01 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantVT220 = ((0x02 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantVT320 = ((0x03 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantVT420 = ((0x04 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
	kTerminal_EmulatorTypeXTerm = ((1 << kTerminal_EmulatorTypeByteShift) & kTerminal_EmulatorTypeMask),
		kTerminal_EmulatorVariantXTermOriginal = ((0x00 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantXTermColor = ((0x01 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantXTerm256Color = ((0x02 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
	kTerminal_EmulatorTypeDumb = ((2 << kTerminal_EmulatorTypeByteShift) & kTerminal_EmulatorTypeMask),
		kTerminal_EmulatorVariantDumb1 = ((0x00 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
	kTerminal_EmulatorTypeANSI = ((3 << kTerminal_EmulatorTypeByteShift) & kTerminal_EmulatorTypeMask),
		kTerminal_EmulatorVariantANSIBBS = ((0x00 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask),
		kTerminal_EmulatorVariantANSISCO = ((0x01 << kTerminal_EmulatorVariantByteShift) & kTerminal_EmulatorVariantMask)
};
enum
{
	// refer to a terminal type using these simpler constants
	kTerminal_EmulatorANSIBBS = kTerminal_EmulatorTypeANSI | kTerminal_EmulatorVariantANSIBBS,				// PC (“ANSI”) terminals
	kTerminal_EmulatorANSISCO = kTerminal_EmulatorTypeANSI | kTerminal_EmulatorVariantANSISCO,
	kTerminal_EmulatorVT100 = kTerminal_EmulatorTypeVT | kTerminal_EmulatorVariantVT100,					// VT terminals
	kTerminal_EmulatorVT102 = kTerminal_EmulatorTypeVT | kTerminal_EmulatorVariantVT102,
	kTerminal_EmulatorVT220 = kTerminal_EmulatorTypeVT | kTerminal_EmulatorVariantVT220,
	kTerminal_EmulatorVT320	= kTerminal_EmulatorTypeVT | kTerminal_EmulatorVariantVT320,
	kTerminal_EmulatorVT420 = kTerminal_EmulatorTypeVT | kTerminal_EmulatorVariantVT420,
	kTerminal_EmulatorXTermOriginal = kTerminal_EmulatorTypeXTerm | kTerminal_EmulatorVariantXTermOriginal,	// xterm terminals
	kTerminal_EmulatorXTermColor = kTerminal_EmulatorTypeXTerm | kTerminal_EmulatorVariantXTermColor,
	kTerminal_EmulatorXTerm256Color = kTerminal_EmulatorTypeXTerm | kTerminal_EmulatorVariantXTerm256Color,
	kTerminal_EmulatorDumb = kTerminal_EmulatorTypeDumb | kTerminal_EmulatorVariantDumb1					// “dumb” terminals
};

/*!
Controls Terminal_Reset().
*/
typedef UInt32 Terminal_ResetFlags;
enum
{
	kTerminal_ResetFlagsGraphicsCharacters  = (1 << 0),		//!< pass this value to reset only the active
															//!  character set; this is primarily used when
															//!  something screws up (either in MacTerm or
															//!  in the program using the terminal) that
															//!  leaves the screen rendered entirely
															//!  in the graphics character set
	kTerminal_ResetFlagsAll					= 0xFFFFFFFF	//!< pass this value to do a full reset
};

/*!
Controls over text-finding behavior.

The terminal is split into main screen and scrollback, and is
normally searched starting with the main screen (top to bottom)
and then the scrollback (newest to oldest).
*/
typedef UInt32 Terminal_SearchFlags;
enum
{
	kTerminal_SearchFlagsCaseSensitive		= (1 << 0),		//!< lowercase and uppercase letters not considered the same?
	kTerminal_SearchFlagsSearchBackwards	= (1 << 1),		//!< search oldest (topmost, offscreen) rows first?
};

/*!
How scrollback lines are allocated.
*/
enum Terminal_ScrollbackType
{
	kTerminal_ScrollbackTypeDisabled = 0,		//!< no lines are saved
	kTerminal_ScrollbackTypeFixed = 1,			//!< a specific number of rows is read from the preferences
	kTerminal_ScrollbackTypeUnlimited = 2,		//!< rows are allocated continuously, memory permitting
	kTerminal_ScrollbackTypeDistributed = 3		//!< allocations favor the active window and starve rarely-used windows
};

/*!
Controls over the computer’s voice when it is speaking text.
*/
enum Terminal_SpeechMode
{
	kTerminal_SpeechModeSpeakNever = 0,			//!< speech is disabled
	kTerminal_SpeechModeSpeakAlways = 1,		//!< no restrictions on speech
	kTerminal_SpeechModeSpeakWhenActive = 2,	//!< mute speech if the terminal window is not frontmost
	kTerminal_SpeechModeSpeakWhenInactive = 3	//!< mute speech if the terminal window is frontmost
};

/*!
Controls over text-copying behavior, given the ambiguity of
two end points.
*/
typedef UInt32 Terminal_TextCopyFlags;
enum
{
	kTerminal_TextCopyFlagsRectangular					= (1 << 0),		//!< only considers text within a rectangular area
	kTerminal_TextCopyFlagsAlwaysNewLineAtRightMargin	= (1 << 1)		//!< normally, the new-line sequence is skipped for
																		//!  any line where the copy area includes the right
																		//!  margin and the right margin character is not a
																		//!  whitespace character; set this flag to force
																		//!  new-line appendages in these cases
};

/*!
Controls over read-only ranges of text.
*/
typedef UInt32 Terminal_TextFilterFlags;
enum
{
	kTerminal_TextFilterFlagsNoEndWhitespace			= (1 << 0)		//!< skip all whitespace characters at the end of lines
};

#pragma mark Types

#include "TerminalScreenRef.typedef.h"

typedef struct Terminal_OpaqueLineIterator*		Terminal_LineRef;	//!< efficient access to an arbitrary screen line

#include "TerminalRangeDescription.typedef.h"

struct Terminal_ScrollDescription
{
	TerminalScreenRef	screen;				//!< the screen for which the scroll applies
	SInt16				rowDelta;			//!< less than zero (typical) if content scrolled upward by this
											//!  number of rows, moving lines into the scrollback or oblivion;
											//!  greater than zero if content scrolled downward and clipped
											//!  the bottom of the main screen; equal to zero if the scrollback
											//!  was modified in some unspecified way (e.g. being cleared)
};
typedef Terminal_ScrollDescription const*	Terminal_ScrollDescriptionConstPtr;

struct Terminal_XTermColorDescription
{
	TerminalScreenRef	screen;				//!< the screen for which the color applies
	UInt16				index;				//!< a number between 16 and 255 that indicates what changed
	UInt16				redComponent;		//!< part of the color value
	UInt16				greenComponent;		//!< part of the color value
	UInt16				blueComponent;		//!< part of the color value
};
typedef Terminal_XTermColorDescription const*	Terminal_XTermColorDescriptionConstPtr;

#pragma mark Callbacks

/*!
Screen Run Routine

This defines a function that can be used as an iterator
over all contiguous blocks of text in a virtual screen
that share *exactly* the same attributes.  The specified
text buffer (which is read-only) includes the contents of
the current chunk of text, whose starting column is also
given - assuming a renderer needs to know this.  The
specified text attributes apply to every character in the
chunk, and *include* any attributes that are actually
applied to the entire line (double-sized text, for
instance).

This callback acts on text chunks that are not necessarily
entire lines, and is guaranteed to be called with a series
of characters whose attributes all match.  The expectation
is that you are using this for rendering purposes.

IMPORTANT:  The line text buffer may be nullptr, and if it
			is, you should still pay attention to the
			length value; it implies a blank area of that
			many characters in length.
*/
typedef void (*Terminal_ScreenRunProcPtr)	(TerminalScreenRef			inScreen,
											 UniChar const*				inLineTextBufferOrNull,
											 UInt16						inLineTextBufferLength,
											 Terminal_LineRef			inRow,
											 UInt16						inZeroBasedStartColumnNumber,
											 TerminalTextAttributes		inAttributes,
											 void*						inContextPtr);
inline void
Terminal_InvokeScreenRunProc	(Terminal_ScreenRunProcPtr		inUserRoutine,
								 TerminalScreenRef				inScreen,
								 UniChar const*					inLineTextBufferOrNull,
								 UInt16							inLineTextBufferLength,
								 Terminal_LineRef				inRow,
								 UInt16							inZeroBasedStartColumnNumber,
								 TerminalTextAttributes			inAttributes,
								 void*							inContextPtr)
{
	(*inUserRoutine)(inScreen, inLineTextBufferOrNull, inLineTextBufferLength,
						inRow, inZeroBasedStartColumnNumber, inAttributes, inContextPtr);
}



#pragma mark Public Methods

//!\name Creating and Destroying Terminal Screen Buffers
//@{

Terminal_Result
	Terminal_NewScreen						(Preferences_ContextRef		inTerminalConfig,
											 Preferences_ContextRef		inTranslationConfig,
											 TerminalScreenRef*			outScreenPtr);

SInt16
	Terminal_DisposeScreen					(TerminalScreenRef			inScreen);

//@}

//!\name Enabling Session Talkback (Such As VT100 Device Attributes)
//@{

Terminal_Result
	Terminal_SetListeningSession			(TerminalScreenRef			inScreen,
											 SessionRef					inSession);

//@}

//!\name Creating and Destroying Terminal Screen Buffer Iterators
//@{

Terminal_LineRef
	Terminal_NewMainScreenLineIterator		(TerminalScreenRef			inScreen,
											 UInt16						inLineNumberZeroForTop);

Terminal_LineRef
	Terminal_NewScrollbackLineIterator		(TerminalScreenRef			inScreen,
											 UInt16						inLineNumberZeroForNewest);

void
	Terminal_DisposeLineIterator			(Terminal_LineRef*			inoutIteratorPtr);

//@}

//!\name Buffer Size
//@{

UInt16
	Terminal_ReturnAllocatedColumnCount		();

UInt16
	Terminal_ReturnColumnCount				(TerminalScreenRef			inScreen);

UInt32
	Terminal_ReturnInvisibleRowCount		(TerminalScreenRef			inScreen);

UInt16
	Terminal_ReturnRowCount					(TerminalScreenRef			inScreen);

Terminal_Result
	Terminal_SetVisibleScreenDimensions		(TerminalScreenRef			inScreen,
											 UInt16						inNewNumberOfCharactersWide,
											 UInt16						inNewNumberOfLinesHigh);

//@}

//!\name Buffer Iteration
//@{

Terminal_Result
	Terminal_ForEachLikeAttributeRunDo		(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 Terminal_ScreenRunProcPtr	inDoWhat,
											 void*						inContextPtr);

Terminal_Result
	Terminal_LineIteratorAdvance			(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 SInt16						inHowManyRowsForwardOrNegativeForBackward);

//@}

//!\name Buffer Search
//@{

Terminal_Result
	Terminal_Search							(TerminalScreenRef			inScreen,
											 CFStringRef				inQuery,
											 Terminal_SearchFlags		inFlags,
											 std::vector< Terminal_RangeDescription >&	outMatches);

//@}

//!\name Accessing Screen Data
//@{

Terminal_Result
	Terminal_ChangeLineAttributes			(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 TerminalTextAttributes		inAttributesToSet,
											 TerminalTextAttributes		inAttributesToClear);

Terminal_Result
	Terminal_ChangeLineRangeAttributes		(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 UInt16						inZeroBasedStartColumn,
											 SInt16						inZeroBasedPastTheEndColumnOrNegativeForLastColumn,
											 TerminalTextAttributes		inAttributesToSet,
											 TerminalTextAttributes		inAttributesToClear);

Terminal_Result
	Terminal_ChangeRangeAttributes			(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inStartRow,
											 UInt16						inNumberOfRowsToConsider,
											 UInt16						inZeroBasedStartColumn,
											 UInt16						inZeroBasedPastTheEndColumn,
											 Boolean					inConstrainToRectangle,
											 TerminalTextAttributes		inAttributesToSet,
											 TerminalTextAttributes		inAttributesToClear);

Terminal_Result
	Terminal_CopyLineRange					(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 UInt16						inZeroBasedStartColumn,
											 SInt16						inZeroBasedEndColumnOrNegativeForLastColumn,
											 char*						outBuffer,
											 SInt32						inBufferLength,
											 SInt32*					outActualLengthPtrOrNull,
											 UInt16						inNumberOfSpacesPerTabOrZeroForNoSubstitution);

Terminal_Result
	Terminal_CopyRange						(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inStartRow,
											 UInt16						inNumberOfRowsToConsider,
											 UInt16						inZeroBasedStartColumnOnFirstRow,
											 UInt16						inZeroBasedEndColumnOnLastRow,
											 char*						outBuffer,
											 SInt32						inBufferLength,
											 SInt32*					outActualLengthPtrOrNull,
											 char const*				inEndOfLineSequence,
											 SInt16						inNumberOfSpacesPerTabOrZeroForNoSubstitution,
											 Terminal_TextCopyFlags		inFlags);

OSStatus
	Terminal_CreateContentsAEDesc			(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inStartRow,
											 UInt16						inNumberOfRowsToConsider,
											 AEDesc*					outDescPtr);

void
	Terminal_DeleteAllSavedLines			(TerminalScreenRef			inScreen);

Terminal_Result
	Terminal_GetLineGlobalAttributes		(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 TerminalTextAttributes*	outAttributesPtr);

Terminal_Result
	Terminal_GetLine						(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 UniChar const*&			outReferenceStart,
											 UniChar const*&			outReferencePastEnd,
											 Terminal_TextFilterFlags	inFlags = 0);

Terminal_Result
	Terminal_GetLineRange					(TerminalScreenRef			inScreen,
											 Terminal_LineRef			inRow,
											 UInt16						inZeroBasedStartColumn,
											 SInt16						inZeroBasedPastEndColumnOrNegativeForLastColumn,
											 UniChar const*&			outReferenceStart,
											 UniChar const*&			outReferencePastEnd,
											 Terminal_TextFilterFlags	inFlags = 0);

//@}

//!\name Terminal State
//@{

Boolean
	Terminal_BellIsEnabled					(TerminalScreenRef			inScreen);

void
	Terminal_CopyTitleForIcon				(TerminalScreenRef			inRef,
											 CFStringRef&				outTitle);

void
	Terminal_CopyTitleForWindow				(TerminalScreenRef			inRef,
											 CFStringRef&				outTitle);

Terminal_Result
	Terminal_CursorGetLocation				(TerminalScreenRef			inScreen,
											 UInt16*					outZeroBasedColumnPtr,
											 UInt16*					outZeroBasedRowPtr);

Boolean
	Terminal_CursorIsVisible				(TerminalScreenRef			inScreen);

TerminalTextAttributes
	Terminal_CursorReturnAttributes			(TerminalScreenRef			inScreen);

Terminal_Result
	Terminal_EmulatorDeriveFromCString		(TerminalScreenRef			inScreen,
											 char const*				inCString,
											 Terminal_Emulator&			outApparentEmulator);

// DEPRECATED
Boolean
	Terminal_EmulatorIsVT100				(TerminalScreenRef			inScreen);

// DEPRECATED
Boolean
	Terminal_EmulatorIsVT220				(TerminalScreenRef			inScreen);

CFStringRef
	Terminal_EmulatorReturnDefaultName		(Terminal_Emulator			inEmulator);

Terminal_Emulator
	Terminal_EmulatorReturnForName			(CFStringRef				inName);

CFStringRef
	Terminal_EmulatorReturnName				(TerminalScreenRef			inScreen);

Terminal_Result
	Terminal_EmulatorSet					(TerminalScreenRef			inScreen,
											 Terminal_Emulator			inEmulator);

Boolean
	Terminal_LEDIsOn						(TerminalScreenRef			inScreen,
											 SInt16						inOneBasedLEDNumber);

void
	Terminal_LEDSetState					(TerminalScreenRef			inRef,
											 SInt16						inOneBasedLEDNumber,
											 Boolean					inIsOn);

Boolean
	Terminal_LineFeedNewLineMode			(TerminalScreenRef			inScreen);

Boolean
	Terminal_LineWrapIsEnabled				(TerminalScreenRef			inScreen);

void
	Terminal_Reset							(TerminalScreenRef			inScreen,
											 Terminal_ResetFlags		inFlags = kTerminal_ResetFlagsAll);

Preferences_ContextRef
	Terminal_ReturnConfiguration			(TerminalScreenRef			inScreen);

CFStringEncoding
	Terminal_ReturnTextEncoding				(TerminalScreenRef			inScreen);

Boolean
	Terminal_ReverseVideoIsEnabled			(TerminalScreenRef			inScreen);

Boolean
	Terminal_SaveLinesOnClearIsEnabled		(TerminalScreenRef			inScreen);

void
	Terminal_SetBellEnabled					(TerminalScreenRef			inScreen,
											 Boolean					inIsEnabled);

void
	Terminal_SetDumbTerminalRendering		(UniChar					inCharacter,
											 char const*				inDescription);

void
	Terminal_SetLineWrapEnabled				(TerminalScreenRef			inScreen,
											 Boolean					inIsEnabled);

void
	Terminal_SetSaveLinesOnClear			(TerminalScreenRef			inScreen,
											 Boolean					inClearScreenSavesLines);

Terminal_Result
	Terminal_SetTextEncoding				(TerminalScreenRef			inScreen,
											 CFStringEncoding			inNewEncoding);

Terminal_Result
	Terminal_UserInputOffsetCursor			(TerminalScreenRef			inScreen,
											 SInt16						inColumnDelta,
											 SInt16						inRowDelta);

Terminal_Result
	Terminal_UserInputVTFunctionKey			(TerminalScreenRef			inRef,
											 VTKeys_FKey				inFunctionKey);

Terminal_Result
	Terminal_UserInputVTKey					(TerminalScreenRef			inScreen,
											 UInt8						inVTKey);

Boolean
	Terminal_WindowIsToBeMinimized			(TerminalScreenRef			inScreen);

//@}

//!\name Direct Interaction With the Emulator (Deprecated)
//@{

Terminal_Result
	Terminal_EmulatorProcessCString			(TerminalScreenRef			inScreen,
											 char const*				inCString);

Terminal_Result
	Terminal_EmulatorProcessData			(TerminalScreenRef			inScreen,
											 UInt8 const*				inBuffer,
											 UInt32						inLength);

//@}

//!\name File Capture Handling (Note: May Move)
//@{

Boolean
	Terminal_FileCaptureBegin				(TerminalScreenRef			inScreen,
											 SInt16						inOpenWritableFile,
											 Boolean					inAutoClose);

void
	Terminal_FileCaptureEnd					(TerminalScreenRef			inScreen);

Boolean
	Terminal_FileCaptureInProgress			(TerminalScreenRef			inScreen);

//@}

//!\name Sound and Speech (Note: May Move)
//@{

TerminalSpeaker_Ref
	Terminal_ReturnSpeaker					(TerminalScreenRef			inScreen);

void
	Terminal_SetSpeechEnabled				(TerminalScreenRef			inScreen,
											 Boolean					inIsEnabled);

Boolean
	Terminal_SpeechIsEnabled				(TerminalScreenRef			inScreen);

void
	Terminal_SpeechPause					(TerminalScreenRef			inScreen);

void
	Terminal_SpeechResume					(TerminalScreenRef			inScreen);

//@}

//!\name Callbacks
//@{

void
	Terminal_StartMonitoring				(TerminalScreenRef			inScreen,
											 Terminal_Change			inForWhatChange,
											 ListenerModel_ListenerRef	inListener);

void
	Terminal_StopMonitoring					(TerminalScreenRef			inScreen,
											 Terminal_Change			inForWhatChange,
											 ListenerModel_ListenerRef	inListener);

//@}

//!\name Debugging
//@{

void
	Terminal_DebugDumpDetailedSnapshot		(TerminalScreenRef			inScreen);

//@}

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
