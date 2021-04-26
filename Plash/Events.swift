import Cocoa
import Defaults
import KeyboardShortcuts

extension AppDelegate {
	func setUpEvents() {
		menu.onUpdate = { [self] _ in
			updateMenu()
		}

		webViewController.onLoaded = { [self] (error, loadedInBackground) in
			webViewError = error

			if loadedInBackground {
				DispatchQueue.main.asyncAfter(deadline: .now()) {
					desktopWindow.contentView?.alphaValue = 1
					NSView.animate(
						duration: 0.5,
						delay: 0,
						timingFunction: CAMediaTimingFunction(name: .easeOut),
						animations: {
							desktopWindow.contentView?.alphaValue = 0
						},
						completion: {
							webViewController.view.isHidden = true
							webViewController.webView = webViewController.backgroundWebView
							webViewController.view = webViewController.webView
							desktopWindow.contentView = webViewController.view
							desktopWindow.contentView?.isHidden = true
							desktopWindow.contentView?.fadeInOut(duration: 0.5, delay: 0, toHidden: false)
						}
					)
				}
			}

			guard error == nil else {
				return
			}

			// TODO: When targeting macOS 11, I might be able to set `.pageLevel` before loading the page.
			// Set the persisted zoom level.
			let zoomLevel = webViewController.webView.zoomLevelWrapper
			if zoomLevel != 1 {
				webViewController.webView.zoomLevelWrapper = zoomLevel
			}

			if let url = WebsitesController.shared.current?.url {
				let title = webViewController.webView.title.map { "\($0)\n" } ?? ""
				let urlString = url.isFileURL ? url.lastPathComponent : url.absoluteString
				statusItemButton.toolTip = "\(title)\(urlString)"
			} else {
				statusItemButton.toolTip = ""
			}
		}

		powerSourceWatcher?.didChangePublisher
			.sink { [self] _ in
				guard Defaults[.deactivateOnBattery] else {
					return
				}

				setEnabledStatus()
			}
			.store(in: &cancellables)

		NSWorkspace.Publishers.didWake
			.sink { [self] in
				loadUserURL()
			}
			.store(in: &cancellables)

		// TODO: Use `.publisher` for all of these.

		Defaults.observe(.websites, options: []) { [self] _ in
			resetTimer()
			recreateWebViewAndReload()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.isBrowsingMode) { [self] change in
			isBrowsingMode = change.newValue
		}
			.tieToLifetime(of: self)

		Defaults.observe(.opacity) { [self] change in
			desktopWindow.alphaValue = isBrowsingMode ? 1 : CGFloat(change.newValue)
		}
			.tieToLifetime(of: self)

		Defaults.observe(.reloadInterval) { [self] _ in
			resetTimer()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.display, options: []) { [self] change in
			desktopWindow.targetScreen = change.newValue.screen
		}
			.tieToLifetime(of: self)

		Defaults.observe(.deactivateOnBattery) { [self] _ in
			setEnabledStatus()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.showOnAllSpaces) { [self] change in
			desktopWindow.collectionBehavior.toggleExistence(.canJoinAllSpaces, shouldExist: change.newValue)
		}
			.tieToLifetime(of: self)

		Defaults.observe(.bringBrowsingModeToFront, options: []) { [self] _ in
			desktopWindow.isInteractive = desktopWindow.isInteractive
		}
			.tieToLifetime(of: self)

		KeyboardShortcuts.onKeyUp(for: .toggleBrowsingMode) {
			Defaults[.isBrowsingMode].toggle()
		}

		KeyboardShortcuts.onKeyUp(for: .reload) { [self] in
			loadUserURL()
		}

		KeyboardShortcuts.onKeyUp(for: .nextWebsite) {
			WebsitesController.shared.makeNextCurrent()
		}

		KeyboardShortcuts.onKeyUp(for: .previousWebsite) {
			WebsitesController.shared.makePreviousCurrent()
		}
	}
}
