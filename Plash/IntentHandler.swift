import Cocoa
import Intents

extension Website_ {
	static var all: [Website_] {
		WebsitesController.shared.all.map { Website_($0) }
	}

	fileprivate convenience init(_ website: Website) {
		self.init(
			identifier: website.id.uuidString,
			display: website.title,
			subtitle: website.url.absoluteString,
			image: nil
		)

		self.url = website.url
		self.isCurrent = website.isCurrent as NSNumber
	}

	var toPlashWebsite: Website? {
		guard
			let identifier = identifier,
			let uuid = UUID(uuidString: identifier),
			let website = WebsitesController.shared.all[id: uuid]
		else {
			return nil
		}

		return website
	}
}

@available(macOS 12, *)
@MainActor
final class AddWebsiteIntentHandler: NSObject, AddWebsiteIntentHandling {
	func resolveUrl(for intent: AddWebsiteIntent) async -> INURLResolutionResult {
		guard let url = intent.url else {
			return .needsValue()
		}

		return .success(with: url)
	}

	func resolveTitle(for intent: AddWebsiteIntent) async -> INStringResolutionResult {
		.success(with: intent.title ?? "")
	}

	func handle(intent: AddWebsiteIntent) async -> AddWebsiteIntentResponse {
		guard let url = intent.url else {
			return .init(code: .failure, userActivity: nil)
		}

		let website = WebsitesController.shared.add(url, title: intent.title?.nilIfEmptyOrWhitespace).wrappedValue

		let response = AddWebsiteIntentResponse(code: .success, userActivity: nil)
		response.result = .init(website)
		return response
	}
}

@available(macOS 12, *)
@MainActor
final class ReloadWebsiteIntentHandler: NSObject, ReloadWebsiteIntentHandling {
	func handle(intent: ReloadWebsiteIntent) async -> ReloadWebsiteIntentResponse {
		AppState.shared.reloadWebsite()
		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class NextWebsiteIntentHandler: NSObject, NextWebsiteIntentHandling {
	func handle(intent: NextWebsiteIntent) async -> NextWebsiteIntentResponse {
		WebsitesController.shared.makeNextCurrent()
		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class PreviousWebsiteIntentHandler: NSObject, PreviousWebsiteIntentHandling {
	func handle(intent: PreviousWebsiteIntent) async -> PreviousWebsiteIntentResponse {
		WebsitesController.shared.makePreviousCurrent()
		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class RandomWebsiteIntentHandler: NSObject, RandomWebsiteIntentHandling {
	func handle(intent: RandomWebsiteIntent) async -> RandomWebsiteIntentResponse {
		WebsitesController.shared.makeRandomCurrent()
		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class ToggleBrowsingModeIntentHandler: NSObject, ToggleBrowsingModeIntentHandling {
	func handle(intent: ToggleBrowsingModeIntent) async -> ToggleBrowsingModeIntentResponse {
		AppState.shared.toggleBrowsingMode()
		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class GetCurrentWebsiteIntentHandler: NSObject, GetCurrentWebsiteIntentHandling {
	func handle(intent: GetCurrentWebsiteIntent) async -> GetCurrentWebsiteIntentResponse {
		guard
			let website = WebsitesController.shared.current
		else {
			return .init(code: .failure, userActivity: nil)
		}

		let response = GetCurrentWebsiteIntentResponse(code: .success, userActivity: nil)
		response.website = Website_(website)
		return response
	}
}

@available(macOS 12, *)
@MainActor
final class GetWebsitesIntentHandler: NSObject, GetWebsitesIntentHandling {
	func handle(intent: GetWebsitesIntent) async -> GetWebsitesIntentResponse {
		var websites = Website_.all

		if
			intent.shouldFilter?.boolValue == true,
			let matchText = intent.matchText?.trimmed.lowercased()
		{
			websites = websites.filter {
				let title = $0.displayString.lowercased()

				guard
					let urlString = $0.subtitleString?.lowercased(),
					let url = URL(string: urlString)
				else {
					return false
				}

				switch intent.condition {
				case .unknown:
					return true
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

		if
			intent.shouldLimit?.boolValue == true,
			let limit = intent.limit as? Int
		{
			websites = Array(websites.prefix(limit))
		}

		let response = GetWebsitesIntentResponse(code: .success, userActivity: nil)
		response.websites = websites
		return response
	}
}

@available(macOS 12, *)
@MainActor
final class SetCurrentWebsiteIntentHandler: NSObject, SetCurrentWebsiteIntentHandling {
	func provideWebsiteOptionsCollection(for intent: SetCurrentWebsiteIntent) async throws -> INObjectCollection<Website_> {
		.init(items: Website_.all)
	}

	func handle(intent: SetCurrentWebsiteIntent) async -> SetCurrentWebsiteIntentResponse {
		guard let website = intent.website?.toPlashWebsite else {
			return .failure(failure: "Could not find the website.")
		}

		WebsitesController.shared.current = website

		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
@MainActor
final class RemoveWebsitesIntentHandler: NSObject, RemoveWebsitesIntentHandling {
	func provideWebsitesOptionsCollection(for intent: RemoveWebsitesIntent) async throws -> INObjectCollection<Website_> {
		.init(items: Website_.all)
	}

	func handle(intent: RemoveWebsitesIntent) async -> RemoveWebsitesIntentResponse {
		guard let websites = intent.websites?.nilIfEmpty else {
			return .init(code: .success, userActivity: nil)
		}

		for website in websites {
			guard let website = website.toPlashWebsite else {
				continue
			}

			WebsitesController.shared.remove(website)
		}

		return .init(code: .success, userActivity: nil)
	}
}

@available(macOS 12, *)
extension AppDelegate {
	@MainActor
	func application(_ application: NSApplication, handlerFor intent: INIntent) -> Any? {
		switch intent {
		case is AddWebsiteIntent:
			return AddWebsiteIntentHandler()
		case is ReloadWebsiteIntent:
			return ReloadWebsiteIntentHandler()
		case is NextWebsiteIntent:
			return NextWebsiteIntentHandler()
		case is PreviousWebsiteIntent:
			return PreviousWebsiteIntentHandler()
		case is RandomWebsiteIntent:
			return RandomWebsiteIntentHandler()
		case is ToggleBrowsingModeIntent:
			return ToggleBrowsingModeIntentHandler()
		case is GetCurrentWebsiteIntent:
			return GetCurrentWebsiteIntentHandler()
		case is GetWebsitesIntent:
			return GetWebsitesIntentHandler()
		case is SetCurrentWebsiteIntent:
			return SetCurrentWebsiteIntentHandler()
		case is RemoveWebsitesIntent:
			return RemoveWebsitesIntentHandler()
		default:
			assertionFailure("No handler for this intent")
			return nil
		}
	}
}
