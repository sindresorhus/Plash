import SwiftUI
import Defaults

extension AppState {
	private func migrateToWebsiteStruct() {
		guard let url = Defaults[.url] else {
			return
		}

		Defaults[.url] = nil

		WebsitesController.shared.add(
			Website(
				id: UUID(),
				isCurrent: true,
				url: url.normalized(),
				usePrintStyles: false,
				css: Defaults[.customCSS]
			)
		)
	}

	private func migrateToAddTitle() {
		for website in WebsitesController.shared.allBinding {
			WebsitesController.shared.fetchTitleIfNeeded(for: website)
		}
	}

	func migrate() {
		// Remove in 2023.
		SSApp.runOnce(identifier: "migrateWebsiteStructAndAddTitle") {
			migrateToWebsiteStruct()
			migrateToAddTitle()
		}
	}
}
