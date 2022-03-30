import SwiftUI
import Defaults

// TODO
//@MainActor
final class WebsitesWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = WebsitesScreen()

		window.title = "Websites"
		window.styleMask = [
			.titled,
			.fullSizeContentView,
			.closable
		]
		window.level = .modalPanel
		window.contentViewController = NSHostingController(rootView: view)
		window.center()
	}
}
