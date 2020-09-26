import Cocoa

extension AppDelegate {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)

		NSAlert.showModal(
			message: "Welcome to Plash!",
			informativeText:
				"""
				Plash lives in the menu bar (droplet icon at the top-right of the screen). Click it and then select “Open URL…” to get started.

				Note: Support for multiple displays is currently limited to the ability to choose which display to show the website on. Support for setting a separate website for each display is planned.

				See the project page for what else is planned: https://github.com/sindresorhus/Plash/issues
				""",
			buttonTitles: [
				"Continue"
			],
			defaultButtonIndex: -1
		)

		NSAlert.showModal(
			message: "Feedback Welcome 🙌🏻",
			informativeText:
				"""
				If you have any feedback, bug reports, or feature requests, kindly use the “Send Feedback” button in the Plash menu. We respond to all submissions and reported issues will be dealt with swiftly. It's preferable that you report bugs this way rather than as an App Store review, since the App Store will not allow us to contact you for more information.
				""",
			buttonTitles: [
				"Get Started"
			]
		)

		statusItemButton.playRainbowAnimation()

		delay(seconds: 1) { [self] in
			statusItemButton.performClick(nil)
		}
	}
}
