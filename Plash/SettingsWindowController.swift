import SwiftUI

final class SettingsWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = SettingsView()

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
