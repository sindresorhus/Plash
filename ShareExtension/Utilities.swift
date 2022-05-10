import Cocoa
import UniformTypeIdentifiers


extension Sequence where Element: Sequence {
	func flatten() -> [Element.Element] {
		// TODO: Make this `flatMap(\.self)` when https://github.com/apple/swift/issues/55343 is fixed.
		flatMap { $0 }
	}
}


extension NSExtensionContext {
	var inputItemsTyped: [NSExtensionItem] { inputItems as! [NSExtensionItem] }

	var attachments: [NSItemProvider] {
		inputItemsTyped.compactMap(\.attachments).flatten()
	}
}


extension NSItemProvider {
	func loadObject<T>(ofClass: T.Type) async throws -> T? where T: NSItemProviderReading {
		try await withCheckedThrowingContinuation { continuation in
			_ = loadObject(ofClass: ofClass) { data, error in
				if let error = error {
					continuation.resume(throwing: error)
					return
				}

				guard let image = data as? T else {
					continuation.resume(returning: nil)
					return
				}

				continuation.resume(returning: image)
			}
		}
	}

	func loadObject<T>(ofClass: T.Type) async throws -> T? where T: _ObjectiveCBridgeable, T._ObjectiveCType: NSItemProviderReading {
		try await withCheckedThrowingContinuation { continuation in
			_ = loadObject(ofClass: ofClass) { data, error in
				if let error = error {
					continuation.resume(throwing: error)
					return
				}

				guard let image = data else {
					continuation.resume(returning: nil)
					return
				}

				continuation.resume(returning: image)
			}
		}
	}
}


// Strongly-typed versions of some of the methods.
extension NSItemProvider {
	func hasItemConforming(to contentType: UTType) -> Bool {
		hasItemConformingToTypeIdentifier(contentType.identifier)
	}

	func loadItem(
		for contentType: UTType,
		options: [AnyHashable: Any]? = nil // swiftlint:disable:this discouraged_optional_collection
	) async throws -> NSSecureCoding {
		try await loadItem(
			forTypeIdentifier: contentType.identifier,
			options: options
		)
	}
}


extension NSError {
	static let userCancelled = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
}


extension NSExtensionContext {
	func cancel() {
		cancelRequest(withError: NSError.userCancelled)
	}
}


@MainActor
class ExtensionController: NSViewController { // swiftlint:disable:this final_class
	@MainActor
	init() {
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError() // swiftlint:disable:this fatal_error_message
	}

	override func loadView() {
		Task { @MainActor in // Not sure if this is needed, but added just in case.
			do {
				extensionContext!.completeRequest(
					returningItems: try await run(extensionContext!),
					completionHandler: nil
				)
			} catch {
				extensionContext!.cancelRequest(withError: error)
			}
		}
	}

	func run(_ context: NSExtensionContext) async throws -> [Any] { [] }
}
