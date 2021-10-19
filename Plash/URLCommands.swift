import Cocoa
import Defaults

extension AppState {
	func setUpURLCommands() {
		SSPublishers.appOpenURL
			.sink { [self] in
				handleURLCommands($0)
			}
			.store(in: &cancellables)
	}

	private func handleURLCommands(_ urlComponents: URLComponents) {
		guard urlComponents.scheme == "plash" else {
			return
		}

		let command = urlComponents.path
		let parameters = urlComponents.queryDictionary

		func showMessage(_ message: String) {
			NSApp.activate(ignoringOtherApps: true)
			NSAlert.showModal(title: message)
		}

		switch command {
		case "add":
			guard
				let urlString = parameters["url"]?.trimmed,
				let url = URL(string: urlString),
				url.isValid
			else {
				showMessage("Invalid URL for the “add” command.")
				return
			}

			WebsitesController.shared.add(url, title: parameters["title"]?.trimmed.nilIfEmpty)
		case "reload":
			reloadWebsite()
		case "next":
			WebsitesController.shared.makeNextCurrent()
		case "previous":
			WebsitesController.shared.makePreviousCurrent()
		case "random":
			WebsitesController.shared.makeRandomCurrent()
		case "toggle-browsing-mode":
			toggleBrowsingMode()
		default:
			showMessage("The command “\(command)” is not supported.")
		}
	}
}
