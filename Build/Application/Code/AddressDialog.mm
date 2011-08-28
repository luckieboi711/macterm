/*!	\file AddressDialog.mm
	\brief Cocoa implementation of the IP addresses panel.
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

// Mac includes
#import <Cocoa/Cocoa.h>

// library includes
#import <AutoPool.objc++.h>
#import <Console.h>

// application includes
#import "AddressDialog.h"
#import "Network.h"



#pragma mark Types

/*!
Implements an object wrapper for IP addresses, that allows them
to be easily inserted into user interface elements without
losing less user-friendly information about each address.
*/
@interface AddressDialog_Address : NSObject
{
@private
	NSString*		description;
}

// accessors; see "Protocol Definitions" array controller in the NIB, for key names

- (NSString*)
boundName;
- (void)
setBoundName:(NSString*)_;

- (NSString*)
description;
- (void)
setDescription:(NSString*)_;

// initializers

- (id)
initWithDescription:(NSString*)_;

@end



#pragma mark Public Methods

/*!
Shows or hides the IP Addresses panel.

(3.1)
*/
void
AddressDialog_Display ()
{
	AutoPool		_;
	HIWindowRef		oldActiveWindow = GetUserFocusWindow();
	
	
	[[AddressDialog_PanelController sharedAddressPanelController] showWindow:NSApp];
	(OSStatus)SetUserFocusWindow(oldActiveWindow);
}// Display


#pragma mark Internal Methods


@implementation AddressDialog_Address


/*!
Designated initializer.

(4.0)
*/
- (id)
initWithDescription:(NSString*)		aString
{
	self = [super init];
	if (nil != self)
	{
		[self setDescription:aString];
	}
	return self;
}// initWithDescription:


#pragma mark Accessors


/*!
Accessor.

IMPORTANT:	The "boundName" key is ONLY required because older
			versions of Mac OS X do not seem to work properly
			when bound to the "description" accessor.  (Namely,
			the OS seems to stubbornly use its own "description"
			instead of invoking the right one.)  In the future
			this might be removed and rebound to "description".

(4.0)
*/
- (NSString*)
boundName
{
	return [[description retain] autorelease];
}
- (void)
setBoundName:(NSString*)	aString
{
	if (description != aString)
	{
		[description release];
		description = [aString copy];
	}
}// setBoundName:


/*!
Accessor.

(4.0)
*/
- (NSString*)
description
{
	return [[description retain] autorelease];
}
- (void)
setDescription:(NSString*)		aString
{
	if (description != aString)
	{
		[description release];
		description = [aString copy];
	}
}// setDescription:


@end // AddressDialog_Address


@implementation AddressDialog_AddressArrayController


/*!
Designated initializer.

(3.1)
*/
- (id)
init
{
	self = [super init];
	// drag and drop support
	[addressTableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, nil]];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
	[addressTableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
#endif
	return self;
}// init


/*!
Adds the selected table strings to the specified drag.

NOTE: This is only called on Mac OS X 10.4 and beyond.

(3.1)
*/
- (BOOL)
tableView:(NSTableView*)			inTable
writeRowsWithIndexes:(NSIndexSet*)	inRowIndices
toPasteboard:(NSPasteboard*)		inoutPasteboard
{
#pragma unused(inTable)
	NSString*	dragData = [[[self arrangedObjects] objectAtIndex:[inRowIndices firstIndex]] boundName];
	BOOL		result = YES;
	
	
	// add the row string to the drag; only one can be selected at at time
	[inoutPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[inoutPasteboard setString:dragData forType:NSStringPboardType];
	return result;
}// tableView:writeRowsWithIndexes:toPasteboard:


@end // AddressDialog_AddressArrayController


@implementation AddressDialog_PanelController


static AddressDialog_PanelController*	gAddressDialog_PanelController = nil;


/*!
Returns the singleton.

(3.1)
*/
+ (id)
sharedAddressPanelController
{
	if (nil == gAddressDialog_PanelController)
	{
		gAddressDialog_PanelController = [[[self class] allocWithZone:NULL] init];
	}
	return gAddressDialog_PanelController;
}


/*!
Designated initializer.

(3.1)
*/
- (id)
init
{
	self = [super initWithWindowNibName:@"AddressDialogCocoa"];
	if (nil != self)
	{
		[self rebuildAddressList:NSApp];
	}
	return self;
}// init


/*!
Destructor.

(4.0)
*/
- (void)
dealloc
{
	[super dealloc];
}// dealloc


/*!
Rebuilds the list of IP addresses based on the current
address assignments for the network cards in the computer.

(4.0)
*/
- (IBAction)
rebuildAddressList:(id)		sender
{
#pragma unused(sender)
	// find IP addresses and store them in the bound array
	typedef std::vector< CFRetainRelease >		My_AddressList;
	My_AddressList	addressList;
	Boolean			addressesFound = Network_CopyIPAddresses(addressList);
	
	
	addressArray = [[NSMutableArray alloc] init];
	if (addressesFound)
	{
		for (My_AddressList::size_type i = 0; i < addressList.size(); ++i)
		{
			NSString*	addressString = (NSString*)addressList[i].returnCFStringRef();
			
			
			[addressArray addObject:[[[AddressDialog_Address alloc] initWithDescription:addressString] autorelease]];
		}
	}
}// rebuildAddressList:


#pragma mark NSWindowController


/*!
Affects the preferences key under which window position
and size information are automatically saved and
restored.

(4.0)
*/
- (NSString*)
windowFrameAutosaveName
{
	// NOTE: do not ever change this, it would only cause existing
	// user settings to be forgotten
	return @"IPAddresses";
}// windowFrameAutosaveName


@end // AddressDialog_PanelController

// BELOW IS REQUIRED NEWLINE TO END FILE
