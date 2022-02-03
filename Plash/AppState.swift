import SwiftUI
import Combine
import Sentry
import Defaults

@MainActor
final class AppState: ObservableObject {
	static let shared = AppState()

	var cancellables = Set<AnyCancellable>()

	let menu = SSMenu()
	let powerSourceWatcher = PowerSourceWatcher()

	private(set) lazy var statusItem = with(NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)) {
		$0.isVisible = true
		$0.behavior = [.removalAllowed, .terminationOnRemoval]
		$0.menu = menu
		$0.button?.image = Constants.menuBarIcon
	}

	private(set) lazy var statusItemButton = statusItem.button!

	private(set) lazy var webViewController = WebViewController()

	private(set) lazy var desktopWindow = with(DesktopWindow(screen: Defaults[.display].screen)) {
		$0.contentView = webViewController.webView
		$0.contentView?.isHidden = true
	}

	var isBrowsingMode = false {
		didSet {
			desktopWindow.isInteractive = isBrowsingMode
			desktopWindow.alphaValue = isBrowsingMode ? 1 : Defaults[.opacity]
			resetTimer()
		}
	}

	var isEnabled = true {
		didSet {
			resetTimer()
			statusItemButton.appearsDisabled = !isEnabled

			if isEnabled {
				loadUserURL()
				desktopWindow.makeKeyAndOrderFront(self)
			} else {
				// TODO: Properly unload the web view instead of just clearing and hiding it.
				desktopWindow.orderOut(self)
				loadURL("about:blank")
			}
		}
	}

	var isScreenLocked = false

	var reloadTimer: Timer?

	var webViewError: Error? {
		didSet {
			if let error = webViewError {
				statusItemButton.toolTip = "Error: \(error.localizedDescription)"
				statusItemButton.contentTintColor = .systemRed

				// TODO: Also present the error when the user just added it from the input box as then it's also "interactive".
				if
					isBrowsingMode,
					!error.localizedDescription.contains("No internet connection")
				{
					error.presentAsModal()
				}

				return
			}

			statusItemButton.contentTintColor = nil
		}
	}

	init() {
		setUpConfig()

		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		// Make the invisible native SwitUI window not block access to the desktop. (macOS 12.0)
		NSApp.windows.first?.ignoresMouseEvents = true

		migrate()
		_ = statusItemButton
		_ = desktopWindow
		setUpEvents()
		showWelcomeScreenIfNeeded()
		SSApp.requestReviewAfterBeingCalledThisManyTimes([5, 50, 500])

		#if DEBUG
//		SSApp.showSettingsWindow()
//		WebsitesWindowController.showWindow()
		#endif
	}

	private func setUpConfig() {
		UserDefaults.standard.register(defaults: [
			"NSApplicationCrashOnExceptions": true
		])

		#if !DEBUG
		SentrySDK.start {
			$0.dsn = "https://4ad446a4961b44ff8dc808a08379914e@o844094.ingest.sentry.io/6140750"
			$0.enableSwizzling = false
		}
		#endif

		// TODO: Remove in 2023.
		SSApp.runOnce(identifier: "migrateToDefaultav5") {
			Defaults.migrate(.websites, to: .v5)
		}
	}

	func handleMenuBarIcon() {
		statusItem.isVisible = true

		delay(seconds: 5) { [self] in
			guard Defaults[.hideMenuBarIcon] else {
				return
			}

			statusItem.isVisible = false
		}
	}

	func handleAppReopen() {
		handleMenuBarIcon()
	}

	func setEnabledStatus() {
		isEnabled = !isScreenLocked && !(Defaults[.deactivateOnBattery] && powerSourceWatcher?.powerSource.isUsingBattery == true)
	}

	func resetTimer() {
		reloadTimer?.invalidate()
		reloadTimer = nil

		guard
			isEnabled,
			!isBrowsingMode,
			let reloadInterval = Defaults[.reloadInterval]
		else {
			return
		}

		reloadTimer = Timer.scheduledTimer(withTimeInterval: reloadInterval, repeats: true) { [self] _ in
			loadUserURL()
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

	func reloadWebsite() {
		loadUserURL()
	}

	func loadUserURL() {
		loadURL(WebsitesController.shared.current?.url)
	}

	func toggleBrowsingMode() {
		Defaults[.isBrowsingMode].toggle()
	}

	func loadURL(_ url: URL?) {
		webViewError = nil

		guard var url = url else {
			return
		}

		do {
			url = try replacePlaceholders(of: url) ?? url
		} catch {
			error.presentAsModal()
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

		webViewController.loadURL(url)

		// TODO: Add a callback to `loadURL` when it's done loading instead.
		// TODO: Fade in the web view.
		delay(seconds: 1) { [self] in
			desktopWindow.contentView?.isHidden = false
		}
	}

	/**
	Replaces app-specific placeholder strings in the given URL with a corresponding value.
	*/
	func replacePlaceholders(of url: URL) throws -> URL? {
		// Here we swap out `[[screenWidth]]` and `[[screenHeight]]` for their actual values.
		// We proceed only if we have an `NSScreen` to work with.
		guard let screen = desktopWindow.targetScreen?.withFallbackToMain ?? .main else {
			return nil
		}

		return try url
			.replacingPlaceholder("[[screenWidth]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.width))
			.replacingPlaceholder("[[screenHeight]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.height))
	}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationWillFinishLaunching(_ notification: Notification) {
		// It's important that this is here so it's registered in time.
		AppState.shared.setUpURLCommands()
	}

	// Does not work on macOS 12 because of `WindowGroup`: https://github.com/feedback-assistant/reports/issues/246
	// This is only run when the app is started when it's already running.
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		AppState.shared.handleAppReopen()
		return true
	}
}
