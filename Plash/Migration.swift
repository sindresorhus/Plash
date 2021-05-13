import SwiftUI
import LinkPresentation
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
				invertColors: Defaults[.invertColors],
				usePrintStyles: false,
				css: Defaults[.customCSS]
			)
		)
	}

	private func fetchTitle(_ website: Binding<Website>) {
		guard website.wrappedValue.title.isEmpty else {
			return
		}

		LPMetadataProvider().startFetchingMetadata(for: website.wrappedValue.url) { metadata, error in
			guard
				error == nil,
				let title = metadata?.title
			else {
				return
			}

			DispatchQueue.main.async {
				website.wrappedValue.title = title
			}
		}
	}

	private func migrateToAddTitle() {
		for website in WebsitesController.shared.allBinding {
			fetchTitle(website)
		}
	}

	func migrate() {
		migrateToWebsiteStruct()
		migrateToAddTitle()
	}
}
