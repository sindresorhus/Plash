import Cocoa
import Defaults

extension AppDelegate {
	private func addInfoMenuItem() {
		guard var url = WebsitesController.shared.current?.url else {
			return
		}

		do {
			url = try replacePlaceholders(of: url) ?? url
		} catch {
			error.presentAsModal()
			return
		}

		let maxLength = 30

		if
			let title = webViewController.webView.title,
			!title.isEmpty
		{
			let menuItem = menu.addDisabled(title.truncating(to: maxLength))
			menuItem.toolTip = title
		}

		let urlString = url.isFileURL ? url.tildePath : url.absoluteString

		var newUrlString = urlString
		if urlString.count > maxLength {
			newUrlString = urlString.removingSchemeAndWWWFromURL
		}

		let menuItem = menu.addDisabled(newUrlString.truncating(to: maxLength))
		menuItem.toolTip = urlString
	}

	private func createSwitchMenu() -> SSMenu {
		let menu = SSMenu()

		for website in WebsitesController.shared.all {
			let menuItem = menu.addCallbackItem(
				website.title.truncating(to: 30),
				isChecked: website.isCurrent
			) { _ in
				website.makeCurrent()
			}

			menuItem.toolTip = website.title
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
			url: URL("https://sindresorhus.com/plash")
		)

		menu.addUrlItem(
			"Roadmap",
			url: URL("https://github.com/sindresorhus/Plash/issues")
		)

		menu.addUrlItem(
			"Examples",
			url: URL("https://github.com/sindresorhus/Plash/issues/1")
		)

		menu.addSeparator()

		menu.addUrlItem(
			"Rate on the App Store",
			url: URL("macappstore://apps.apple.com/app/id1494023538?action=write-review")
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

			// TODO: Find a better label name.
			menu.addItem("Switch")
				.withSubmenu(createSwitchMenu())

			menu.addSeparator()
		}

		menu.addCallbackItem("Add Website…") { _ in
			AddWebsiteWindowController.showWindow()
		}

		menu.addCallbackItem("Websites…") { _ in
			WebsitesWindowController.showWindow()
		}

		menu.addSeparator()

		menu.addCallbackItem(
			"Reload",
			isEnabled: WebsitesController.shared.current != nil
		) { [weak self] _ in
			self?.loadUserURL()
		}
			.setShortcut(for: .reload)

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

		menu.addCallbackItem("Preferences…", key: ",") { _ in
			SettingsWindowController.showWindow()
		}

		let moreMenuItem = menu.addItem("More")
		moreMenuItem.submenu = createMoreMenu()

		menu.addSeparator()

		menu.addQuitItem()
	}
}
