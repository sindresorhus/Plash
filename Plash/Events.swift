import Cocoa
import Defaults
import KeyboardShortcuts

extension AppDelegate {
	func setUpEvents() {
		menu.onUpdate = { [self] _ in
			updateMenu()
		}

		webViewController.onLoaded = { [self] error in
			webViewError = error

			guard error == nil else {
				return
			}

			// TODO: When targeting macOS 11, I might be able to set `.pageLevel` before loading the page.
			// Set the persisted zoom level.
			let zoomLevel = webViewController.webView.zoomLevelWrapper
			if zoomLevel != 1 {
				webViewController.webView.zoomLevelWrapper = zoomLevel
			}

			if let url = Defaults[.url] {
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

		Defaults.observe(.url, options: []) { [self] change in
			resetTimer()
			loadURL(change.newValue)
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

		Defaults.observe(.invertColors, options: []) { [self] _ in
			recreateWebViewAndReload()
		}
			.tieToLifetime(of: self)

		Defaults.observe(.customCSS, options: []) { [self] _ in
			recreateWebViewAndReload()
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

		KeyboardShortcuts.onKeyUp(for: .toggleBrowsingMode) {
			Defaults[.isBrowsingMode].toggle()
		}

		KeyboardShortcuts.onKeyUp(for: .reload) { [self] in
			loadUserURL()
		}
	}
}
