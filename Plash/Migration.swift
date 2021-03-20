import Foundation
import Defaults

extension AppDelegate {
	private func migrateToWebsiteStruct() {
		guard let url = Defaults[.url] else {
			return
		}

		Defaults[.url] = nil

		WebsitesController.shared.add(
			Website(
				id: UUID(),
				isCurrent: true,
				url: url,
				invertColors: Defaults[.invertColors],
				css: Defaults[.customCSS]
			)
		)
	}

	func migrate() {
		migrateToWebsiteStruct()
	}
}
