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
			) { _ in
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

		menu.addCallbackItem("Send Feedback…") { _ in
			SSApp.openSendFeedbackPage()
		}

		menu.addSeparator()

		menu.addUrlItem(
			"Website",
			url: "https://sindresorhus.com/plash"
		)

		menu.addUrlItem(
			"Examples",
			url: "https://github.com/sindresorhus/Plash/issues/1"
		)

		menu.addUrlItem(
			"Scripting",
			url: "https://github.com/sindresorhus/Plash#scripting"
		)

		menu.addSeparator()

		menu.addUrlItem(
			"Rate on the App Store",
			url: "macappstore://apps.apple.com/app/id1494023538?action=write-review"
		)

		menu.addMoreAppsItem()

		return menu
	}

	private func addWebsiteItems() {
		if let error = webViewError {
			menu.addDisabled("Error: \(error.localizedDescription)".wrapped(atLength: 36).attributedString)
			menu.addSeparator()
		}

		addInfoMenuItem()

		menu.addSeparator()

		if WebsitesController.shared.all.count > 1 {
			menu.addCallbackItem("Next Website") { _ in
				WebsitesController.shared.makeNextCurrent()
			}
				.setShortcut(for: .nextWebsite)

			menu.addCallbackItem("Previous Website") { _ in
				WebsitesController.shared.makePreviousCurrent()
			}
				.setShortcut(for: .previousWebsite)

			menu.addCallbackItem(
				"Reload Website",
				isEnabled: WebsitesController.shared.current != nil
			) { [weak self] _ in
				self?.loadUserURL()
			}
				.setShortcut(for: .reload)

			menu.addItem("Switch")
				.withSubmenu(createSwitchMenu())

			menu.addSeparator()
		}

		menu.addCallbackItem("Add Website…") { _ in
			WebsitesWindowController.showWindow()

			// TODO: Find a better way to do this.
			NotificationCenter.default.post(name: .showAddWebsiteDialog, object: nil)
		}

		menu.addCallbackItem("Websites…") { _ in
			WebsitesWindowController.showWindow()
		}

		menu.addSeparator()

		menu.addCallbackItem(
			"Browsing Mode",
			isEnabled: WebsitesController.shared.current != nil,
			isChecked: Defaults[.isBrowsingMode]
		) { menuItem in
			Defaults[.isBrowsingMode] = !menuItem.isChecked

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
