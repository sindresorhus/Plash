import Foundation
import Defaults

struct Website: Hashable, Codable, Identifiable {
	let id: UUID
	var isCurrent: Bool
	var url: URL
	@DecodableDefault.EmptyString var title: String
	@DecodableDefault.Custom<InvertColors> var invertColors2
	var usePrintStyles: Bool
	var css = ""
	var javaScript = ""

	var subtitle: String { url.humanString }

	var menuTitle: String { title.isEmpty ? subtitle : title }

	// The space is there to force `NSMenu` to display an empty line.
	var tooltip: String { "\(title)\n \n\(subtitle)".trimmed }

	var thumbnailCacheKey: String { url.isFileURL ? url.tildePath : (url.host ?? "") }

	func makeCurrent() {
		WebsitesController.shared.current = self
	}

	func remove() {
		WebsitesController.shared.remove(self)
	}
}

extension Website {
	enum InvertColors: String, CaseIterable, Codable {
		case never
		case always
		case darkMode

		var title: String {
			switch self {
			case .never:
				return "Never"
			case .always:
				return "Always"
			case .darkMode:
				return "When in dark mode"
			}
		}
	}
}

extension Website.InvertColors: DecodableDefault.Source {
	static let defaultValue = never
}
