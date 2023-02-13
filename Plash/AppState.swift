import SwiftUI

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
		$0.button!.image = Constants.menuBarIcon
		$0.button!.setAccessibilityTitle(SSApp.name)
	}

	private(set) lazy var statusItemButton = statusItem.button!

	private(set) lazy var webViewController = WebViewController()

	private(set) lazy var desktopWindow = with(DesktopWindow(display: Defaults[.display])) {
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
			if let webViewError {
				statusItemButton.toolTip = "Error: \(webViewError.localizedDescription)"

				// TODO: There's a macOS bug that makes it black instead of a color.
//				statusItemButton.contentTintColor = .systemRed

				// TODO: Also present the error when the user just added it from the input box as then it's also "interactive".
				if
					isBrowsingMode,
					!webViewError.localizedDescription.contains("No internet connection")
				{
					webViewError.presentAsModal()
				}

				return
			}

			statusItemButton.contentTintColor = nil
		}
	}

	private init() {
		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		_ = statusItemButton
		_ = desktopWindow
		setUpEvents()
		showWelcomeScreenIfNeeded()
		SSApp.requestReviewAfterBeingCalledThisManyTimes([8, 50, 500])

		#if DEBUG
//		SSApp.showSettingsWindow()
//		Constants.openWebsitesWindow()
		#endif
	}

	func handleMenuBarIcon() {
		statusItem.isVisible = true

		delay(.seconds(5)) { [self] in
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
			Task { @MainActor in
				loadUserURL()
			}
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

		guard
			var url,
			url.isValid
		else {
			return
		}

		do {
			url = try replacePlaceholders(of: url) ?? url
		} catch {
			error.presentAsModal()
			return
		}

		// TODO: This is just a quick fix. The proper fix is to create a new web view below the existing one (with no opacity), load the URL, if it succeeds, we fade out the old one while fading in the new one. If it fails, we discard the new web view.
		if
			!url.isFileURL,
			!Reachability.isOnlineExtensive()
		{
			webViewError = NSError.appError("No internet connection.")
			return
		}

		webViewController.loadURL(url)

		// TODO: Add a callback to `loadURL` when it's done loading instead.
		// TODO: Fade in the web view.
		delay(.seconds(1)) { [self] in
			desktopWindow.contentView?.isHidden = false
		}
	}

	/**
	Replaces app-specific placeholder strings in the given URL with a corresponding value.
	*/
	func replacePlaceholders(of url: URL) throws -> URL? {
		// Here we swap out `[[screenWidth]]` and `[[screenHeight]]` for their actual values.
		// We proceed only if we have an `NSScreen` to work with.
		guard let screen = desktopWindow.targetDisplay?.screen ?? .main else {
			return nil
		}

		return try url
			.replacingPlaceholder("[[screenWidth]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.width))
			.replacingPlaceholder("[[screenHeight]]", with: String(format: "%.0f", screen.visibleFrameWithoutStatusBar.height))
	}
}
