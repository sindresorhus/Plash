import Foundation
import Defaults

extension AppDelegate {
	private func migrateToWebsiteStruct() {
		guard let url = Defaults[.url]?.normalized() else {
			return
		}

		Defaults[.url] = nil

		WebsitesController.shared.add(
			Website(
				id: UUID(),
				isCurrent: true,
				url: url,
				invertColors: Defaults[.invertColors],
				usePrintStyles: false,
				css: Defaults[.customCSS]
			)
		)
	}

	func migrate() {
		migrateToWebsiteStruct()
	}
}
