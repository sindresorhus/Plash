import Cocoa
import Defaults
import KeyboardShortcuts

extension AppState {
	func setUpEvents() {
		menu.needsUpdatePublisher
			.sink { [self] _ in
				updateMenu()
			}
			.store(in: &cancellables)

		webViewController.didLoadPublisher
			.convertToResult()
			.sink { [self] result in
				switch result {
				case .success:
					// Set the persisted zoom level.
					// This must be here as `webView.url` needs to have been set.
					let zoomLevel = webViewController.webView.zoomLevelWrapper
					if zoomLevel != 1 {
						webViewController.webView.zoomLevelWrapper = zoomLevel
					}

					statusItemButton.toolTip = WebsitesController.shared.current?.tooltip
				case .failure(let error):
					webViewError = error
				}
			}
			.store(in: &cancellables)

		powerSourceWatcher?.didChangePublisher
			.sink { [self] _ in
				guard Defaults[.deactivateOnBattery] else {
					return
				}

				setEnabledStatus()
			}
			.store(in: &cancellables)

		SSPublishers.deviceDidWake
			.sink { [self] in
				loadUserURL()
			}
			.store(in: &cancellables)

		SSPublishers.isScreenLocked
			.sink { [self] in
				isScreenLocked = $0
				setEnabledStatus()
			}
			.store(in: &cancellables)

		// We use this instead of `applicationShouldHandleReopen` because of the macOS bug.
		// https://github.com/feedback-assistant/reports/issues/246
		NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
			.sink { [self] _ in
				handleAppReopen()
			}
			.store(in: &cancellables)

		Defaults.publisher(.websites, options: [])
			.receive(on: DispatchQueue.main)
			.sink { [self] _ in
				resetTimer()
				recreateWebViewAndReload()
			}
			.store(in: &cancellables)

		Defaults.publisher(.isBrowsingMode)
			.receive(on: DispatchQueue.main)
			.sink { [self] change in
				isBrowsingMode = change.newValue
			}
			.store(in: &cancellables)

		Defaults.publisher(.hideMenuBarIcon)
			.sink { [self] _ in
				handleMenuBarIcon()
			}
			.store(in: &cancellables)

		Defaults.publisher(.opacity)
			.sink { [self] change in
				desktopWindow.alphaValue = isBrowsingMode ? 1 : change.newValue
			}
			.store(in: &cancellables)

		Defaults.publisher(.reloadInterval)
			.sink { [self] _ in
				resetTimer()
			}
			.store(in: &cancellables)

		Defaults.publisher(.display, options: [])
			.sink { [self] change in
				desktopWindow.targetScreen = change.newValue.screen
			}
			.store(in: &cancellables)

		Defaults.publisher(.deactivateOnBattery)
			.sink { [self] _ in
				setEnabledStatus()
			}
			.store(in: &cancellables)

		Defaults.publisher(.showOnAllSpaces)
			.sink { [self] change in
				desktopWindow.collectionBehavior.toggleExistence(.canJoinAllSpaces, shouldExist: change.newValue)
			}
			.store(in: &cancellables)

		Defaults.publisher(.bringBrowsingModeToFront, options: [])
			.sink { [self] _ in
				desktopWindow.isInteractive = desktopWindow.isInteractive
			}
			.store(in: &cancellables)

		Defaults.publisher(.muteAudio, options: [])
			.receive(on: DispatchQueue.main)
			.sink { [self] _ in
				recreateWebViewAndReload()
			}
			.store(in: &cancellables)

		KeyboardShortcuts.onKeyUp(for: .toggleBrowsingMode) {
			Defaults[.isBrowsingMode].toggle()
		}

		KeyboardShortcuts.onKeyUp(for: .reload) { [self] in
			reloadWebsite()
		}

		KeyboardShortcuts.onKeyUp(for: .nextWebsite) {
			WebsitesController.shared.makeNextCurrent()
		}

		KeyboardShortcuts.onKeyUp(for: .previousWebsite) {
			WebsitesController.shared.makePreviousCurrent()
		}

		KeyboardShortcuts.onKeyUp(for: .randomWebsite) {
			WebsitesController.shared.makeRandomCurrent()
		}
	}
}
