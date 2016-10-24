/*!	\file AppResources.mm
	\brief Easy access to resources located in application
	resource files.
*/
/*###############################################################

	MacTerm
		© 1998-2016 by Kevin Grant.
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

#include "AppResources.h"
#include <UniversalDefines.h>

// Mac includes
#include <AppKit/AppKit.h>
#include <Carbon/Carbon.h>
//#include <QuickTime/QuickTime.h>

// library includes
#include <CFRetainRelease.h>
#include <Console.h>

// application includes
#include "ConstantsRegistry.h"
#include "Local.h"
#include "UIStrings.h"



#pragma mark Variables
namespace {

CFRetainRelease&	gApplicationBundle ()	{ static CFRetainRelease x; return x; }

} // anonymous namespace



#pragma mark Public Methods

/*!
Call this before any other routines in this module.

Provide the name of the bundle containing resources.
Normally this is CFBundleGetMainBundle(), however
in a scripting scenario (for instance) this may have
to be reset explicitly.

(3.1)
*/
void
AppResources_Init	(CFBundleRef	inApplicationBundle)
{
	if (nullptr != inApplicationBundle)
	{
		gApplicationBundle().setMutableWithRetain(inApplicationBundle);
	}
}// Init


/*!
Provides an FSRef for the requested resource
file from one of the Resources subdirectories
of the main bundle.

Returns "true" only if the file can be found.

DEPRECATED.  URLs should be retrieved directly.

(3.1)
*/
Boolean
AppResources_GetArbitraryResourceFileFSRef	(CFStringRef	inName,
											 CFStringRef	inTypeOrNull,
											 FSRef&			outFSRef)
{
	Boolean		result = false;
	CFURLRef	resourceFileURL = nullptr;
	
	
	resourceFileURL = CFBundleCopyResourceURL(AppResources_ReturnApplicationBundle(), inName, inTypeOrNull,
												nullptr/* no particular subdirectory */);
	if (nullptr != resourceFileURL)
	{
		if (CFURLGetFSRef(resourceFileURL, &outFSRef))
		{
			result = true;
		}
		CFRelease(resourceFileURL);
	}
	
	return result;
}// GetArbitraryResourceFileFSRef


/*!
Asynchronously launches a separate application that
displays a preview of terminal text and allows the
user to print.  A new instance is produced each time,
allowing multiple previews to exist simultaneously
in the background.

Environment variables set in the dictionary should
match those used by the “Print Preview” internal
application to customize the display (such as the
font, font size, and unique name of a pasteboard
containing all the text to print).

See AppResources_LaunchResourceApplication() for
more on the remaining parameters and return value.

(2016.09)
*/
NSRunningApplication*
AppResources_LaunchPrintPreview	(CFDictionaryRef		inEnvironment,
								 CFErrorRef*			outErrorOrNull)
{
	NSRunningApplication*	result = AppResources_LaunchResourceApplication
										(CFSTR("PrintPreview.app"), inEnvironment, outErrorOrNull);
	
	
	return result;
}// LaunchPrintPreview


/*!
Asynchronously launches a separate application that
is located in the application bundle.  A new instance
is produced each time.

The error parameter is a standard autoreleasing
NSError object.  You can pass nullptr if you do not
want the error information but you should probably
display it to the user using the "presentError:"
method of NSResponder.

A handle to the running application is returned,
in case you need to take further action (such as
to force termination).

(2016.09)
*/
NSRunningApplication*
AppResources_LaunchResourceApplication	(CFStringRef			inDotAppDirectoryName,
										 CFDictionaryRef		inEnvironment,
										 CFErrorRef*			outErrorOrNull)
{
	NSRunningApplication*	result = nil;
	NSError*				error = nil;
	CFRetainRelease			appURL(CFBundleCopyResourceURL(AppResources_ReturnApplicationBundle(),
															inDotAppDirectoryName, nullptr/* type string */,
															nullptr/* subdirectory path */),
									CFRetainRelease::kAlreadyRetained);
	
	
	if (false == appURL.exists())
	{
		error = [NSError errorWithDomain:BRIDGE_CAST(kConstantsRegistry_NSErrorDomainAppDefault, NSString*)
											code:kConstantsRegistry_NSErrorResourceNotFound
											userInfo:@{
															NSFilePathErrorKey: BRIDGE_CAST(inDotAppDirectoryName, NSString*),
															NSLocalizedDescriptionKey: NSLocalizedStringFromTable
																						(@"Internal error: unable to find specified resource.",
																							@"Alert"/* table */,
																							@"message displayed for bad bundle resource locations"),
														}];
	}
	else
	{
		NSDictionary*			launchConfigDict =
								@{
									NSWorkspaceLaunchConfigurationEnvironment: BRIDGE_CAST(inEnvironment, NSDictionary*),
								};
		
		
		result = [[NSWorkspace sharedWorkspace]
					launchApplicationAtURL:BRIDGE_CAST(appURL.returnCFTypeRef(), NSURL*)
											options:(NSWorkspaceLaunchWithoutAddingToRecents |
														NSWorkspaceLaunchAsync |
														NSWorkspaceLaunchNewInstance)
											configuration:launchConfigDict
											error:&error];
	}
	
	if (outErrorOrNull != nullptr)
	{
		*outErrorOrNull = BRIDGE_CAST(error, CFErrorRef);
	}
	
	return result;
}// LaunchResourceApplication


/*!
ALWAYS use this instead of CFBundleGetMainBundle(),
to retrieve the bundle that contains resources.  In
general, be explicit about bundles at all times
(e.g. do not use CreateNibReference(), instead use
CreateNibReferenceWithCFBundle(), etc.).

The CFBundle API views the main bundle as the place
where the parent executable lives, and this is not
correct in cases like a scripting environment where
the interpreter is the parent.  This API ensures the
right bundle for resources can still be used.

See also the various other routines for determining
the bundle appropriate for a task.

(3.1)
*/
CFBundleRef
AppResources_ReturnApplicationBundle ()
{
	CFBundleRef		result = gApplicationBundle().returnCFBundleRef();
	
	
	assert(nullptr != result);
	return result;
}// ReturnApplicationBundle


/*!
ALWAYS use this instead of CFBundleGetMainBundle(),
to retrieve the bundle that contains application
information (such as the version).

See also the various other routines for determining
the bundle appropriate for a task.

(3.1)
*/
CFBundleRef
AppResources_ReturnBundleForInfo ()
{
	// currently, this is the same as the primary bundle
	CFBundleRef		result = gApplicationBundle().returnCFBundleRef();
	
	
	assert(nullptr != result);
	return result;
}// ReturnBundleForInfo


/*!
ALWAYS use this instead of CFBundleGetMainBundle(),
to retrieve the bundle that contains NIBs.  In
general, be explicit about bundles at all times
(e.g. do not use CreateNibReference(), instead use
CreateNibReferenceWithCFBundle(), etc.).

See also the various other routines for determining
the bundle appropriate for a task.

(3.1)
*/
CFBundleRef
AppResources_ReturnBundleForNIBs ()
{
	// currently, this is the same as the primary bundle
	CFBundleRef		result = gApplicationBundle().returnCFBundleRef();
	
	
	assert(nullptr != result);
	return result;
}// ReturnBundleForNIBs


/*!
Returns the four-character code representing the application,
used with many system APIs as a quick way to produce a value
that is reasonably unique compared to other applications.

(3.1)
*/
UInt32
AppResources_ReturnCreatorCode ()
{
	static UInt32	gCreatorCode = 0;
	
	
	// only need to look it up once, then remember it
	if (0 == gCreatorCode)
	{
		CFBundleRef		infoBundle = AppResources_ReturnBundleForInfo();
		UInt32			typeCode = 0;
		
		
		assert(nullptr != infoBundle);
		CFBundleGetPackageInfo(infoBundle, &typeCode, &gCreatorCode);
		assert(0 != gCreatorCode);
	}
	return gCreatorCode;
}// ReturnCreatorCode

// BELOW IS REQUIRED NEWLINE TO END FILE