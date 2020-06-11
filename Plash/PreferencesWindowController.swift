import SwiftUI

final class PreferencesWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = PreferencesView()

		window.title = "Preferences"
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
