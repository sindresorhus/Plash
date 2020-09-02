import Cocoa
import Combine
import AppCenter
import AppCenterCrashes
import Defaults

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
				statusItemButton.toolTip = "Error: \(error.localizedDescription)"
				statusItemButton.contentTintColor = .systemRed

				// TODO: Also present the error when the user just added it from the input box as then it's also "interactive".
				if isBrowsingMode {
					NSApp.presentError(error)
				}

				return
			}

			statusItemButton.contentTintColor = nil
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

	func setEnabledStatus() {
		isEnabled = !(Defaults[.deactivateOnBattery] && powerSourceWatcher?.powerSource.isUsingBattery == true)
	}

	func resetTimer() {
		reloadTimer?.invalidate()
		reloadTimer = nil

		guard !isBrowsingMode else {
			return
		}

		guard let reloadInterval = Defaults[.reloadInterval] else {
			return
		}

		reloadTimer = Timer.scheduledTimer(withTimeInterval: reloadInterval, repeats: true) { _ in
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

		guard var url = url else {
			return
		}

		url = replacePlaceholders(of: url) ?? url

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

		webViewController.loadURL(url)

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

			guard url.appendingPathComponent("index.html", isDirectory: false).exists else {
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

	func showWelcomeScreenIfNeeded() {
		guard App.isFirstLaunch else {
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

				If you have any feedback, bug reports, or feature requests, kindly use the “Send Feedback” button in the Plash menu. We respond to all submissions and reported issues will be dealt with swiftly. It's preferable that you report bugs this way rather than as an App Store review, since the App Store will not allow us to contact you for more information.
				"""
		)

		statusItemButton.playRainbowAnimation()

		delay(seconds: 1) {
			self.statusItemButton.performClick(nil)
		}
	}

	/**
	Replaces application-specific placeholder strings in the given
	URL with a corresponding value.
	*/
	private func replacePlaceholders(of url: URL) -> URL? {
		// Here we swap out [[screenWidth]] and [[screenHeight]] for their actual values.
		// We proceed only if we have an NSScreen to work with.
		guard let screen = desktopWindow.targetScreen?.withFallbackToMain ?? .main else {
			print("No screen was found to read dimensions from!")
			return nil
		}

		do {
			return try url
				.replacingPlaceholder("[[screenWidth]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.width))
				.replacingPlaceholder("[[screenHeight]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.height))
		} catch {
			print(error.localizedDescription)
			return nil
		}
	}
}
