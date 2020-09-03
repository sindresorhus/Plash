import Cocoa
import Defaults
import KeyboardShortcuts

extension AppDelegate {
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

		KeyboardShortcuts.onKeyUp(for: .reload) {
			self.loadUserURL()
		}
	}
}
