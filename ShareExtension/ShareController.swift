import Cocoa

final class ShareController: ExtensionController {
	override func run(_ context: NSExtensionContext) async throws -> [Any] {
		guard
			let url = try await (context.attachments.first { $0.hasItemConforming(to: .url) })?.loadObject(ofClass: URL.self)
		else {
			context.cancel()
			return []
		}

		var components = URLComponents()
		components.scheme = "plash"
		components.path = "add"
		components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

		NSWorkspace.shared.open(components.url!)
		return []
	}
}
