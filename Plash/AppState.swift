import SwiftUI
import Combine

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
		$0.button!.image = .menuBarIcon
		$0.button!.setAccessibilityTitle(SSApp.name)
	}

	private(set) lazy var statusItemButton = statusItem.button!

	private(set) lazy var webViewController = WebViewController()

	// Main window hosting the primary web view
	private(set) lazy var desktopWindow = with(DesktopWindow(display: Defaults[.display])) {
		$0.contentView = webViewController.webView
		$0.contentView?.isHidden = true
	}

	// Extra windows/controllers when showing on ALL displays (Defaults[.display] == nil)
	private var extraWindows: [UUID: (window: DesktopWindow, controller: WebViewController)] = [:]

	// Convenience collections for acting on all windows/controllers
	private var allWindows: [DesktopWindow] { [desktopWindow] + extraWindows.values.map { $0.window } }
	private var allControllers: [WebViewController] { [webViewController] + extraWindows.values.map { $0.controller } }

	var isBrowsingMode = false {
		didSet {
			guard isEnabled else { return }
			for window in allWindows {
				window.isInteractive = isBrowsingMode
				window.alphaValue = isBrowsingMode ? 1 : Defaults[.opacity]
			}
			resetTimer()
		}
	}

	var isEnabled = true {
		didSet {
			resetTimer()
			statusItemButton.appearsDisabled = !isEnabled

			if isEnabled {
				loadUserURL()
				for window in allWindows { presentWindow(window) }
			} else {
				// TODO: Properly unload the web view instead of just clearing and hiding it.
				for window in allWindows { window.orderOut(self) }
				loadURL("about:blank")
			}
		}
	}

	var isScreenLocked = false

	var isManuallyDisabled = false {
		didSet { setEnabledStatus() }
	}

	var reloadTimer: Timer?

	var webViewError: Error? {
		didSet {
			if let webViewError {
				statusItemButton.toolTip = "Error: \\(webViewError.localizedDescription)"
				// TODO: There's a macOS bug that makes it black instead of a color.
				// statusItemButton.contentTintColor = .systemRed
				if isBrowsingMode, !webViewError.localizedDescription.contains("No internet connection") {
					webViewError.presentAsModal()
				}
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

		// Ensure windows match current display selection at launch.
		syncWindowsForCurrentDisplaySelection()

		// Keep windows in sync with screen topology when showing on ALL.
		NSScreen.publisher
			.sink { [weak self] in self?.handleScreensChanged() }
			.store(in: &cancellables)

		// Load the initial website into all windows created above so that
		// on launch with "ALL" selected, each display gets content.
		loadUserURL()

		#if DEBUG
		// SSApp.showSettingsWindow()
		// Constants.openWebsitesWindow()
		#endif
	}

	// Present a window without trying to make it key unless it's interactive.
	private func presentWindow(_ window: DesktopWindow) {
		if window.isInteractive {
			window.makeKeyAndOrderFront(self)
		} else {
			window.orderFrontRegardless()
		}
	}

	func handleMenuBarIcon() {
		statusItem.isVisible = true
		delay(.seconds(5)) { [self] in
			guard Defaults[.hideMenuBarIcon] else { return }
			statusItem.isVisible = false
		}
	}

	func handleAppReopen() {
		handleMenuBarIcon()
		// Recreate web views for extra windows, mirroring main window behavior.
		for (id, pair) in extraWindows {
			pair.controller.recreateWebView()
			extraWindows[id]?.window.contentView = pair.controller.webView
		}
	}

	func setEnabledStatus() {
		isEnabled = !isManuallyDisabled && !isScreenLocked && !(Defaults[.deactivateOnBattery] && powerSourceWatcher?.powerSource.isUsingBattery == true)
	}

	func resetTimer() {
		reloadTimer?.invalidate()
		reloadTimer = nil

		guard isEnabled, !isBrowsingMode, let reloadInterval = Defaults[.reloadInterval] else { return }

		reloadTimer = Timer.scheduledTimer(withTimeInterval: reloadInterval, repeats: true) { [self] _ in
			Task { @MainActor in
				reloadWebsite()
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
		// We always load the website the user specified in case it's a redirect that may change on each call.
		loadUserURL()
		// webViewController.reloadCurrentPageFromOrigin()
	}

	func loadUserURL() {
		loadURL(WebsitesController.shared.current?.url)
	}

	func toggleBrowsingMode() { Defaults[.isBrowsingMode].toggle() }

	func loadURL(_ url: URL?) {
		webViewError = nil

		guard let url, url.isValid else { return }

		// Load into the main window/controller.
		do {
			let replaced = try replacePlaceholders(of: url, for: desktopWindow.targetDisplay) ?? url
			webViewController.loadURL(replaced)
		} catch {
			error.presentAsModal()
		}

		// Load into any extra windows/controllers.
		for (_, pair) in extraWindows {
			do {
				let replaced = try replacePlaceholders(of: url, for: pair.window.targetDisplay) ?? url
				pair.controller.loadURL(replaced)
			} catch {
				error.presentAsModal()
			}
		}

		// TODO: Add a callback to `loadURL` when it's done loading instead.
		// TODO: Fade in the web view.
		delay(.seconds(1)) { [self] in
			for window in allWindows {
				window.contentView?.isHidden = false
			}
		}
	}

	// MARK: - Placeholder helpers

	/**
	Replaces app-specific placeholder strings in the given URL with values for the current main window's display.
	*/
	func replacePlaceholders(of url: URL) throws -> URL? {
		try replacePlaceholders(of: url, for: desktopWindow.targetDisplay)
	}

	private func replacePlaceholders(of url: URL?, for display: Display?) throws -> URL? {
		guard let url else { return nil }

		let frame: CGRect? = {
			if let screen = display?.screen ?? .main {
				return screen.frameWithoutStatusBar
			} else {
				return NSScreen.main?.frameWithoutStatusBar
			}
		}()

		guard let frame else { return nil }

		return try url
			.replacingPlaceholder("[[screenWidth]]", with: String(format: "%.0f", frame.width))
			.replacingPlaceholder("[[screenHeight]]", with: String(format: "%.0f", frame.height))
	}

	// MARK: - Multi-display helpers

	private func syncWindowsForCurrentDisplaySelection() {
		if let chosen = Defaults[.display] {
			// Single-display mode.
			desktopWindow.targetDisplay = chosen
			// Tear down any extra windows.
			for (_, pair) in extraWindows { pair.window.orderOut(self) }
			extraWindows.removeAll()
			return
		}

		// ALL displays: one window per active display.
		desktopWindow.targetDisplay = .main

		let displays = Display.all
		let mainUUID = NSScreen.primary?.uuid

		// Add or update windows for each non-main display.
		for display in displays {
			if let mainUUID, display.id == mainUUID { continue }
			if let existing = extraWindows[display.id] {
				existing.window.targetDisplay = display
				continue
			}

			let controller = WebViewController()
			let window = DesktopWindow(display: display)
			window.contentView = controller.webView
			window.contentView?.isHidden = true
			window.collectionBehavior.toggleExistence(.canJoinAllSpaces, shouldExist: Defaults[.showOnAllSpaces])
			window.isInteractive = isBrowsingMode
			window.alphaValue = isBrowsingMode ? 1 : Defaults[.opacity]
			if isEnabled {
				presentWindow(window)
			} else {
				window.orderOut(self)
			}

			extraWindows[display.id] = (window, controller)
		}

		// Remove any windows whose displays no longer exist.
		let currentIDs = Set(displays.map { $0.id })
		for (id, pair) in extraWindows where !currentIDs.contains(id) {
			pair.window.orderOut(self)
			extraWindows.removeValue(forKey: id)
		}
	}

	func handleDisplaySelectionChange(_ newValue: Display?) {
		syncWindowsForCurrentDisplaySelection()
		// Reload URL to any newly created windows.
		loadUserURL()
		// Update visibility according to current enabled state.
		if isEnabled {
			for window in allWindows { presentWindow(window) }
		} else {
			for window in allWindows { window.orderOut(self) }
		}
	}

	func applyOpacity(_ opacity: Double) {
		for window in allWindows { window.alphaValue = isBrowsingMode ? 1 : opacity }
	}

	func applyShowOnAllSpaces(_ value: Bool) {
		for window in allWindows { window.collectionBehavior.toggleExistence(.canJoinAllSpaces, shouldExist: value) }
	}

	func refreshInteractiveLevels() {
		for window in allWindows { window.refreshInteractiveLevel() }
	}

	func handleScreensChanged() {
		guard Defaults[.display] == nil else { return }
		syncWindowsForCurrentDisplaySelection()
	}
}

