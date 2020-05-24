import Cocoa
import SwiftUI
import Defaults

final class OpenURLWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = OpenURLView { url in
			window.close()
			Defaults[.url] = url
		}

		window.title = "Open URL"
		window.shouldCloseOnEscapePress = true
		window.styleMask = [
			.titled,
			.closable
		]
		window.level = .modalPanel
		window.contentView = NSHostingView(rootView: view)
		window.center()
	}
}
