import Cocoa
import Defaults

extension AppState {
	private func addInfoMenuItem() {
		guard let website = WebsitesController.shared.current else {
			return
		}

		var url = website.url
		do {
			url = try replacePlaceholders(of: url) ?? url
		} catch {
			error.presentAsModal()
			return
		}

		let maxLength = 30

		if !website.menuTitle.isEmpty {
			let menuItem = menu.addDisabled(website.menuTitle.truncating(to: maxLength))
			menuItem.toolTip = website.tooltip
		}
	}

	private func createSwitchMenu() -> SSMenu {
		let menu = SSMenu()

		for website in WebsitesController.shared.all {
			let menuItem = menu.addCallbackItem(
				website.menuTitle.truncating(to: 40),
				isChecked: website.isCurrent
			) {
				website.makeCurrent()
			}

			menuItem.toolTip = website.tooltip
		}

		return menu
	}

	private func createMoreMenu() -> SSMenu {
		let menu = SSMenu()

		menu.addAboutItem()

		menu.addSeparator()

		menu.addCallbackItem("Send Feedback…") {
			SSApp.openSendFeedbackPage()
		}

		menu.addSeparator()

		menu.addLinkItem(
			"Website",
			destination: "https://sindresorhus.com/plash"
		)

		menu.addLinkItem(
			"Examples",
			destination: "https://github.com/sindresorhus/Plash/issues/1"
		)

		menu.addLinkItem(
			"Scripting",
			destination: "https://github.com/sindresorhus/Plash#scripting"
		)

		menu.addSeparator()

		menu.addLinkItem(
			"Rate on the App Store",
			destination: "macappstore://apps.apple.com/app/id1494023538?action=write-review"
		)

		menu.addMoreAppsItem()

		return menu
	}

	private func addWebsiteItems() {
		if let error = webViewError {
			menu.addDisabled("Error: \(error.localizedDescription)".wrapped(atLength: 36).nsAttributedString)
			menu.addSeparator()
		}

		addInfoMenuItem()

		menu.addSeparator()

		menu.addCallbackItem(
			"Reload",
			isEnabled: WebsitesController.shared.current != nil
		) { [weak self] in
			self?.loadUserURL()
		}
			.setShortcut(for: .reload)

		menu.addCallbackItem(
			"Browsing Mode",
			isEnabled: WebsitesController.shared.current != nil,
			isChecked: Defaults[.isBrowsingMode]
		) {
			Defaults[.isBrowsingMode].toggle()

			SSApp.runOnce(identifier: "activatedBrowsingMode") {
				DispatchQueue.main.async {
					NSAlert.showModal(
						title: "Browsing Mode lets you temporarily interact with the website. For example, to log into an account or scroll to a specific position on the website.",
						message: "If you don't currently see the website, you might need to hide some windows to reveal the desktop."
					)
				}
			}
		}
			.setShortcut(for: .toggleBrowsingMode)

		menu.addCallbackItem(
			"Edit…",
			isEnabled: WebsitesController.shared.current != nil
		) {
			WebsitesWindowController.showWindow()

			// TODO: Find a better way to do this.
			NotificationCenter.default.post(name: .showEditWebsiteDialog, object: nil)
		}

		menu.addSeparator()

		if WebsitesController.shared.all.count > 1 {
			menu.addCallbackItem("Next") {
				WebsitesController.shared.makeNextCurrent()
			}
				.setShortcut(for: .nextWebsite)

			menu.addCallbackItem("Previous") {
				WebsitesController.shared.makePreviousCurrent()
			}
				.setShortcut(for: .previousWebsite)

			menu.addCallbackItem("Random") {
				WebsitesController.shared.makeRandomCurrent()
			}
				.setShortcut(for: .randomWebsite)

			menu.addItem("Switch")
				.withSubmenu(createSwitchMenu())

			menu.addSeparator()
		}

		menu.addCallbackItem("Add Website…") {
			WebsitesWindowController.showWindow()

			// TODO: Find a better way to do this.
			NotificationCenter.default.post(name: .showAddWebsiteDialog, object: nil)
		}

		menu.addCallbackItem("Websites…") {
			WebsitesWindowController.showWindow()
		}
	}

	func updateMenu() {
		menu.removeAllItems()

		if isEnabled {
			addWebsiteItems()
		} else {
			menu.addDisabled("Deactivated While on Battery")
		}

		menu.addSeparator()

		menu.addSettingsItem()

		menu.addItem("More")
			.withSubmenu(createMoreMenu())

		menu.addSeparator()

		menu.addQuitItem()
	}
}
