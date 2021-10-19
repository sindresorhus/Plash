import Cocoa
import Intents

extension Website_ {
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

		WebsitesController.shared.add(url, title: intent.title?.nilIfEmptyOrWhitespace)

		return .init(code: .success, userActivity: nil)
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
		let response = GetWebsitesIntentResponse(code: .success, userActivity: nil)
		response.websites = WebsitesController.shared.all.map { Website_($0) }
		return response
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
		default:
			assertionFailure("No handler for this intent")
			return nil
		}
	}
}
