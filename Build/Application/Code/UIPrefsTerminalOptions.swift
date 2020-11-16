/*###############################################################

	MacTerm
		© 1998-2020 by Kevin Grant.
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

import SwiftUI

//
// IMPORTANT: Many "public" entities below are required
// in order to interact with Swift playgrounds.
//

@objc public protocol UIPrefsTerminalOptions_ActionHandling : NSObjectProtocol {
	// implement these functions to bind to button actions
	func dataUpdated()
	func resetToDefaultGetWrapLines() -> Bool
	func resetToDefaultGetEightBit() -> Bool
	func resetToDefaultGetSaveLinesOnClear() -> Bool
	func resetToDefaultGetNormalKeypadTopRow() -> Bool
	func resetToDefaultGetLocalPageKeys() -> Bool
}

class UIPrefsTerminalOptions_RunnerDummy : NSObject, UIPrefsTerminalOptions_ActionHandling {
	// dummy used for debugging in playground (just prints function that is called)
	func dataUpdated() { print(#function) }
	func resetToDefaultGetWrapLines() -> Bool { print(#function); return false }
	func resetToDefaultGetEightBit() -> Bool { print(#function); return false }
	func resetToDefaultGetSaveLinesOnClear() -> Bool { print(#function); return false }
	func resetToDefaultGetNormalKeypadTopRow() -> Bool { print(#function); return false }
	func resetToDefaultGetLocalPageKeys() -> Bool { print(#function); return false }
}

public class UIPrefsTerminalOptions_Model : UICommon_DefaultingModel, ObservableObject {

	@Published @objc public var isDefaultWrapLines = true {
		willSet(isOn) {
			if isOn { ifUserRequestedDefault { lineWrapEnabled = runner.resetToDefaultGetWrapLines() } }
		}
	}
	@Published @objc public var isDefaultEightBit = true {
		willSet(isOn) {
			if isOn { ifUserRequestedDefault { eightBitEnabled = runner.resetToDefaultGetEightBit() } }
		}
	}
	@Published @objc public var isDefaultSaveLinesOnClear = true {
		willSet(isOn) {
			if isOn { ifUserRequestedDefault { saveLinesOnClearEnabled = runner.resetToDefaultGetSaveLinesOnClear() } }
		}
	}
	@Published @objc public var isDefaultNormalKeypadTopRow = true {
		willSet(isOn) {
			if isOn { ifUserRequestedDefault { normalKeypadTopRowEnabled = runner.resetToDefaultGetNormalKeypadTopRow() } }
		}
	}
	@Published @objc public var isDefaultLocalPageKeys = true {
		willSet(isOn) {
			if isOn { ifUserRequestedDefault { localPageKeysEnabled = runner.resetToDefaultGetLocalPageKeys() } }
		}
	}
	@Published @objc public var lineWrapEnabled = false {
		didSet(isOn) {
			ifWritebackEnabled {
				inNonDefaultContext { isDefaultWrapLines = false }
				runner.dataUpdated()
			}
		}
	}
	@Published @objc public var eightBitEnabled = false {
		didSet(isOn) {
			ifWritebackEnabled {
				inNonDefaultContext { isDefaultEightBit = false }
				runner.dataUpdated()
			}
		}
	}
	@Published @objc public var saveLinesOnClearEnabled = false {
		didSet(isOn) {
			ifWritebackEnabled {
				inNonDefaultContext { isDefaultSaveLinesOnClear = false }
				runner.dataUpdated()
			}
		}
	}
	@Published @objc public var normalKeypadTopRowEnabled = false {
		didSet(isOn) {
			ifWritebackEnabled {
				inNonDefaultContext { isDefaultNormalKeypadTopRow = false }
				runner.dataUpdated()
			}
		}
	}
	@Published @objc public var localPageKeysEnabled = false {
		didSet(isOn) {
			ifWritebackEnabled {
				inNonDefaultContext { isDefaultLocalPageKeys = false }
				runner.dataUpdated()
			}
		}
	}
	public var runner: UIPrefsTerminalOptions_ActionHandling

	@objc public init(runner: UIPrefsTerminalOptions_ActionHandling) {
		self.runner = runner
	}

	// MARK: UICommon_DefaultingModel

	override func setDefaultFlagsToTrue() {
		// unconditional; used by base when swapping to "isEditingDefaultContext"
		isDefaultWrapLines = true
		isDefaultEightBit = true
		isDefaultSaveLinesOnClear = true
		isDefaultNormalKeypadTopRow = true
		isDefaultLocalPageKeys = true
	}

}

public struct UIPrefsTerminalOptions_View : View {

	@EnvironmentObject private var viewModel: UIPrefsTerminalOptions_Model

	public var body: some View {
		VStack(
			alignment: .leading
		) {
			UICommon_DefaultOptionHeaderView()
			UICommon_Default1OptionLineView("General", bindIsDefaultTo: $viewModel.isDefaultWrapLines, isEditingDefault: viewModel.isEditingDefaultContext) {
				Toggle("Wrap lines (no truncation)", isOn: $viewModel.lineWrapEnabled)
					//.help("...") // (add when SDK is updated)
			}
			UICommon_Default1OptionLineView("", bindIsDefaultTo: $viewModel.isDefaultEightBit, isEditingDefault: viewModel.isEditingDefaultContext) {
				Toggle("Do not strip high bit of bytes", isOn: $viewModel.eightBitEnabled)
					//.help("...") // (add when SDK is updated)
			}
			UICommon_Default1OptionLineView("", bindIsDefaultTo: $viewModel.isDefaultSaveLinesOnClear, isEditingDefault: viewModel.isEditingDefaultContext) {
				Toggle("Save lines when screen clears", isOn: $viewModel.saveLinesOnClearEnabled)
					//.help("...") // (add when SDK is updated)
			}
			Spacer().asMacTermSectionSpacingV()
			UICommon_Default1OptionLineView("Keyboard", bindIsDefaultTo: $viewModel.isDefaultNormalKeypadTopRow, isEditingDefault: viewModel.isEditingDefaultContext) {
				Toggle("Normal keypad top row", isOn: $viewModel.normalKeypadTopRowEnabled)
					//.help("...") // (add when SDK is updated)
			}
			UICommon_Default1OptionLineView("", bindIsDefaultTo: $viewModel.isDefaultLocalPageKeys, isEditingDefault: viewModel.isEditingDefaultContext) {
				Toggle("Local page keys (↖︎↘︎⇞⇟)", isOn: $viewModel.localPageKeysEnabled)
					//.help("...") // (add when SDK is updated)
			}
			Spacer().asMacTermSectionSpacingV()
			Spacer().layoutPriority(1)
		}
	}

}

public class UIPrefsTerminalOptions_ObjC : NSObject {

	@objc public static func makeView(_ data: UIPrefsTerminalOptions_Model) -> NSView {
		return NSHostingView<AnyView>(rootView: AnyView(UIPrefsTerminalOptions_View().environmentObject(data)))
	}

}

public struct UIPrefsTerminalOptions_Previews : PreviewProvider {
	public static var previews: some View {
		let data = UIPrefsTerminalOptions_Model(runner: UIPrefsTerminalOptions_RunnerDummy())
		return VStack {
			UIPrefsTerminalOptions_View().background(Color(NSColor.windowBackgroundColor)).environment(\.colorScheme, .light).environmentObject(data)
			UIPrefsTerminalOptions_View().background(Color(NSColor.windowBackgroundColor)).environment(\.colorScheme, .dark).environmentObject(data)
		}
	}
}