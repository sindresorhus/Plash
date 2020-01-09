import Cocoa
import SwiftUI
import Defaults

final class OpenURLWindowController: NSWindowController {
	convenience init() {
		let window = NSWindow()
		self.init(window: window)

		let view = OpenURLView { url in
			window.close()
			Defaults[.url] = url
		}

		window.title = "Open URL"
		window.styleMask = [
			.titled,
			.closable
		]
		window.level = .modalPanel
		window.contentView = NSHostingView(rootView: view)
		window.center()
	}

	@objc
	func cancel(_ sender: Any?) {
		close()
	}

	func showWindow() {
		NSApp.activate(ignoringOtherApps: true)
		window?.makeKeyAndOrderFront(nil)
	}
}
