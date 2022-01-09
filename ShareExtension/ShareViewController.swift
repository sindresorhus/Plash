import Cocoa

@MainActor
final class ShareViewController: NSViewController {
	@MainActor
	init() {
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError() // swiftlint:disable:this fatal_error_message
	}

	override func loadView() {
		guard
			let attachment = (extensionContext!.attachments.first { $0.hasItemConformingTo(.url) })
		else {
			cancel()
			return
		}

		Task { @MainActor in // Not sure if this is needed, but added just in case.
			let url: URL?
			do {
				url = try await attachment.loadObject(ofClass: NSURL.self) as URL?
			} catch {
				extensionContext!.cancelRequest(withError: error)
				return
			}

			guard let url = url else {
				cancel()
				return
			}

			var components = URLComponents()
			components.scheme = "plash"
			components.path = "add"
			components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

			NSWorkspace.shared.open(components.url!)
			extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
		}
	}

	private func cancel() {
		extensionContext!.cancelRequest(withError: NSError.userCancelled)
	}
}
