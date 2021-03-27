import SwiftUI
import Defaults

final class AddWebsiteWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = AddWebsiteView(isEditing: false, showsCancelButtons: false, website: nil) {
			window.close()
		}

		window.title = "Add Website"
		window.shouldCloseOnEscapePress = true
		window.styleMask = [
			.titled,
			.fullSizeContentView,
			.closable
		]
		window.level = .modalPanel
		window.contentView = NSHostingView(rootView: view)
		window.center()
	}
}
