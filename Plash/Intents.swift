import AppIntents
import AppKit

struct AddWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Add Website"

	static let description = IntentDescription(
		"""
		Adds a website to Plash.

		Returns the added website.
		""",
		resultValueName: "Added Website"
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

	@MainActor
	func perform() async throws -> some IntentResult & ReturnsValue<WebsiteAppEntity> {
		ensureRunning()
		let website = WebsitesController.shared.add(url, title: title?.nilIfEmptyOrWhitespace).wrappedValue
		return .result(value: .init(website))
	}
}

struct RemoveWebsitesIntent: AppIntent {
	static let title: LocalizedStringResource = "Remove Websites"

	static let description = IntentDescription("Removes the given websites from Plash.")

	@Parameter(title: "Websites")
	var websites: [WebsiteAppEntity]

	static var parameterSummary: some ParameterSummary {
		Summary("Remove websites \(\.$websites)")
	}

	@MainActor
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

struct SetEnabledStateIntent: AppIntent {
	static let title: LocalizedStringResource = "Set Enabled State"

	static let description = IntentDescription("Sets the enabled state of Plash.")

	@Parameter(
		title: "Action",
		displayName: .init(true: "Toggle", false: "Turn")
	)
	var shouldToggle: Bool

	@Parameter(title: "Is Enabled")
	var isEnabled: Bool

	static var parameterSummary: some ParameterSummary {
		When(\.$shouldToggle, .equalTo, true) {
			Summary("\(\.$shouldToggle) Plash")
		} otherwise: {
			Summary("\(\.$shouldToggle) Plash \(\.$isEnabled)")
		}
	}

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()

		if shouldToggle {
			AppState.shared.isManuallyDisabled.toggle()
		} else {
			AppState.shared.isManuallyDisabled = !isEnabled
		}

		return .result()
	}
}

struct GetEnabledStateIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Enabled State"

	static let description = IntentDescription(
		"Returns whether Plash is currently enabled.",
		resultValueName: "Enabled State"
	)

	static var parameterSummary: some ParameterSummary {
		Summary("Get the current enabled state of Plash")
	}

	@MainActor
	func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
		.result(value: AppState.shared.isEnabled)
	}
}

struct GetCurrentWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Current Website"

	static let description = IntentDescription(
		"Returns the current website in Plash.",
		resultValueName: "Current Website"
	)

	@MainActor
	func perform() async throws -> some IntentResult & ReturnsValue<WebsiteAppEntity?> {
		ensureRunning()
		return .result(value: WebsitesController.shared.current.flatMap { .init($0) })
	}
}

struct SetCurrentWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Set Current Website"

	static let description = IntentDescription("Sets the current website in Plash to the given website.")

	@Parameter(title: "Website")
	var website: WebsiteAppEntity

	static var parameterSummary: some ParameterSummary {
		Summary("Set current website to \(\.$website)")
	}

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.current = website.toNative
		return .result()
	}
}

struct ReloadWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Reload Website"

	static let description = IntentDescription("Reloads the current website in Plash.")

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		AppState.shared.reloadWebsite()
		return .result()
	}
}

struct NextWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Switch to Next Website"

	static let description = IntentDescription("Switches Plash to the next website in the list.")

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makeNextCurrent()
		return .result()
	}
}

struct PreviousWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Switch to Previous Website"

	static let description = IntentDescription("Switches Plash to the previous website in the list.")

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makePreviousCurrent()
		return .result()
	}
}

struct RandomWebsiteIntent: AppIntent {
	static let title: LocalizedStringResource = "Switch to Random Website"

	static let description = IntentDescription("Switches Plash to a random website in the list.")

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		WebsitesController.shared.makeRandomCurrent()
		return .result()
	}
}

struct ToggleBrowsingModeIntent: AppIntent {
	static let title: LocalizedStringResource = "Toggle Browsing Mode"

	static let description = IntentDescription("Toggles “Browsing Mode” for Plash.")

	@MainActor
	func perform() async throws -> some IntentResult {
		ensureRunning()
		AppState.shared.toggleBrowsingMode()
		return .result()
	}
}

struct WebsiteAppEntity: AppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Website"

	static let defaultQuery = Query()

	let id: UUID

	@Property(title: "Title")
	var title: String

	@Property(title: "URL")
	var url: URL

	@Property(title: "URL Host")
	var urlHost: String

	@Property(title: "Is Current")
	var isCurrent: Bool

	init(_ website: Website) {
		self.id = website.id
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
	@MainActor
	var toNative: Website? {
		WebsitesController.shared.all[id: id]
	}
}

extension WebsiteAppEntity {
	struct Query: EnumerableEntityQuery, EntityStringQuery {
		static let findIntentDescription = IntentDescription(
			"Returns the websites in Plash.",
			resultValueName: "Websites"
		)

		func allEntities() async -> [WebsiteAppEntity] {
			await WebsitesController.shared.all.map(WebsiteAppEntity.init)
		}

		func suggestedEntities() async throws -> [WebsiteAppEntity] {
			await allEntities()
		}

		func entities(for identifiers: [WebsiteAppEntity.ID]) async throws -> [WebsiteAppEntity] {
			await allEntities().filter { identifiers.contains($0.id) }
		}

		func entities(matching query: String) async throws -> [WebsiteAppEntity] {
			await allEntities().filter {
				$0.title.localizedCaseInsensitiveContains(query)
					|| $0.url.absoluteString.localizedCaseInsensitiveContains(query)
			}
		}
	}
}

func ensureRunning() {
	// It's `prohibited` if the app was not already launched.
	// We activate it so that it will not quit right away if it was not already launched. (macOS 13.4)
	// We don't use `static let openAppWhenRun = true` as it activates (and steals focus) even if the app is already launched.
	if NSApp.activationPolicy() == .prohibited {
		SSApp.url.open()
	}
}
