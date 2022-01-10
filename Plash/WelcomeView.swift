import Cocoa

extension AppState {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)

		NSAlert.showModal(
			title: "Welcome to Plash!",
			message:
				"""
				Plash lives in the menu bar (droplet icon at the top-right of the screen). Click it and then select “Add Website…” to get started.

				Use “Browsing Mode” if you need to log into a website or interact with it in some way.

				Note: Support for multiple displays is currently limited to the ability to choose which display to show the website on. Support for setting a separate website for each display is planned.
				""",
			buttonTitles: [
				"Continue"
			],
			defaultButtonIndex: -1
		)

		NSAlert.showModal(
			title: "Feedback Welcome",
			message:
				"""
				If you have any feedback, bug reports, or feature requests, use the feedback button in the app. I quickly respond to all submissions.
				""",
			buttonTitles: [
				"Get Started with Plash"
			]
		)

		// Does not work on macOS 11 or later.
//		statusItemButton.playRainbowAnimation()

		delay(seconds: 1) { [self] in
			statusItemButton.performClick(nil)
		}
	}
}
