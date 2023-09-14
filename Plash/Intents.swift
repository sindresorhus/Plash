import AppIntents
import AppKit

struct AddWebsiteIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "AddWebsiteIntent"

	static let title: LocalizedStringResource = "Add Website"

	static let description = IntentDescription(
"""
Adds a website to Plash.

Returns the added website.
"""
	)

	@Parameter(title: "URL")
	var url: URL

	@Parameter(title: "Title")
	var title: String?

	static var parameterSummary: some ParameterSummary {
		Summary("Add \(\.$url) to Plash") {
			\.$title
		}
	}

	func perform() async throws -> some IntentResult & ReturnsValue<WebsiteAppEntity> {
		ensureRunning()
		let website = WebsitesController.shared.add(url, title: title?.nilIfEmptyOrWhitespace).wrappedValue
		return .result(value: .init(website))
	}
}

// Typo in the name, but we cannot fix it as this point.
struct RemoveWebsitesItent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "RemoveWebsitesIntent"

	static let title: LocalizedStringResource = "Remove Websites"

	static let description = IntentDescription("Removes the given websites from Plash.")

	@Parameter(title: "Websites")
	var websites: [WebsiteAppEntity]

	static var parameterSummary: some ParameterSummary {
		Summary("Remove websites \(\.$websites)")
	}

	func perform() async throws -> some IntentResult {
		ensureRunning()

		for website in websites {
			guard let website = website.toNative else {
				continue
			}

			WebsitesController.shared.remove(website)
		}

		return .result()
	}
}

@available(macOS, deprecated: 13, message: "Replaced by the “Find Website” action.")
struct GetWebsitesIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "GetWebsitesIntent"

	static let title: LocalizedStringResource = "Get Websites"

	static let description = IntentDescription("Returns all the websites in Plash or just some based on a filter.")

	@Parameter(
		title: "Filter",
		default: false,
		displayName: Bool.IntentDisplayName(true: "websites where", false: "all websites")
	)
	var shouldFilter: Bool

	@Parameter(title: "Condition", default: .titleEquals)
	var condition: FilterConditionAppEnum?

	@Parameter(title: "Text")
	var matchText: String?

	@Parameter(title: "Maximum Results")
	var limit: Int?

	static var parameterSummary: some ParameterSummary {
		When(\.$shouldFilter, .equalTo, true) {
			Summary("Get \(\.$shouldFilter) \(\.$condition) \(\.$matchText)") {
				\.$limit
			}
		} otherwise: {
			Summary("Get \(\.$shouldFilter)") {
				\.$limit
			}
		}
	}

	func perform() async throws -> some IntentResult & ReturnsValue<[WebsiteAppEntity]> {
		ensureRunning()

		var websites = WebsiteAppEntity.all

		if
			shouldFilter,
			let condition,
			let matchText = matchText?.trimmed.lowercased()
		{
			websites = websites.filter {
				let title = $0.title.lowercased()
				let urlString = $0.url.absoluteString.lowercased()

				guard let url = URL(string: urlString) else {
					return false
				}

				switch condition {
				case .titleEquals:
					return title == matchText
				case .titleContains:
					return title.contains(matchText)
				case .titleBeginsWith:
					return title.hasPrefix(matchText)
				case .titleEndsWith:
					return title.hasSuffix(matchText)
				case .urlEquals:
					return url.absoluteString == matchText
				case .urlHostEquals:
					return url.host == matchText
				}
			}
		}

		if let limit {
			websites = Array(websites.prefix(limit))
		}

		return .result(value: websites)
	}
}

struct GetCurrentWebsiteItent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "GetCurrentWebsiteIntent"

	static let title: LocalizedStringResource = "Get Current Website"

	static let description = IntentDescription("Returns the current website in Plash.")

	func perform() async throws -> some IntentResult & ReturnsValue<WebsiteAppEntity?> {
		ensureRunning()
		return .result(value: WebsitesController.shared.current.flatMap { .init($0) })
	}
}

struct SetCurrentWebsiteItent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "SetCurrentWebsiteIntent"

	static let title: LocalizedStringResource = "Set Current Website"

	static let description = IntentDescription("Sets the current website in Plash to the given website.")

	@Parameter(title: "Website")
	var website: WebsiteAppEntity

	static var parameterSummary: some ParameterSummary {
		Summary("Set current website to \(\.$website)")
	}

	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.current = website.toNative
		return .result()
	}
}

struct ReloadWebsiteIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "ReloadWebsiteIntent"

	static let title: LocalizedStringResource = "Reload Website"

	static let description = IntentDescription("Reloads the current website in Plash.")

	func perform() async throws -> some IntentResult {
		ensureRunning()
		await AppState.shared.reloadWebsite()
		return .result()
	}
}

struct NextWebsiteIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "NextWebsiteIntent"

	static let title: LocalizedStringResource = "Switch to Next Website"

	static let description = IntentDescription("Switches Plash to the next website in the list.")

	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makeNextCurrent()
		return .result()
	}
}

struct PreviousWebsiteIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "PreviousWebsiteIntent"

	static let title: LocalizedStringResource = "Switch to Previous Website"

	static let description = IntentDescription("Switches Plash to the previous website in the list.")

	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makePreviousCurrent()
		return .result()
	}
}

struct RandomWebsiteIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "RandomWebsiteIntent"

	static let title: LocalizedStringResource = "Switch to Random Website"

	static let description = IntentDescription("Switches Plash to a random website in the list.")

	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makeRandomCurrent()
		return .result()
	}
}

struct ToggleBrowsingModeIntent: AppIntent, CustomIntentMigratedAppIntent {
	static let intentClassName = "ToggleBrowsingModeIntent"

	static let title: LocalizedStringResource = "Toggle Browsing Mode"

	static let description = IntentDescription("Toggles “Browsing Mode” for Plash.")

	func perform() async throws -> some IntentResult {
		ensureRunning()
		await AppState.shared.toggleBrowsingMode()
		return .result()
	}
}

enum FilterConditionAppEnum: String, AppEnum {
	case titleEquals
	case titleContains
	case titleBeginsWith
	case titleEndsWith
	case urlEquals
	case urlHostEquals

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Filter Condition"

	static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
		.titleEquals: "title equals",
		.titleContains: "title contains",
		.titleBeginsWith: "title begins with",
		.titleEndsWith: "title ends with",
		.urlEquals: "URL equals",
		.urlHostEquals: "URL host equals"
	]
}

// TODO: When targeting macOS 14, use `EnumerableEntityQuery` to simplify it?
// Note: It's a class so we can use `NSPredicate`.
//struct WebsiteAppEntity: AppEntity {
final class WebsiteAppEntity: NSObject, AppEntity {
	struct WebsiteAppEntityQuery: EntityStringQuery, EntityPropertyQuery {
		static var sortingOptions = SortingOptions {}

		static var properties = QueryProperties {
			Property(\.$title) {
				EqualToComparator { NSPredicate(format: "title ==[cd] %@", $0) }
				NotEqualToComparator { NSPredicate(format: "title !=[cd] %@", $0) }
				ContainsComparator { NSPredicate(format: "title CONTAINS[cd] %@", $0) }
				HasPrefixComparator { NSPredicate(format: "title BEGINSWITH[cd] %@", $0) }
				HasSuffixComparator { NSPredicate(format: "title ENDSWITH[cd] %@", $0) }
			}
			Property(\.$url) {
				EqualToComparator { NSPredicate(format: "url ==[cd] %@", $0.absoluteString) }
				NotEqualToComparator { NSPredicate(format: "url !=[cd] %@", $0.absoluteString) }
				// TODO: Find a way to make these work on `URL`.
//				ContainsComparator { NSPredicate(format: "title CONTAINS[cd] %@", $0.absoluteString) }
//				HasPrefixComparator { NSPredicate(format: "title BEGINSWITH[cd] %@", $0.absoluteString) }
//				HasSuffixComparator { NSPredicate(format: "title ENDSWITH[cd] %@", $0.absoluteString) }
			}
			Property(\.$urlHost) {
				EqualToComparator { NSPredicate(format: "urlHost ==[cd] %@", $0) }
				NotEqualToComparator { NSPredicate(format: "urlHost !=[cd] %@", $0) }
				ContainsComparator { NSPredicate(format: "urlHost CONTAINS[cd] %@", $0) }
				HasPrefixComparator { NSPredicate(format: "urlHost BEGINSWITH[cd] %@", $0) }
				HasSuffixComparator { NSPredicate(format: "urlHost ENDSWITH[cd] %@", $0) }
			}
		}

		private func allEntities() -> [WebsiteAppEntity] {
			WebsiteAppEntity.all
		}

		func entities(for identifiers: [WebsiteAppEntity.ID]) async throws -> [WebsiteAppEntity] {
			allEntities().filter { identifiers.contains($0.id) }
		}

		func entities(matching query: String) async throws -> [WebsiteAppEntity] {
			allEntities().filter {
				$0.title.localizedCaseInsensitiveContains(query)
					|| $0.url.absoluteString.localizedCaseInsensitiveContains(query)
			}
		}

		func entities(
			matching comparators: [NSPredicate],
			mode: ComparatorMode,
			sortedBy: [Sort<WebsiteAppEntity>],
			limit: Int?
		) async throws -> [WebsiteAppEntity] {
			let predicate = NSCompoundPredicate(type: mode == .and ? .and : .or, subpredicates: comparators)
			var result = allEntities().filter { predicate.evaluate(with: $0) }

			if let limit {
				result = Array(result.prefix(limit))
			}

			return result
		}

		func suggestedEntities() async throws -> [WebsiteAppEntity] {
			allEntities()
		}
	}

	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Website"

	static let defaultQuery = WebsiteAppEntityQuery()

	// TODO: Use `Self` here when it's a struct again.
	static var all: [WebsiteAppEntity] { WebsitesController.shared.all.map(Self.init) }

	@Property(title: "Title")
	@objc var title: String

	@Property(title: "URL")
	@objc var url: URL

	@Property(title: "URL Host")
	@objc var urlHost: String

	@Property(title: "Is Current")
	var isCurrent: Bool

	let id: UUID

	init(_ website: Website) {
		self.id = website.id

		super.init()

		self.title = website.title
		self.url = website.url
		self.urlHost = website.url.host ?? ""
		self.isCurrent = website.isCurrent
	}

	var displayRepresentation: DisplayRepresentation {
		let title = title.nilIfEmptyOrWhitespace
		let urlString = url.absoluteString.removingSchemeAndWWWFromURL
		return .init(
			title: "\(title ?? urlString)",
			subtitle: title != nil ? "\(urlString)" : nil
			// TODO: Show the icon. I must first find a good way to store it to disk.
		)
	}
}

extension WebsiteAppEntity {
	var toNative: Website? {
		WebsitesController.shared.all[id: id]
	}
}

func ensureRunning() {
	// It's `prohibited` if the app was not already launched.
	// We activate it so that it will not quit right away if it was not already launched. (macOS 13.4)
	// We don't use `static let openAppWhenRun = true` as it activates (and steals focus) even if the app is already launched.
	// Note: Activate no longer works in macOS 14.
	if NSApp.activationPolicy() == .prohibited {
		if #available(macOS 14, *) {
			SSApp.url.open()
		} else {
			SSApp.forceActivate()
		}
	}
}
