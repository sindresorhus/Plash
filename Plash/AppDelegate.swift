import Cocoa
import Combine
import AppCenter
import AppCenterCrashes
import Defaults
import KeyboardShortcuts

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	var cancellables = Set<AnyCancellable>()

	let menu = SSMenu()
	let powerSourceWatcher = PowerSourceWatcher()

	lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = true
		$0.behavior = [.removalAllowed, .terminationOnRemoval]
		$0.menu = menu
		$0.button?.image = Constants.menuBarIcon
	}

	lazy var statusItemButton = statusItem.button!

	lazy var webViewController = WebViewController()

	lazy var desktopWindow = with(DesktopWindow(screen: Defaults[.display].screen)) {
		$0.contentView = webViewController.webView
		$0.contentView?.isHidden = true
	}

	var isBrowsingMode = false {
		didSet {
			desktopWindow.isInteractive = isBrowsingMode
			desktopWindow.alphaValue = isBrowsingMode ? 1 : CGFloat(Defaults[.opacity])
			resetTimer()
		}
	}

	var isEnabled = true {
		didSet {
			statusItemButton.appearsDisabled = !isEnabled

			if isEnabled {
				loadUserURL()
				desktopWindow.makeKeyAndOrderFront(self)
			} else {
				// TODO: Properly unload the web view instead of just clearing and hiding it.
				desktopWindow.orderOut(self)
				loadURL(URL("about:blank"))
			}
		}
	}

	var reloadTimer: Timer?

	var webViewError: Error? {
		didSet {
			if let error = webViewError {
				self.statusItemButton.toolTip = "Error: \(error.localizedDescription)"
				self.statusItemButton.contentTintColor = .systemRed

				// TODO: Also present the error when the user just added it from the input box as then it's also "interactive".
				if self.isBrowsingMode {
					NSApp.presentError(error)
				}

				return
			}

			self.statusItemButton.contentTintColor = nil
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

		_ = statusItemButton
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

			// Set the persisted zoom level.
			let zoomLevel = self.webViewController.webView.zoomLevelWrapper
			if zoomLevel != 1 {
				self.webViewController.webView.zoomLevelWrapper = zoomLevel
			}

			if let url = Defaults[.url] {
				let title = self.webViewController.webView.title.map { "\($0)\n" } ?? ""
				let urlString = url.isFileURL ? url.lastPathComponent : url.absoluteString
				self.statusItemButton.toolTip = "\(title)\(urlString)"
			} else {
				self.statusItemButton.toolTip = ""
			}
		}

		powerSourceWatcher?.onChange = { _ in
			guard Defaults[.deactivateOnBattery] else {
				return
			}

			self.setEnabledStatus()
		}

		NSWorkspace.shared.notificationCenter
			.publisher(for: NSWorkspace.didWakeNotification)
			.sink { _ in
				self.loadUserURL()
			}
			.store(in: &cancellables)

		Defaults.observe(.url, options: []) { change in
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

		Defaults.observe(.display, options: []) { change in
			self.desktopWindow.targetScreen = change.newValue.screen
		}
			.tieToLifetime(of: self)

		Defaults.observe(.invertColors, options: []) { _ in
			self.recreateWebViewAndReload()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.customCSS, options: []) { _ in
			self.recreateWebViewAndReload()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.deactivateOnBattery) { _ in
			self.setEnabledStatus()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.showOnAllSpaces) { change in
			self.desktopWindow.collectionBehavior.toggleExistence(.canJoinAllSpaces, shouldExist: change.newValue)
		}
			.tieToLifetime(of: self)

		KeyboardShortcuts.onKeyUp(for: .toggleBrowsingMode) {
			self.isBrowsingMode.toggle()
		}
	}

	func setEnabledStatus() {
		self.isEnabled = !(Defaults[.deactivateOnBattery] && powerSourceWatcher?.powerSource.isUsingBattery == true)
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

		statusItemButton.playRainbowAnimation()
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
	}

	func recreateWebViewAndReload() {
		recreateWebView()
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

		// TODO: This is just a quick fix. The proper fix is to create a new web view below the existing one (with no opacity), load the URL, if it succeeds, we fade out the old one while fading in the new one. If it fails, we discard the new web view.
		if !url.isFileURL, !Reachability.isOnlineExtensive() {
			webViewError = NSError.appError("No internet connection.")
			return
		}

		// TODO: Report the bug to Apple.
		// WKWebView has a bug where it can only load a local file once. So if you load file A, load file B, and load file A again, it errors. And if you load the same file as the existing one, nothing happens. Quality engineering.
		if url.isFileURL {
			recreateWebView()
		}

		self.webViewController.loadURL(url)

		// TODO: Add a callback to `loadURL` when it's done loading instead.
		// TODO: Fade in the web view.
		delay(seconds: 1) {
			self.desktopWindow.contentView?.isHidden = false
		}
	}

	func openLocalWebsite() {
		NSApp.activate(ignoringOtherApps: true)

		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.canCreateDirectories = false
		panel.title = "Open Local Website"
		panel.message = "Choose a directory with a “index.html” file."

		// Ensure it's above the window when in "Browsing Mode".
		panel.level = .floating

		if
			let url = Defaults[.url],
			url.isFileURL
		{
			panel.directoryURL = url
		}

		panel.begin {
			guard
				$0 == .OK,
				let url = panel.url
			else {
				return
			}

			guard url.appendingPathComponent("index.html").exists else {
				NSAlert.showModal(message: "Please choose a directory that contains a “index.html” file.")
				self.openLocalWebsite()
				return
			}

			do {
				try SecurityScopedBookmarkManager.saveBookmark(for: url)
			} catch {
				NSApp.presentError(error)
				return
			}

			Defaults[.url] = url
		}
	}

	func addInfoMenuItem() {
		guard let url = Defaults[.url] else {
			return
		}

		let maxLength = 30

		if
			let title = webViewController.webView.title,
			!title.isEmpty
		{
			let menuItem = menu.addDisabled(title.truncated(to: maxLength))
			menuItem.toolTip = title
		}

		let urlString = url.isFileURL ? url.tildePath : url.absoluteString

		var newUrlString = urlString
		if urlString.count > maxLength {
			newUrlString = urlString.removingSchemeAndWWWFromURL
		}

		let menuItem = menu.addDisabled(newUrlString.truncated(to: maxLength))
		menuItem.toolTip = urlString
	}

	func createMoreMenu() -> SSMenu {
		let menu = SSMenu()

		menu.addAboutItem()

		menu.addSeparator()

		menu.addUrlItem(
			"Website",
			url: URL("https://sindresorhus.com/plash")
		)

		menu.addUrlItem(
			"Roadmap",
			url: URL("https://github.com/sindresorhus/Plash/issues")
		)

		menu.addUrlItem(
			"Examples",
			url: URL("https://github.com/sindresorhus/Plash/issues/1")
		)

		menu.addSeparator()

		menu.addMoreAppsItem()

		return menu
	}

	func updateMenu() {
		menu.removeAllItems()

		if isEnabled {
			if let error = webViewError {
				menu.addDisabled("Error: \(error.localizedDescription)".wrapped(atLength: 36).attributedString)
				menu.addSeparator()
			}

			addInfoMenuItem()
		} else {
			menu.addDisabled("Deactivated While on Battery")
		}

		menu.addSeparator()

		menu.addCallbackItem(
			"Open URL…",
			key: "o",
			isEnabled: isEnabled
		) { _ in
			OpenURLWindowController.showWindow()
		}

		menu.addCallbackItem(
			"Open Local Website…",
			key: "o",
			keyModifiers: .option,
			isEnabled: isEnabled
		) { _ in
			self.openLocalWebsite()
		}

		menu.addSeparator()

		menu.addCallbackItem(
			"Reload",
			key: "r",
			isEnabled: isEnabled && Defaults[.url] != nil
		) { _ in
			self.loadUserURL()
		}

		menu.addCallbackItem(
			"Browsing Mode",
			key: "b",
			isEnabled: isEnabled && Defaults[.url] != nil,
			isChecked: isBrowsingMode
		) { _ in
			self.isBrowsingMode.toggle()
		}

		menu.addSeparator()

		menu.addCallbackItem("Preferences…", key: ",") { _ in
			PreferencesWindowController.showWindow()
		}

		menu.addSeparator()

		menu.addCallbackItem("Send Feedback…") { _ in
			App.openSendFeedbackPage()
		}

		let moreMenuItem = menu.addItem("More")
		moreMenuItem.submenu = createMoreMenu()

		menu.addSeparator()

		menu.addQuitItem()
	}
}
