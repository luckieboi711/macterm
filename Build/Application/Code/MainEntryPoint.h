/*!	\file MainEntryPoint.h
	\brief Contains main(), routines to quit the program, and
	a mechanism for modules to register themselves.
	
	This is where MacTelnet starts up from, and also (in a
	perfect world) the only place where it can quit.  There are
	routines that cause MacTelnet to quit, either forcefully or
	gracefully.
*/
/*###############################################################

	MacTelnet
		© 1998-2009 by Kevin Grant.
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

#ifndef __MAINENTRYPOINT__
#define __MAINENTRYPOINT__



/*###############################################################
	APPLICATION ENTRY POINTS
###############################################################*/

//int
//	main							();

/*###############################################################
	APPLICATION EXIT POINTS
###############################################################*/

void
	MainEntryPoint_ImmediatelyQuit	();

#endif

// BELOW IS REQUIRED NEWLINE TO END FILE
