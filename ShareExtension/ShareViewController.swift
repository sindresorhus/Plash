import Cocoa

final class ShareViewController: NSViewController {
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

		attachment.loadObject(ofClass: NSURL.self) { [weak self] object, error in
			guard let self = self else {
				return
			}

			if let error = error {
				self.extensionContext!.cancelRequest(withError: error)
				return
			}

			guard let url = object as? NSURL else {
				self.cancel()
				return
			}

			var components = URLComponents()
			components.scheme = "plash"
			components.path = "add"
			components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

			DispatchQueue.main.sync {
				NSWorkspace.shared.open(components.url!)
				self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
			}
		}
	}

	private func cancel() {
		extensionContext!.cancelRequest(withError: NSError.userCancelled)
	}
}
