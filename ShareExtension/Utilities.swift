import Cocoa
import UniformTypeIdentifiers


extension Sequence where Element: Sequence {
	func flatten() -> [Element.Element] {
		// TODO: Make this `flatMap(\.self)` when https://bugs.swift.org/browse/SR-12897 is fixed.
		flatMap { $0 }
	}
}


extension NSExtensionContext {
	var inputItemsTyped: [NSExtensionItem] { inputItems as! [NSExtensionItem] }

	var attachments: [NSItemProvider] {
		inputItemsTyped.compactMap(\.attachments).flatten()
	}
}


// Strongly-typed versions of some of the methods.
extension NSItemProvider {
	func hasItemConformingTo(_ contentType: UTType) -> Bool {
		hasItemConformingToTypeIdentifier(contentType.identifier)
	}

	func loadItem(
		forType contentType: UTType,
		options: [AnyHashable: Any]? = nil, // swiftlint:disable:this discouraged_optional_collection
		completionHandler: NSItemProvider.CompletionHandler? = nil
	) {
		loadItem(
			forTypeIdentifier: contentType.identifier,
			options: options,
			completionHandler: completionHandler
		)
	}
}


extension NSError {
	static let userCancelled = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
}
