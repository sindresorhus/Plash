import SwiftUI
import Combine
import Defaults

struct Website: Hashable, Codable, Identifiable {
	let id: UUID
	var isCurrent: Bool
	var url: URL
	var invertColors: Bool
	var usePrintStyles: Bool
	var css = ""
	var javaScript = ""

	var title: String {
		url.isFileURL ? url.tildePath : url.absoluteString.removingSchemeAndWWWFromURL
	}

	var thumbnailCacheKey: String { url.isFileURL ? url.tildePath : (url.host ?? "") }

	func makeCurrent() {
		WebsitesController.shared.current = self
	}

	func remove() {
		WebsitesController.shared.remove(self)
	}
}

final class WebsitesController {
	static let shared = WebsitesController()

	private var cancellables = Set<AnyCancellable>()
	private var _current: Website? { all.first(where: \.isCurrent) }
	private var nextCurrent: Website? { all.elementAfterOrFirst(_current) }
	private var previousCurrent: Website? { all.elementBeforeOrLast(_current) }

	let thumbnailCache = SimpleImageCache<String>(diskCacheName: "websiteThumbnailCache")

	/// The current website.
	var current: Website? {
		get { _current ?? all.first }
		set {
			guard let website = newValue else {
				all = all.modifying {
					$0.isCurrent = false
				}

				return
			}

			makeCurrent(website)
		}
	}

	/// All websites.
	var all: [Website] {
		get { Defaults[.websites] }
		set {
			Defaults[.websites] = newValue
		}
	}

	init() {
		setUpEvents()
		thumbnailCache.prewarmCacheFromDisk(for: all.map(\.thumbnailCacheKey))
	}

	private func setUpEvents() {
		Defaults.publisher(.websites)
			.sink { change in
				// Ensures there's always a current website.
				if
					change.newValue.allSatisfy(!\.isCurrent),
					let website = change.newValue.first
				{
					website.makeCurrent()
				}
			}
			.store(in: &cancellables)
	}

	/// Make a website the current one.
	private func makeCurrent(_ website: Website) {
		all = all.modifying {
			$0.isCurrent = $0.id == website.id
		}
	}

	/// Add a website.
	func add(_ website: Website) {
		// The order here is important.
		all.append(website)
		current = website
	}

	/// Remove a website.
	func remove(_ website: Website) {
		all = all.removingAll(website)
	}

	/// Makes the next website the current one.
	func makeNextCurrent() {
		guard let website = nextCurrent else {
			return
		}

		makeCurrent(website)
	}

	/// Makes the previous website the current one.
	func makePreviousCurrent() {
		guard let website = previousCurrent else {
			return
		}

		makeCurrent(website)
	}
}
