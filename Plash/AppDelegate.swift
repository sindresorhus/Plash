import Cocoa
import AppCenter
import AppCenterCrashes
import Defaults

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	let menu = SSMenu()

	lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = true
		$0.behavior = [.removalAllowed, .terminationOnRemoval]
		$0.menu = menu
		$0.button?.image = Constants.menuBarIcon
	}

	lazy var statusButton = statusItem.button!

	lazy var webViewController = WebViewController()

	lazy var desktopWindow = with(DesktopWindow(screen: Defaults[.display].screen)) {
		$0.contentView = webViewController.webView
		$0.contentView?.isHidden = true
	}

	lazy var openURLWindowController = OpenURLWindowController()
	lazy var preferencesWindowController = PreferencesWindowController()

	var isBrowsingMode = false {
		didSet {
			desktopWindow.isInteractive = isBrowsingMode
			desktopWindow.alphaValue = isBrowsingMode ? 1 : CGFloat(Defaults[.opacity])
			resetTimer()
		}
	}

	var reloadTimer: Timer?

	var webViewError: Error? {
		didSet {
			if let error = webViewError {
				self.statusButton.toolTip = "Error: \(error.localizedDescription)"
				self.statusButton.contentTintColor = .systemRed

				// TODO: Also present the error when the user just added it from the input box as then it's also "interactive".
				if self.isBrowsingMode {
					NSApp.presentError(error)
				}

				return
			}

			self.statusButton.contentTintColor = nil
		}
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		UserDefaults.standard.register(defaults: [
			"NSApplicationCrashOnExceptions": true
		])
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		MSAppCenter.start(
			"27131b3e-4b25-4a92-b0d3-7bb6883f7343",
			withServices: [
				MSCrashes.self
			]
		)

		_ = statusButton
		_ = desktopWindow

		// This is needed to make the window appear.
		// TODO: Find out why.
		desktopWindow.isInteractive = false

		setUpEvents()

		showWelcomeScreenIfNeeded()
	}

	func setUpEvents() {
		menu.onUpdate = { _ in
			self.updateMenu()
		}

		webViewController.onLoaded = { error in
			self.webViewError = error

			guard error == nil else {
				return
			}

			if let url = Defaults[.url] {
				let title = self.webViewController.webView.title.map { "\($0)\n" } ?? ""
				let urlString = url.isFileURL ? url.lastPathComponent : url.absoluteString
				self.statusButton.toolTip = "\(title)\(urlString)"
			} else {
				self.statusButton.toolTip = ""
			}
		}

		Defaults.observe(.url) { change in
			self.resetTimer()
			self.loadURL(change.newValue)
		}
			.tieToLifetime(of: self)

		Defaults.observe(.opacity) { change in
			self.isBrowsingMode = false
			self.desktopWindow.alphaValue = CGFloat(change.newValue)
		}
			.tieToLifetime(of: self)

		Defaults.observe(.reloadInterval) { _ in
			self.resetTimer()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.display, options: [.new]) { change in
			self.desktopWindow.targetScreen = change.newValue.screen
		}
			.tieToLifetime(of: self)

		Defaults.observe(.invertColors, options: []) { _ in
			self.recreateWebView()
		}
			.tieToLifetime(of: self)
	}

	func showWelcomeScreenIfNeeded() {
		guard App.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)
		NSAlert.showModal(
			message: "Welcome to Plash!",
			informativeText:
				"""
				Plash lives in the menu bar (droplet icon). Click it and then select “Open URL…” to get started.

				Note: Support for multiple displays is currently limited to the ability to choose which display to show the website on. Support for setting a separate website for each display is planned.

				See the project page for what else is planned: https://github.com/sindresorhus/Plash/issues

				If you have any feedback, bug reports, or feature requests, kindly use the “Send Feedback” button in the Plash menu. We respond to all submissions and reported issues will be dealt with swiftly. It's preferable that you report bugs this way rather than as an App Store review, since the App Store will not allow us to contact you for more information.
				"""
		)
	}

	func resetTimer() {
		self.reloadTimer?.invalidate()
		self.reloadTimer = nil

		guard !isBrowsingMode else {
			return
		}

		guard let reloadInterval = Defaults[.reloadInterval] else {
			return
		}

		self.reloadTimer = Timer.scheduledTimer(withTimeInterval: reloadInterval, repeats: true) { _ in
			self.loadUserURL()
		}
	}

	func recreateWebView() {
		webViewController.recreateWebView()
		desktopWindow.contentView = webViewController.webView
		loadUserURL()
	}

	func loadUserURL() {
		loadURL(Defaults[.url])
	}

	func loadURL(_ url: URL?) {
		webViewError = nil

		guard let url = url else {
			return
		}

		self.webViewController.loadURL(url)

		// TODO: Add a callback to `loadURL` when it's done loading instead.
		// TODO: Fade in the web view.
		delay(seconds: 1) {
			self.desktopWindow.contentView?.isHidden = false
		}
	}

	func updateMenu() {
		menu.removeAllItems()

		if let error = webViewError {
			menu.addDisabled("Error: \(error.localizedDescription)".wrapped(atLength: 36).attributedString)
			menu.addSeparator()
		}

		if let url = Defaults[.url] {
			let maxCount = 26

			if
				let title = webViewController.webView.title,
				!title.isEmpty
			{
				let menuItem = menu.addDisabled(title.truncated(to: maxCount))
				menuItem.toolTip = title
			}

			let urlString = url.isFileURL ? url.lastPathComponent : url.absoluteString

			var newUrlString = urlString
			if urlString.count > maxCount {
				newUrlString = urlString.replacingOccurrences(matchingRegex: #"^https?:\/\/(?:www.)?"#, with: "")
			}

			let menuItem = menu.addDisabled(newUrlString.truncated(to: maxCount))
			menuItem.toolTip = urlString
		}

		menu.addSeparator()

		menu.addCallbackItem("Open URL…", key: "o") { _ in
			self.openURLWindowController.showWindow()
		}

		// TODO: This requires some more work.
		// - Need to save the security scoped bookmark in UserDefaults after the open panel so the file can be accessed on the next launch.
		// - WKWebView has a bug where it can only load a local file once. We need to work around that.
		// - See inline TODOs.
		menu.addCallbackItem(
			"Open File…",
			key: "o",
			keyModifiers: .option,
			isHidden: true // TODO: Disabled until it's done.
		) { _ in
			NSApp.activate(ignoringOtherApps: true)

			let panel = NSOpenPanel()
			panel.canChooseDirectories = false
			panel.canCreateDirectories = false

			// Ensure it's above the window when in "Browsing Mode".
			panel.level = .floating

			// TODO: Limit file types to only what WKWebView supports? Where can we find out what it supports?
			//panel.allowedFileTypes = []

			if
				let url = Defaults[.url],
				url.isFileURL
			{
				panel.directoryURL = url.deletingLastPathComponent()
			}

			panel.begin {
				if $0 == .OK {
					Defaults[.url] = panel.url!
				}
			}
		}

		menu.addSeparator()

		menu.addCallbackItem("Reload", key: "r", isEnabled: Defaults[.url] != nil) { _ in
			self.loadUserURL()
		}

		menu.addCallbackItem(
			"Browsing Mode",
			key: "b",
			isEnabled: Defaults[.url] != nil,
			isChecked: isBrowsingMode
		) { _ in
			self.isBrowsingMode.toggle()
		}

		menu.addSeparator()

		menu.addAboutItem()

		menu.addCallbackItem("Preferences…", key: ",") { _ in
			self.preferencesWindowController.showWindow()
		}

		menu.addSeparator()

		menu.addCallbackItem("Send Feedback…") { _ in
			Meta.openSubmitFeedbackPage()
		}

		menu.addQuitItem()
	}
}
