import Cocoa
import SwiftUI

final class PreferencesWindowController: SingletonWindowController {
	convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = PreferencesView()

		window.title = "Plash Preferences"
		window.styleMask = [
			.titled,
			.closable
		]
		window.level = .modalPanel
		window.contentView = NSHostingView(rootView: view)
		window.center()
	}
}
