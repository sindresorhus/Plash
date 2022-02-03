import SwiftUI
import Combine
import Defaults
import LinkPresentation

final class WebsitesController {
	static let shared = WebsitesController()

	private var cancellables = Set<AnyCancellable>()
	private var _current: Website? { all.first(where: \.isCurrent) }
	private var nextCurrent: Website? { all.elementAfterOrFirst(_current) }
	private var previousCurrent: Website? { all.elementBeforeOrLast(_current) }

	var randomWebsiteIterator = Defaults[.websites].infiniteUniformRandomSequence().makeIterator()
	let thumbnailCache = SimpleImageCache<String>(diskCacheName: "websiteThumbnailCache")

	/**
	The current website.
	*/
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

	/**
	All websites.
	*/
	var all: [Website] {
		get { Defaults[.websites] }
		set {
			Defaults[.websites] = newValue
		}
	}

	let allBinding = Defaults.bindingCollection(for: .websites)

	init() {
		setUpEvents()
		thumbnailCache.prewarmCacheFromDisk(for: all.map(\.thumbnailCacheKey))
	}

	private func setUpEvents() {
		Defaults.publisher(.websites)
			.sink { [weak self] change in
				guard let self = self else {
					return
				}

				// Ensures there's always a current website.
				if
					change.newValue.allSatisfy(!\.isCurrent),
					let website = change.newValue.first
				{
					website.makeCurrent()
				}

				// We only reset the iterator if a website was added/removed.
				if change.newValue.map(\.id) != change.oldValue.map(\.id) {
					self.randomWebsiteIterator = self.all.infiniteUniformRandomSequence().makeIterator()
				}
			}
			.store(in: &cancellables)
	}

	/**
	Make a website the current one.
	*/
	private func makeCurrent(_ website: Website) {
		all = all.modifying {
			$0.isCurrent = $0.id == website.id
		}
	}

	/**
	Add a website.
	*/
	@discardableResult
	func add(_ website: Website) -> Binding<Website> {
		// The order here is important.
		all.append(website)
		current = website

		return allBinding[id: website.id]!
	}

	/**
	Add a website from a URL.

	Optionally, specify a title. If no title is given or if the title is empty, a title will be automatically fetched from the website.
	*/
	@discardableResult
	func add(_ websiteURL: URL, title: String? = nil) -> Binding<Website> {
		let websiteBinding = add(
			Website(
				id: UUID(),
				isCurrent: true,
				url: websiteURL,
				usePrintStyles: false
			)
		)

		if let title = title?.nilIfEmptyOrWhitespace {
			websiteBinding.wrappedValue.title = title
		} else {
			fetchTitleIfNeeded(for: websiteBinding)
		}

		return websiteBinding
	}

	/**
	Remove a website.
	*/
	func remove(_ website: Website) {
		all = all.removingAll(website)
	}

	/**
	Makes the next website the current one.
	*/
	func makeNextCurrent() {
		guard let website = nextCurrent else {
			return
		}

		makeCurrent(website)
	}

	/**
	Makes the previous website the current one.
	*/
	func makePreviousCurrent() {
		guard let website = previousCurrent else {
			return
		}

		makeCurrent(website)
	}

	/**
	Makes a random website in the list the current one.
	*/
	func makeRandomCurrent() {
		guard let website = randomWebsiteIterator.next() else {
			return
		}

		makeCurrent(website)
	}

	/**
	Fetch the title for a website in the background if the existing title is empty.
	*/
	func fetchTitleIfNeeded(for website: Binding<Website>) {
		guard website.wrappedValue.title.isEmpty else {
			return
		}

		Task { @MainActor in // TODO: Not sure if this is needed.
			let metadataProvider = LPMetadataProvider()
			metadataProvider.shouldFetchSubresources = false

			guard
				let metadata = try? await metadataProvider.startFetchingMetadata(for: website.wrappedValue.url),
				let title = metadata.title
			else {
				return
			}

			website.wrappedValue.title = title
		}
	}
}
