/*!	\file CocoaBasic.mm
	\brief Fundamental Cocoa APIs wrapped in C++.
*/
/*###############################################################

	Simple Cocoa Wrappers Library 1.0
	© 2008 by Kevin Grant
	
	This library is free software; you can redistribute it or
	modify it under the terms of the GNU Lesser Public License
	as published by the Free Software Foundation; either version
	2.1 of the License, or (at your option) any later version.
	
	This program is distributed in the hope that it will be
	useful, but WITHOUT ANY WARRANTY; without even the implied
	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
	PURPOSE.  See the GNU Lesser Public License for details.
	
	You should have received a copy of the GNU Lesser Public
	License along with this library; if not, write to:
	
		Free Software Foundation, Inc.
		59 Temple Place, Suite 330
		Boston, MA  02111-1307
		USA

###############################################################*/

// Mac includes
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

// library includes
#import <AutoPool.objc++.h>
#import <CocoaBasic.h>
#import <Console.h>
#import <HIViewWrap.h>
#import <SoundSystem.h>

// MacTelnet includes
#import "ColorBox.h"
#import "FileUtilities.h"



#pragma mark Types

@interface My_NoticeColorPanelChange : NSResponder
- (void)changeColor: (id)sender;
@end

#pragma mark Internal Method prototypes
namespace {

NSString*	findFolder			(short, OSType);
NSString*	returnPathForFSRef	(FSRef const&);

} // anonymous namespace

#pragma mark Variables
namespace {

HIViewWrap						gCurrentColorPanelFocus;	//!< see ColorBox.h; a view with a color box that uses the current color
My_NoticeColorPanelChange*		gColorWatcher = nil;		//!< sees color changes

} // anonymous namespace



#pragma mark Public Methods

/*!
Shows the standard About panel, or brings it to the front.

(1.0)
*/
void
CocoaBasic_AboutPanelDisplay ()
{
	AutoPool		_;
	// clear out the version field because it tends to be redundant
	NSDictionary*	aboutBoxOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										@"", @"Version",
										nil];
	
	
	[NSApp orderFrontStandardAboutPanelWithOptions:aboutBoxOptions];
}// AboutPanelDisplay


/*!
Initializes a Cocoa application by calling
NSApplicationLoad().

(1.0)
*/
Boolean
CocoaBasic_ApplicationLoad ()
{
	AutoPool	_;
	BOOL		loadOK = NSApplicationLoad();
	
	
	return loadOK;
}// ApplicationLoad


/*!
Shows the global color panel floating window, if it is
not already visible.

(1.0)
*/
void
CocoaBasic_ColorPanelDisplay ()
{
	AutoPool	_;
	
	
	[NSApp orderFrontColorPanel:NSApp];
}// ColorPanelDisplay


/*!
Specifies the view, which must be a color box, that is
the current target of the global color panel.  Also
initializes the global color panel color to whatever
ColorBox_GetColor() returns.

(1.0)
*/
void
CocoaBasic_ColorPanelSetTargetView	(HIViewRef	inColorBoxView)
{
	AutoPool		_;
	NSColorPanel*	colorPanel = [NSColorPanel sharedColorPanel];
	NSColor*		globalColor = nil;
	RGBColor		viewColor;
	CGDeviceColor	viewColorFloat;
	
	
	// create a responder if none exists, to watch for color changes
	if (nil == gColorWatcher)
	{
		gColorWatcher = [[My_NoticeColorPanelChange alloc] init];
		[gColorWatcher setNextResponder:[NSApp nextResponder]];
		[NSApp setNextResponder:gColorWatcher];
	}
	
	// remove highlighting from any previous focus
	if (gCurrentColorPanelFocus.exists()) SetControl32BitValue(gCurrentColorPanelFocus, kControlCheckBoxUncheckedValue);
	
	// set the global to the new target view
	gCurrentColorPanelFocus.setCFTypeRef(inColorBoxView);
	
	// highlight the new focus
	SetControl32BitValue(gCurrentColorPanelFocus, kControlCheckBoxCheckedValue);
	
	// initialize the color in the panel
	ColorBox_GetColor(inColorBoxView, &viewColor);
	viewColorFloat.red = viewColor.red;
	viewColorFloat.red /= RGBCOLOR_INTENSITY_MAX;
	viewColorFloat.green = viewColor.green;
	viewColorFloat.green /= RGBCOLOR_INTENSITY_MAX;
	viewColorFloat.blue = viewColor.blue;
	viewColorFloat.blue /= RGBCOLOR_INTENSITY_MAX;
	globalColor = [NSColor colorWithDeviceRed:viewColorFloat.red green:viewColorFloat.green blue:viewColorFloat.blue alpha:1.0];
	[colorPanel setColor:globalColor];
}// ColorPanelSetTargetView


/*!
Shows a modal panel for opening any number of files and
automatically handling them via Apple Events.  The panel
resolves aliases, does not allow the user to choose
directories, and allows the user to try opening any type
of file (despite the list).

All of the arguments can be "nullptr" to choose defaults.
The defaults are: no message, no title, and allowing all
possible file types.

The file type list is sophisticated and can accept
anything you would imagine: file name extensions, HFS
four-character codes, and reverse-domain-style UTIs.

Returns true only if the user tried to open something.

(1.0)
*/
Boolean
CocoaBasic_FileOpenPanelDisplay		(CFStringRef	inMessage,
									 CFStringRef	inWindowTitle,
									 CFArrayRef		inAllowedFileTypes)
{
	AutoPool		_;
	NSOpenPanel*	thePanel = [NSOpenPanel openPanel];
	int				buttonHit = NSCancelButton;
	Boolean			result = false;
	
	
	if (nullptr != inMessage)
	{
		[thePanel setMessage:(NSString*)inMessage];
	}
	if (nullptr != inWindowTitle)
	{
		[thePanel setTitle:(NSString*)inWindowTitle];
	}
	[thePanel setCanChooseDirectories:NO];
	[thePanel setCanChooseFiles:YES];
	[thePanel setAllowsOtherFileTypes:YES];
	[thePanel setAllowsMultipleSelection:YES];
	[thePanel setResolvesAliases:YES];
	buttonHit = [thePanel runModalForTypes:(NSArray*)inAllowedFileTypes];
	result = (NSOKButton == buttonHit);
	if (result)
	{
		NSArray*		toOpen = [thePanel URLs];
		NSEnumerator*	forURLs = [toOpen objectEnumerator];
		id				currentFile = nil;
		
		
		while (nil != (currentFile = [forURLs nextObject]))
		{
			NSURL*		currentFileURL = (NSURL*)currentFile;
			FSRef		fileRef;
			OSStatus	error = noErr;
			
			
			if (CFURLGetFSRef((CFURLRef)currentFileURL, &fileRef))
			{
				error = FileUtilities_OpenDocument(fileRef);
			}
			else
			{
				error = kURLInvalidURLError;
			}
			
			if (noErr != error)
			{
				Sound_StandardAlert();
				Console_WriteValueCFString("unable to open file", (CFStringRef)[currentFileURL absoluteString]);
				Console_WriteValue("error", error);
			}
		}
	}
	
	return result;
}// FileOpenPanelDisplay


/*!
Plays the sound with the given name (no extension), if it
is found anywhere in the standard search paths like
/System/Library/Sounds, etc.

See also CocoaBasic_ReturnUserSoundNames().

(1.0)
*/
void
CocoaBasic_PlaySoundByName	(CFStringRef	inName)
{
	AutoPool	_;
	
	
	[(NSSound*)[NSSound soundNamed:REINTERPRET_CAST(inName, NSString const*)] stop];
	[(NSSound*)[NSSound soundNamed:REINTERPRET_CAST(inName, NSString const*)] play];
}// PlaySoundByName


/*!
Plays the sound in the specified file (asynchronously).

(1.0)
*/
void
CocoaBasic_PlaySoundFile	(CFURLRef	inFile)
{
	AutoPool	_;
	
	
	[[[[NSSound alloc] initWithContentsOfURL:REINTERPRET_CAST(inFile, NSURL const*) byReference:NO] autorelease] play];
}// PlaySoundFile


/*!
Since Cocoa has a routine for finding the *localized* name of a
string encoding, it is exposed as a general API here.

The returned string is not retained, so do not release it.

(1.0)
*/
CFStringRef
CocoaBasic_ReturnStringEncodingLocalizedName	(CFStringEncoding	inEncoding)
{
	AutoPool			_;
	NSStringEncoding	translatedEncoding = CFStringConvertEncodingToNSStringEncoding(inEncoding);
	CFStringRef			result = nullptr;
	
	
	result = (CFStringRef)[NSString localizedNameOfStringEncoding:translatedEncoding];
	return result;
}// ReturnStringEncodingLocalizedName


/*!
Returns an unsorted list of names (without extensions) that are
valid sounds to pass to CocoaBasic_PlaySoundByName().  This is
useful for displaying a set of choices, such as a menu, to the
user.

(1.0)
*/
CFArrayRef
CocoaBasic_ReturnUserSoundNames ()
{
	AutoPool				_;
	NSArray* const			kSearchPaths = [NSArray arrayWithObjects:
												findFolder(kUserDomain, kSystemSoundsFolderType),
												findFolder(kLocalDomain, kSystemSoundsFolderType),
												findFolder(kSystemDomain, kSystemSoundsFolderType),
												nil];
	NSArray* const			kSupportedFileTypes = [NSSound soundUnfilteredFileTypes];
	NSFileManager* const	kFileManager = [NSFileManager defaultManager];
	NSEnumerator*			toSearchPath = [kSearchPaths objectEnumerator];
	BOOL					isDirectory = NO;
	NSMutableArray*			result = [NSMutableArray array];
	
	
	while (NSString* soundDirectory = [toSearchPath nextObject])
	{
		if ([kFileManager fileExistsAtPath:soundDirectory isDirectory:&isDirectory])
		{
			if (isDirectory)
			{
				NSEnumerator*	toFile = [[kFileManager directoryContentsAtPath:soundDirectory] objectEnumerator];
				
				
				while (NSString* soundFile = [toFile nextObject])
				{
					if ([kSupportedFileTypes containsObject:[soundFile pathExtension]])
					{
						[result addObject:[soundFile stringByDeletingPathExtension]];
					}
				}
			}
		}
	}
	
	[result retain];
	return REINTERPRET_CAST(result, CFArrayRef);
}// ReturnUserSoundNames


#pragma mark Internal Methods
namespace {

/*!
Returns the path of the specified folder.  The domain is
one that is valid for FSFindFolder, e.g. kUserDomain or
kSystemDomain or a volume.

The result is always defined, which is convenient for
such things as initializing arrays.  Though it may be an
empty string (if there was a problem) or a path to a
folder that does not exist yet.

(1.0)
*/
NSString*
findFolder	(short		inDomain,
			 OSType		inType)
{
	OSStatus	error = noErr;
	FSRef		fileOrFolder;
	NSString*	result = nil;
	
	
	error = FSFindFolder(inDomain, inType, kDontCreateFolder, &fileOrFolder);
	if (noErr == error)
	{
		result = returnPathForFSRef(fileOrFolder);
	}
	if (nil == result) result = [NSString string];
	return result;
}// findFolder


/*!
Converts a Carbon-style FSRef for an existing file or folder
into a path as required by Cocoa routines.

(1.0)
*/
NSString*
returnPathForFSRef	(FSRef const&	inFileOrFolder)
{
	NSString*	result = nil;
	CFURLRef	urlRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &inFileOrFolder);
	
	
	if (nil != urlRef)
	{
		NSURL*		urlObject = (NSURL*)urlRef;
		
		
		result = [urlObject path];
	}
	return result;
}// returnPathForFSRef

} // anonymous namespace

@implementation My_NoticeColorPanelChange

- (void)changeColor: (id)sender
{
#pragma unused(sender)
	NSColor*		newColor = [[NSColorPanel sharedColorPanel] color];
	CGDeviceColor	newColorFloat;
	float			ignoredAlpha = 0;
	RGBColor		newColorRGB;
	
	
	[newColor getRed:&newColorFloat.red green:&newColorFloat.green blue:&newColorFloat.blue
		alpha:&ignoredAlpha];
	newColorFloat.red *= RGBCOLOR_INTENSITY_MAX;
	newColorFloat.green *= RGBCOLOR_INTENSITY_MAX;
	newColorFloat.blue *= RGBCOLOR_INTENSITY_MAX;
	newColorRGB.red = STATIC_CAST(newColorFloat.red, unsigned short);
	newColorRGB.green = STATIC_CAST(newColorFloat.green, unsigned short);
	newColorRGB.blue = STATIC_CAST(newColorFloat.blue, unsigned short);
	
	ColorBox_SetColor(gCurrentColorPanelFocus, &newColorRGB);
}

@end // My_NoticeColorPanelChange

// BELOW IS REQUIRED NEWLINE TO END FILE
