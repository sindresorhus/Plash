import Foundation

struct Website: Hashable, Codable, Identifiable {
	let id: UUID
	var isCurrent: Bool
	var url: URL
	@DecodableDefault.EmptyString var title: String
	var invertColors: Bool
	var usePrintStyles: Bool
	var css = ""
	var javaScript = ""

	var subtitle: String { url.humanString }

	var menuTitle: String { title.isEmpty ? subtitle : title }

	// The space is there to force `NSMenu` to display an empty line.
	var tooltip: String { "\(title)\n \n\(subtitle)" }

	var thumbnailCacheKey: String { url.isFileURL ? url.tildePath : (url.host ?? "") }

	func makeCurrent() {
		WebsitesController.shared.current = self
	}

	func remove() {
		WebsitesController.shared.remove(self)
	}
}
