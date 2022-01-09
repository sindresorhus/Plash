import SwiftUI
import Defaults

// TODO
//@MainActor
final class WebsitesWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = WebsitesView()

		window.title = "Websites"
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
