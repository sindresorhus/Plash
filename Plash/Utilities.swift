import IOKit.ps
import IOKit.pwr_mgt
import WebKit
import SwiftUI
import Combine
import Network
import SystemConfiguration
import Defaults


/**
Convenience function for initializing an object and modifying its properties.

```
let label = with(NSTextField()) {
	$0.stringValue = "Foo"
	$0.textColor = .systemBlue
	view.addSubview($0)
}
```
*/
@discardableResult
func with<T>(_ item: T, update: (inout T) throws -> Void) rethrows -> T {
	var this = item
	try update(&this)
	return this
}


func delay(seconds: TimeInterval, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: closure)
}


extension NSWindow.Level {
	private static func level(for cgLevelKey: CGWindowLevelKey) -> Self {
		.init(rawValue: Int(CGWindowLevelForKey(cgLevelKey)))
	}

	static let desktop = level(for: .desktopWindow)
	static let desktopIcon = level(for: .desktopIconWindow)
	static let backstopMenu = level(for: .backstopMenu)
	static let dragging = level(for: .draggingWindow)
	static let overlay = level(for: .overlayWindow)
	static let help = level(for: .helpWindow)
	static let utility = level(for: .utilityWindow)
	static let assistiveTechHigh = level(for: .assistiveTechHighWindow)
	static let cursor = level(for: .cursorWindow)

	static let minimum = level(for: .minimumWindow)
	static let maximum = level(for: .maximumWindow)
}


final class SSMenu: NSMenu, NSMenuDelegate {
	var onOpen: (() -> Void)?
	var onClose: (() -> Void)?
	var onUpdate: ((NSMenu) -> Void)? {
		didSet {
			// Need to update it here, otherwise it's
			// positioned incorrectly on the first open.
			onUpdate?(self)
		}
	}

	private(set) var isOpen = false

	override init(title: String) {
		super.init(title: title)
		self.delegate = self
		self.autoenablesItems = false
	}

	@available(*, unavailable)
	required init(coder decoder: NSCoder) {
		fatalError(because: .notYetImplemented)
	}

	func menuWillOpen(_ menu: NSMenu) {
		isOpen = true
		onOpen?()
	}

	func menuDidClose(_ menu: NSMenu) {
		isOpen = false
		onClose?()
	}

	func menuNeedsUpdate(_ menu: NSMenu) {
		onUpdate?(menu)
	}
}


// TODO: Adopt the native method if this lands in Swift
// From: https://github.com/apple/swift-evolution/pull/861/files#diff-7227258cce0fbf6442a789b162652031R110
// Reasons why code should die at runtime
public struct FatalReason: CustomStringConvertible {
	/// Die because this code branch should be unreachable.
	public static let unreachable = Self("Should never be reached during execution.")

	/// Die because this method or function has not yet been implemented.
	public static let notYetImplemented = Self("Not yet implemented.")

	/// Die because a default method must be overridden by a
	/// subtype or extension.
	public static let subtypeMustOverride = Self("Must be overridden in subtype.")

	/// Die because this functionality should never be called,
	/// typically to silence requirements.
	public static let mustNotBeCalled = Self("Should never be called.")

	/// An underlying string-based cause for a fatal error.
	public let reason: String

	/// Establishes a new instance of a `FatalReason` with a string-based explanation.
	public init(_ reason: String) {
		self.reason = reason
	}

	/// Conforms to CustomStringConvertible, allowing reason to
	/// print directly to complaint.
	public var description: String { reason }
}
/// Unconditionally prints a given message and stops execution.
///
/// - Parameters:
///   - reason: A predefined `FatalReason`.
///   - function: The name of the calling function to print with `message`. The
///     default is the calling scope where `fatalError(because:, function:, file:, line:)`
///     is called.
///   - file: The file name to print with `message`. The default is the file
///     where `fatalError(because:, function:, file:, line:)` is called.
///   - line: The line number to print along with `message`. The default is the
///     line number where `fatalError(because:, function:, file:, line:)` is called.
// swiftlint:disable:next unavailable_function
public func fatalError(
	because reason: FatalReason,
	function: StaticString = #function,
	file: StaticString = #fileID,
	line: Int = #line
) -> Never {
	fatalError("\(function): \(reason)", file: file, line: UInt(line))
}
///


final class CallbackMenuItem: NSMenuItem {
	private static var validateCallback: ((NSMenuItem) -> Bool)?

	static func validate(_ callback: @escaping (NSMenuItem) -> Bool) {
		validateCallback = callback
	}

	init(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		callback: @escaping (NSMenuItem) -> Void
	) {
		self.callback = callback
		super.init(title: title, action: #selector(action(_:)), keyEquivalent: key)
		self.target = self
		self.isEnabled = isEnabled
		self.isChecked = isChecked
		self.isHidden = isHidden

		if let keyModifiers = keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	@available(*, unavailable)
	required init(coder decoder: NSCoder) {
		fatalError(because: .notYetImplemented)
	}

	private let callback: (NSMenuItem) -> Void

	@objc
	func action(_ sender: NSMenuItem) {
		callback(sender)
	}
}

extension CallbackMenuItem: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		Self.validateCallback?(menuItem) ?? true
	}
}


extension NSMenuItem {
	convenience init(
		_ title: String,
		action: Selector? = nil,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(title: title, action: action, keyEquivalent: key)
		self.representedObject = data
		self.isEnabled = isEnabled
		self.isChecked = isChecked
		self.isHidden = isHidden

		if let keyModifiers = keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	convenience init(
		_ attributedTitle: NSAttributedString,
		action: Selector? = nil,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(
			"",
			action: action,
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		self.attributedTitle = attributedTitle
	}

	var isChecked: Bool {
		get { state == .on }
		set {
			state = newValue ? .on : .off
		}
	}
}


extension NSMenu {
	/// Get the `NSMenuItem` that has this menu as a submenu.
	var parentMenuItem: NSMenuItem? {
		guard let supermenu = supermenu else {
			return nil
		}

		let index = supermenu.indexOfItem(withSubmenu: self)
		return supermenu.item(at: index)
	}

	/// Get the item with the given identifier.
	func item(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSMenuItem? {
		for item in items where item.identifier == identifier {
			return item
		}

		return nil
	}

	/// Remove the first item in the menu.
	func removeFirstItem() {
		removeItem(at: 0)
	}

	/// Remove the last item in the menu.
	func removeLastItem() {
		removeItem(at: numberOfItems - 1)
	}

	func addSeparator() {
		addItem(.separator())
	}

	@discardableResult
	func add(_ menuItem: NSMenuItem) -> NSMenuItem {
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addDisabled(_ title: String) -> NSMenuItem {
		let menuItem = NSMenuItem(title)
		menuItem.isEnabled = false
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addDisabled(_ attributedTitle: NSAttributedString) -> NSMenuItem {
		let menuItem = NSMenuItem(attributedTitle)
		menuItem.isEnabled = false
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addItem(
		_ title: String,
		action: Selector? = nil,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			title,
			action: action,
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addItem(
		_ attributedTitle: NSAttributedString,
		action: Selector? = nil,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			attributedTitle,
			action: action,
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addCallbackItem(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		callback: @escaping (NSMenuItem) -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden,
			callback: callback
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addCallbackItem(
		_ title: NSAttributedString,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		callback: @escaping (NSMenuItem) -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			"",
			key: key,
			keyModifiers: keyModifiers,
			data: data,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden,
			callback: callback
		)
		menuItem.attributedTitle = title
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addUrlItem(_ title: String, url: URL) -> NSMenuItem {
		addCallbackItem(title) { _ in
			NSWorkspace.shared.open(url)
		}
	}

	@discardableResult
	func addUrlItem(_ title: NSAttributedString, url: URL) -> NSMenuItem {
		addCallbackItem(title) { _ in
			NSWorkspace.shared.open(url)
		}
	}

	@discardableResult
	func addMoreAppsItem() -> NSMenuItem {
		addUrlItem(
			"More Apps",
			url: URL("macappstore://apps.apple.com/us/developer/sindresorhus/id328077650?mt=8")
		)
	}

	@discardableResult
	func addDefaultsItem<Value: Equatable>(
		_ title: String,
		key: Defaults.Key<Value>,
		value: Value,
		isEnabled: Bool = true,
		callback: ((NSMenuItem) -> Void)? = nil
	) -> NSMenuItem {
		addCallbackItem(
			title,
			isEnabled: isEnabled,
			isChecked: value == Defaults[key]
		) { item in
			Defaults[key] = value
			callback?(item)
		}
	}

	@discardableResult
	func addDefaultsItemForBool(
		_ title: String,
		key: Defaults.Key<Bool>,
		isEnabled: Bool = true,
		callback: ((NSMenuItem) -> Void)? = nil
	) -> NSMenuItem {
		addCallbackItem(
			title,
			isEnabled: isEnabled,
			isChecked: Defaults[key]
		) { item in
			Defaults[key].toggle()
			callback?(item)
		}
	}

	@discardableResult
	func addDefaultsItemForBool(
		_ title: String,
		key: String,
		isEnabled: Bool = true,
		callback: ((NSMenuItem) -> Void)? = nil
	) -> NSMenuItem {
		let bool = UserDefaults.standard.bool(forKey: key)
		return addCallbackItem(
			title,
			isEnabled: isEnabled,
			isChecked: bool
		) { item in
			UserDefaults.standard.set(!bool, forKey: key)
			callback?(item)
		}
	}

	@discardableResult
	func addAboutItem() -> NSMenuItem {
		addCallbackItem("About") {
			NSApp.activate(ignoringOtherApps: true)
			NSApp.orderFrontStandardAboutPanel($0)
		}
	}

	@discardableResult
	func addQuitItem() -> NSMenuItem {
		addSeparator()

		return addCallbackItem("Quit \(App.name)", key: "q") { _ in
			App.quit()
		}
	}
}


enum App {
	static let id = Bundle.main.bundleIdentifier!
	static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
	static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
	static let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
	static let versionWithBuild = "\(version) (\(build))"
	static let icon = NSApp.applicationIconImage!
	static let url = Bundle.main.bundleURL

	static func quit() {
		NSApp.terminate(nil)
	}

	static let isFirstLaunch: Bool = {
		let key = "SS_hasLaunched"

		if UserDefaults.standard.bool(forKey: key) {
			return false
		} else {
			UserDefaults.standard.set(true, forKey: key)
			return true
		}
	}()

	static func openSendFeedbackPage() {
		let metadata =
			"""
			\(App.name) \(App.versionWithBuild) - \(App.id)
			macOS \(Device.osVersion)
			\(Device.hardwareModel)
			"""

		let query: [String: String] = [
			"product": App.name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback/").addingDictionaryAsQuery(query).open()
	}
}


/// Convenience for opening URLs.
extension URL {
	func open() {
		NSWorkspace.shared.open(self)
	}
}
extension String {
	/*
	```
	"https://sindresorhus.com".openUrl()
	```
	*/
	func openUrl() {
		URL(string: self)?.open()
	}
}


extension URL {
	/**
	Example:

	```
	URL("https://sindresorhus.com")
	```
	*/
	init(_ staticString: StaticString) {
		self.init(string: "\(staticString)")!
	}
}


struct Device {
	static let osVersion: String = {
		let os = ProcessInfo.processInfo.operatingSystemVersion
		return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
	}()

	static let hardwareModel: String = {
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		return String(cString: model)
	}()
}


private func escapeQuery(_ query: String) -> String {
	// From RFC 3986
	let generalDelimiters = ":#[]@"
	let subDelimiters = "!$&'()*+,;="

	var allowedCharacters = CharacterSet.urlQueryAllowed
	allowedCharacters.remove(charactersIn: generalDelimiters + subDelimiters)
	return query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? query
}


extension Dictionary where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
	var asQueryItems: [URLQueryItem] {
		map {
			URLQueryItem(
				name: escapeQuery($0 as! String),
				value: escapeQuery($1 as! String)
			)
		}
	}

	var asQueryString: String {
		var components = URLComponents()
		components.queryItems = asQueryItems
		return components.query!
	}
}


extension URLComponents {
	mutating func addDictionaryAsQuery(_ dict: [String: String]) {
		percentEncodedQuery = dict.asQueryString
	}
}


extension URL {
	func addingDictionaryAsQuery(_ dict: [String: String]) -> Self {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
		components.addDictionaryAsQuery(dict)
		return components.url ?? self
	}
}


extension NSEdgeInsets {
	static let zero = NSEdgeInsetsZero

	init(
		top: Double = 0,
		left: Double = 0,
		bottom: Double = 0,
		right: Double = 0
	) {
		self.init()
		self.top = CGFloat(top)
		self.left = CGFloat(left)
		self.bottom = CGFloat(bottom)
		self.right = CGFloat(right)
	}

	init(all: Double) {
		self.init(
			top: all,
			left: all,
			bottom: all,
			right: all
		)
	}

	init(horizontal: Double, vertical: Double) {
		self.init(
			top: CGFloat(vertical),
			left: CGFloat(horizontal),
			bottom: CGFloat(vertical),
			right: CGFloat(horizontal)
		)
	}

	var horizontal: Double { Double(left + right) }
	var vertical: Double { Double(top + bottom) }
}



extension NSView {
	func constrainEdges(to view: NSView, with insets: NSEdgeInsets = .zero) {
		translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
			trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
			topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
			bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
		])
	}

	func constrainEdges(to view: NSView, margin: Double = 0) {
		constrainEdges(to: view, with: .init(all: margin))
	}

	func constrainEdgesToSuperview(with insets: NSEdgeInsets = .zero) {
		guard let superview = superview else {
			assertionFailure("There is no superview for this view")
			return
		}

		constrainEdges(to: superview, with: insets)
	}
}


extension String {
	/// NSString has some useful properties that String does not.
	var nsString: NSString { self as NSString }

	var attributedString: NSAttributedString { .init(string: self) }
}


private var controlActionClosureProtocolAssociatedObjectKey: UInt8 = 0

protocol ControlActionClosureProtocol: NSObjectProtocol {
	var target: AnyObject? { get set }
	var action: Selector? { get set }
}

private final class ActionTrampoline<T>: NSObject {
	let action: (T) -> Void

	init(action: @escaping (T) -> Void) {
		self.action = action
	}

	@objc
	func action(sender: AnyObject) {
		action(sender as! T)
	}
}

extension ControlActionClosureProtocol {
	/**
	Closure version of `.action`

	```
	let button = NSButton(title: "Unicorn", target: nil, action: nil)

	button.onAction { sender in
		print("Button action: \(sender)")
	}
	```
	*/
	func onAction(_ action: @escaping (Self) -> Void) {
		let trampoline = ActionTrampoline(action: action)
		target = trampoline
		self.action = #selector(ActionTrampoline<Self>.action(sender:))
		objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
	}
}

extension NSControl: ControlActionClosureProtocol {}
extension NSMenuItem: ControlActionClosureProtocol {}
extension NSToolbarItem: ControlActionClosureProtocol {}
extension NSGestureRecognizer: ControlActionClosureProtocol {}


struct NativeButton: NSViewRepresentable {
	typealias NSViewType = NSButton

	enum KeyEquivalent: String {
		case escape = "\u{1b}"
		case `return` = "\r"

		// More here: https://cool8jay.github.io/shortcut-nemenuitem-nsbutton/
	}

	var title: String?
	var attributedTitle: NSAttributedString?
	let keyEquivalent: KeyEquivalent?
	let action: () -> Void

	init(
		_ title: String,
		keyEquivalent: KeyEquivalent? = nil,
		action: @escaping () -> Void
	) {
		self.title = title
		self.keyEquivalent = keyEquivalent
		self.action = action
	}

	init(
		_ attributedTitle: NSAttributedString,
		keyEquivalent: KeyEquivalent? = nil,
		action: @escaping () -> Void
	) {
		self.attributedTitle = attributedTitle
		self.keyEquivalent = keyEquivalent
		self.action = action
	}

	func makeNSView(context: Context) -> NSViewType {
		let nsView = NSButton(title: "", target: nil, action: nil)
		nsView.wantsLayer = true
		nsView.translatesAutoresizingMaskIntoConstraints = false
		nsView.setContentHuggingPriority(.defaultHigh, for: .vertical)
		nsView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		if attributedTitle == nil {
			nsView.title = title ?? ""
		}

		if title == nil {
			nsView.attributedTitle = attributedTitle ?? "".attributedString
		}

		nsView.keyEquivalent = keyEquivalent?.rawValue ?? ""

		nsView.onAction { _ in
			action()
		}
	}
}


struct Validators {
	static func isIPv4(_ string: String) -> Bool {
		IPv4Address(string) != nil
	}

	static func isIPv6(_ string: String) -> Bool {
		IPv6Address(string) != nil
	}

	static func isIP(_ string: String) -> Bool {
		isIPv4(string) || isIPv6(string)
	}
}


extension URL {
	/**
	Check if a URL string is a valid URL.

	`URL(string:)` doesn't strictly validate the input. This one at least ensures there's a `scheme` and that the `host` has a TLD.
	*/
	static func isValid(string: String) -> Bool {
		guard let url = URL(string: string) else {
			return false
		}

		return url.isValid
	}

	/// Check if the `host` part of a URL is an IP address.
	var isHostAnIPAddress: Bool {
		guard let host = host else {
			return false
		}

		return Validators.isIP(host)
	}

	/**
	Check if `self` is a valid URL.

	`URL(string:)` doesn't strictly validate the input. This one at least ensures there's a `scheme` and that the `host` has a TLD.
	*/
	var isValid: Bool {
		guard
			!isFileURL,
			!isHostAnIPAddress
		else {
			return true
		}

		guard
			scheme != nil,
			let host = host
		else {
			return false
		}

		// Allow `localhost` and other local URLs without a domain.
		guard host.contains(".") else {
			return true
		}

		let hostComponents = host.components(separatedBy: ".")

		return hostComponents.count >= 2 &&
			!hostComponents[0].isEmpty &&
			hostComponents.last!.count > 1
	}
}


extension Binding where Value: Equatable {
	/**
	Get notified when the binding value changes to a different one.

	Can be useful to manually update non-reactive properties.

	```
	Toggle(
		"Foo",
		isOn: $foo.onChange {
			bar.isEnabled = $0
		}
	)
	```
	*/
	func onChange(_ action: @escaping (Value) -> Void) -> Self {
		.init(
			get: { wrappedValue },
			set: {
				let oldValue = wrappedValue
				wrappedValue = $0
				let newValue = wrappedValue
				if newValue != oldValue {
					action(newValue)
				}
			}
		)
	}

	/**
	Update the given property when the binding value changes to a different one.

	Can be useful to manually update non-reactive properties.

	- Note: Static key paths are not yet supported in Swift: https://forums.swift.org/t/key-path-cannot-refer-to-static-member/28055/2

	```
	Toggle("Foo", isOn: $foo.onChange(for: bar, keyPath: \.isEnabled))
	```
	*/
	func onChange<Object: AnyObject>(
		for object: Object,
		keyPath: ReferenceWritableKeyPath<Object, Value>
	) -> Self {
		onChange { [weak object] newValue in
			object?[keyPath: keyPath] = newValue
		}
	}
}


extension Binding {
	/**
	Convert a binding with an optional value to a binding with a non-optional value by using the given default value if the binding value is `nil`.

	```
	struct ContentView: View {
		private static let defaultInterval = 60.0

		private var interval: Binding<Double> {
			$optionalInterval.withDefaultValue(Self.defaultInterval)
		}

		var body: some View {}
	}
	```
	*/
	func withDefaultValue<T>(_ defaultValue: T) -> Binding<T> where Value == T? {
		.init(
			get: { wrappedValue ?? defaultValue },
			set: {
				wrappedValue = $0
			}
		)
	}
}


extension Binding {
	/**
	Convert a binding with an optional value to a binding with a boolean value representing whether the original binding value is `nil`.

	- Parameter falseSetValue: The value used when the binding value is set to `false`.

	```
	struct ContentView: View {
		private static let defaultInterval = 60.0

		private var doesNotHaveInterval: Binding<Bool> {
			$optionalInterval.isNil(falseSetValue: Self.defaultInterval)
		}

		var body: some View {}
	}
	```
	*/
	func isNil<T>(falseSetValue: T) -> Binding<Bool> where Value == T? {
		.init(
			get: { wrappedValue == nil },
			set: {
				wrappedValue = $0 ? nil : falseSetValue
			}
		)
	}

	/**
	Convert a binding with an optional value to a binding with a boolean value representing whether the original binding value is not `nil`.

	- Parameter trueSetValue: The value used when the binding value is set to `true`.

	```
	struct ContentView: View {
		private static let defaultInterval = 60.0

		private var hasInterval: Binding<Bool> {
			$optionalInterval.isNotNil(trueSetValue: Self.defaultInterval)
		}

		var body: some View {}
	}
	```
	*/
	func isNotNil<T>(trueSetValue: T) -> Binding<Bool> where Value == T? {
		.init(
			get: { wrappedValue != nil },
			set: {
				wrappedValue = $0 ? trueSetValue : nil
			}
		)
	}
}


extension Binding where Value == Double {
	// TODO: Maybe make a general `Binding#convert()` function that accepts a converter. Something like `binding.convert(.secondsToMinutes)`?
	var secondsToMinutes: Self {
		map(
			get: { $0 / 60 },
			set: { $0 * 60 }
		)
	}
}


extension StringProtocol where Self: RangeReplaceableCollection {
	var removingNewlines: Self {
		// TODO: Use `filter(!\.isNewline)` when key paths support negation.
		filter { !$0.isNewline }
	}
}


extension AppDelegate {
	static let shared = NSApp.delegate as! AppDelegate
}


extension String {
	var trimmed: Self {
		trimmingCharacters(in: .whitespacesAndNewlines)
	}

	var trimmedLeading: Self {
		replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
	}

	var trimmedTrailing: Self {
		replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
	}

	func removingPrefix(_ prefix: Self) -> Self {
		guard hasPrefix(prefix) else {
			return self
		}

		return Self(dropFirst(prefix.count))
	}

	/// Returns a string with the matches of the given regex replaced with the given replacement string.
	func replacingOccurrences(matchingRegex regex: Self, with replacement: Self) -> Self {
		replacingOccurrences(of: regex, with: replacement, options: .regularExpression)
	}

	/**
	```
	"Unicorn".truncated(to: 4)
	//=> "Uni…"
	```
	*/
	func truncating(to number: Int, truncationIndicator: Self = "…") -> Self {
		if number <= 0 {
			return ""
		} else if count > number {
			return Self(prefix(number - truncationIndicator.count)).trimmedTrailing + truncationIndicator
		} else {
			return self
		}
	}
}


extension Binding {
	/**
	Transform a binding.

	You can even change the type of the binding.

	```
	$foo.map(
		get: { $0.uppercased() },
		set: { $0.lowercased() }
	)
	```
	*/
	func map<Result>(
		get: @escaping (Value) -> Result,
		set: @escaping (Result) -> Value
	) -> Binding<Result> {
		.init(
			get: { get(wrappedValue) },
			set: { newValue in
				wrappedValue = set(newValue)
			}
		)
	}

	/**
	Transform the value on `set`.

	```
	$foo.setMap { $0.uppercased() }
	```
	*/
	func setMap(
		_ set: @escaping (Value) -> Value
	) -> Self {
		.init(
			get: { wrappedValue },
			set: { newValue in
				wrappedValue = set(newValue)
			}
		)
	}

	/**
	Transform the value on `get`.

	- Important: If you want to simply map using a property, you can just do `$foo.someProperty` instead, thanks to dynamic member support in `Binding`.

	```
	$foo.getMap { $0.uppercased() }
	```
	*/
	func getMap(
		_ get: @escaping (Value) -> Value
	) -> Self {
		.init(
			get: { get(wrappedValue) },
			set: { newValue in
				wrappedValue = newValue
			}
		)
	}
}


extension URL {
	/// `URLComponents` have better parsing than `URL` and supports
	/// things like `scheme:path` (notice the missing `//`).
	var components: URLComponents? {
		URLComponents(url: self, resolvingAgainstBaseURL: true)
	}
}


extension WKWebView {
	// Source: https://github.com/WebKit/webkit/blob/a77f5c97c5be3a392f626f444f2111a09a3520ca/Source/WebKit/UIProcess/API/Cocoa/WKMenuItemIdentifiers.mm
	/**
	Use this to modify the web view context menu in the `func willOpenMenu()` delegate method.

	```
	import WebKit

	final class SSWebView: WKWebView {
		private var excludedMenuItems: Set<MenuItemIdentifier> = [
			.toggleEnhancedFullScreen,
			.toggleFullScreen
		]

		override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
			menu.items.removeAll {
				guard let identifier = MenuItemIdentifier($0) else {
					return false
				}

				return excludedMenuItems.contains(identifier)
			}
		}
	}
	```
	*/
	enum MenuItemIdentifier: String {
		case copy = "WKMenuItemIdentifierCopy"
		case copyImage = "WKMenuItemIdentifierCopyImage"
		case copyLink = "WKMenuItemIdentifierCopyLink"
		case copyMediaLink = "WKMenuItemIdentifierCopyMediaLink"
		case downloadImage = "WKMenuItemIdentifierDownloadImage"
		case downloadLinkedFile = "WKMenuItemIdentifierDownloadLinkedFile"
		case downloadMedia = "WKMenuItemIdentifierDownloadMedia"
		case goBack = "WKMenuItemIdentifierGoBack"
		case goForward = "WKMenuItemIdentifierGoForward"
		case inspectElement = "WKMenuItemIdentifierInspectElement"
		case lookUp = "WKMenuItemIdentifierLookUp"
		case openFrameInNewWindow = "WKMenuItemIdentifierOpenFrameInNewWindow"
		case openImageInNewWindow = "WKMenuItemIdentifierOpenImageInNewWindow"
		case openLink = "WKMenuItemIdentifierOpenLink"
		case openLinkInNewWindow = "WKMenuItemIdentifierOpenLinkInNewWindow"
		case openMediaInNewWindow = "WKMenuItemIdentifierOpenMediaInNewWindow"
		case paste = "WKMenuItemIdentifierPaste"
		case reload = "WKMenuItemIdentifierReload"
		case searchWeb = "WKMenuItemIdentifierSearchWeb"
		case showHideMediaControls = "WKMenuItemIdentifierShowHideMediaControls"
		case toggleEnhancedFullScreen = "WKMenuItemIdentifierToggleEnhancedFullScreen"
		case toggleFullScreen = "WKMenuItemIdentifierToggleFullScreen"
		case shareMenu = "WKMenuItemIdentifierShareMenu"
		case speechMenu = "WKMenuItemIdentifierSpeechMenu"

		init?(_ menuItem: NSMenuItem) {
			guard let rawIdentifier = menuItem.identifier?.rawValue else {
				return nil
			}

			self.init(rawValue: rawIdentifier)
		}
	}
}


extension NSAlert {
	/// Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	@discardableResult
	static func showModal(
		for window: NSWindow? = nil,
		message: String,
		informativeText: String? = nil,
		style: Style = .warning
	) -> NSApplication.ModalResponse {
		NSAlert(
			message: message,
			informativeText: informativeText,
			style: style
		).runModal(for: window)
	}

	convenience init(
		message: String,
		informativeText: String? = nil,
		style: Style = .warning
	) {
		self.init()
		self.messageText = message
		self.alertStyle = style

		if let informativeText = informativeText {
			self.informativeText = informativeText
		}
	}

	/// Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window = window else {
			return runModal()
		}

		beginSheetModal(for: window) { returnCode in
			NSApp.stopModal(withCode: returnCode)
		}

		return NSApp.runModal(for: window)
	}
}


extension NSEvent {
	/**
	Real modifiers.

	- Note: Prefer this over `.modifierFlags`.

	```
	// Check if Command is one of possible more modifiers keys
	event.modifiers.contains(.command)

	// Check if Command is the only modifier key
	event.modifiers == .command

	// Check if Command and Shift are the only modifiers
	event.modifiers == [.command, .shift]
	```
	*/
	var modifiers: ModifierFlags {
		modifierFlags
			.intersection(.deviceIndependentFlagsMask)
			// We remove capsLock as it shouldn't affect the modifiers.
			// We remove numericPad/function as arrow keys trigger it, use `event.specialKeys` instead.
			.subtracting([.capsLock, .numericPad, .function])
	}
}


final class SwiftUIWindowForMenuBarApp: NSWindow {
	override var canBecomeMain: Bool { true }
	override var canBecomeKey: Bool { true }
	override var acceptsFirstResponder: Bool { true }

	var shouldCloseOnEscapePress = false

	convenience init() {
		self.init(
			contentRect: .zero,
			styleMask: [
				.titled,
				.fullSizeContentView,
				.closable,
				.miniaturizable,
				.resizable
			],
			backing: .buffered,
			defer: true
		)
	}

	override func cancelOperation(_ sender: Any?) {
		guard shouldCloseOnEscapePress else {
			return
		}

		performClose(self)
	}

	override func keyDown(with event: NSEvent) {
		if event.modifiers == .command {
			if event.charactersIgnoringModifiers == "w" {
				performClose(self)
				return
			}

			if event.charactersIgnoringModifiers == "m" {
				performMiniaturize(self)
				return
			}
		}

		super.keyDown(with: event)
	}
}


extension WKWebView {
	static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.4 Safari/605.1.15"

	/**
	Evaluate JavaScript synchronously.

	- Important: This will block the main thread. Don't use it for anything that takes a long time.
	*/
	@discardableResult
	func evaluateSync(script: String) throws -> Any? {
		var isFinished = false
		var returnResult: Any?
		var returnError: Error?

		evaluateJavaScript(script) { result, error in
			returnResult = result
			returnError = error
			isFinished = true
		}

		while !isFinished {
			RunLoop.current.run(mode: .default, before: .distantFuture)
		}

		if let error = returnError {
			throw error
		}

		return returnResult
	}

	/**
	Get/set the zoom level of the page.

	- Important: This is very slow. Don't call it in a hot path.
	*/
	var zoomLevel: Double {
		get {
			guard let zoomString = (try? evaluateSync(script: "document.body.style.zoom")) as? String else {
				return 1
			}

			return Double(zoomString) ?? 1
		}
		set {
			_ = try? evaluateSync(script: "document.body.style.zoom = '\(newValue)'")
		}
	}

	// https://github.com/feedback-assistant/reports/issues/81
	/// Whether the web view should have a background. Set to `false` to make it transparent.
	var drawsBackground: Bool {
		get {
			value(forKey: "drawsBackground") as? Bool ?? true
		}
		set {
			setValue(newValue, forKey: "drawsBackground")
		}
	}
}

/**
Default handlers for the UI for WKUIDelegate.

Test it with https://jsfiddle.net/sindresorhus/8moqrudL/

```
extension WebViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		webView.defaultAlertHandler(message: message, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		webView.defaultConfirmHandler(message: message, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		webView.defaultPromptHandler(prompt: prompt, defaultText: defaultText, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
		webView.defaultUploadPanelHandler(parameters: parameters, completion: completionHandler)
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		webView.defaultAuthChallengeHandler(challenge: challenge, completion: completionHandler)
	}
}
```
*/
extension WKWebView {
	/// Default handler for JavaScript `alert()` to be used in `WKDelegate`.
	func defaultAlertHandler(message: String, completion: @escaping () -> Void) {
		let alert = NSAlert()
		alert.messageText = message
		alert.runModal()
		completion()
	}

	/// Default handler for JavaScript `confirm()` to be used in `WKDelegate`.
	func defaultConfirmHandler(message: String, completion: @escaping (Bool) -> Void) {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = message
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")

		let result = alert.runModal() == .alertFirstButtonReturn
		completion(result)
	}

	/// Default handler for JavaScript `prompt()` to be used in `WKDelegate`.
	func defaultPromptHandler(prompt: String, defaultText: String?, completion: @escaping (String?) -> Void) {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = prompt
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")

		let textField = AutofocusedTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 22))
		textField.stringValue = defaultText ?? ""
		alert.accessoryView = textField

		let result = alert.runModal() == .alertFirstButtonReturn ? textField.stringValue : nil
		completion(result)
	}

	/// Default handler for JavaScript initiated upload panel to be used in `WKDelegate`.
	func defaultUploadPanelHandler(parameters: WKOpenPanelParameters, completion: @escaping ([URL]?) -> Void) { // swiftlint:disable:this discouraged_optional_collection
		let openPanel = NSOpenPanel()
		openPanel.level = .floating
		openPanel.prompt = "Choose"
		openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
		openPanel.canChooseFiles = !parameters.allowsDirectories
		openPanel.canChooseDirectories = parameters.allowsDirectories

		// It's intentionally modal as we don't want the user to interact with the website until they're done with the panel.
		let result = openPanel.runModal() == .OK ? openPanel.urls : nil
		completion(result)
	}

	// Can be tested at https://jigsaw.w3.org/HTTP/Basic/ with `guest` as username and password.
	/// Default handler for websites requiring basic authentication. To be used in `WKDelegate`.
	func defaultAuthChallengeHandler(challenge: URLAuthenticationChallenge, completion: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		guard
			let host = url?.host,
			challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
				|| challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
		else {
			completion(.performDefaultHandling, nil)
			return
		}

		let alert = NSAlert()
		alert.messageText = "Log in to \(host)"
		alert.addButton(withTitle: "Log In")
		alert.addButton(withTitle: "Cancel")

		let view = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 54))
		alert.accessoryView = view

		let username = AutofocusedTextField(frame: CGRect(x: 0, y: 32, width: 200, height: 22))
		// TODO: Enable these when on Xcode 12.
//		if #available(macOS 11, *) {
//			username.contentType = .username
//		}
		username.placeholderString = "Username"
		view.addSubview(username)

		let password = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 22))
//		if #available(macOS 11, *) {
//			password.contentType = .password
//		}
		password.placeholderString = "Password"
		view.addSubview(password)

		// TODO: It doesn't continue tabbing to the buttons after the password field.
		username.nextKeyView = password

		// Menu bar apps need to be activated, otherwise, things like input focus doesn't work.
		if NSApp.activationPolicy() == .accessory {
			NSApp.activate(ignoringOtherApps: true)
		}

		guard alert.runModal() == .alertFirstButtonReturn else {
			completion(.rejectProtectionSpace, nil)
			return
		}

		let credential = URLCredential(
			user: username.stringValue,
			password: password.stringValue,
			persistence: .synchronizable
		)

		completion(.useCredential, credential)
	}
}


extension WKWebView {
	static func createCSSInjectScript(_ css: String) -> String {
		let textContent = css.addingPercentEncoding(withAllowedCharacters: .letters) ?? css

		return
			"""
			(() => {
				const style = document.createElement('style');
				style.textContent = unescape('\(textContent)');
				document.documentElement.appendChild(style);
			})();
			"""
	}
}

extension WKUserContentController {
	/// Add CSS to the page.
	func addCSS(_ css: String) {
		let source = WKWebView.createCSSInjectScript(css)

		let userScript = WKUserScript(
			source: source,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: false
		)

		addUserScript(userScript)
	}
}

extension WKUserContentController {
	private static let invertColorsCSS =
		"""
		:root {
			background-color: #fefefe;
			filter: invert(100%) hue-rotate(-180deg);
		}

		* {
			background-color: inherit;
		}

		img:not([src*='.svg']),
		video {
			filter: invert(100%) hue-rotate(180deg);
			background-color: unset;
		}
		"""

	/// Invert the colors on the page. Pseudo dark mode.
	func invertColors() {
		addCSS(Self.invertColorsCSS)
	}
}


extension WKUserContentController {
	private static let muteAudioCode =
		"""
		(() => {
			const selector = 'audio, video';

			for (const element of document.querySelectorAll(selector)) {
				element.muted = true;
			}

			const observer = new MutationObserver(mutations => {
				for (const mutation of mutations) {
					for (const node of mutation.addedNodes) {
						if ('matches' in node && node.matches(selector)) {
							node.muted = true;
						} else if ('querySelectorAll' in node) {
							for (const element of node.querySelectorAll(selector)) {
								element.muted = true;
							}
						}
					}
				}

				// TODO: Find a way to avoid this.
				// This is quite inefficient, but it's needed to be able to work, for example, when browsing videos on YouTube.
				if (mutations.length > 0) {
					for (const element of document.querySelectorAll(selector)) {
						element.muted = true;
					}
				}
			});

			observer.observe(document, {
				childList: true,
				subtree: true
			});
		})();
		"""

	// https://github.com/feedback-assistant/reports/issues/79
	/// Mute all existing and future audio on websites, including audio in videos.
	func muteAudio() {
		let userScript = WKUserScript(
			source: Self.muteAudioCode,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: false
		)

		addUserScript(userScript)
	}
}


extension WKWebView {
	// TODO: Use https://developer.apple.com/documentation/webkit/wkwebview/3516410-mediatype when macOS 10.15.4 is out.
	// TODO: Move this to `SSWebView` instead and also expose a `response` property so we don't need the `mimeType` parameter.
	// https://github.com/feedback-assistant/reports/issues/82
	/**
	Centers a standalone image as WKWebView doesn't center it like Chrome and Firefox do.

	The image will aspect-fill the space available.
	*/
	func centerAndAspectFillImage(mimeType: String?) {
		guard mimeType?.hasPrefix("image/") == true else {
			return
		}

		let js = Self.createCSSInjectScript(
			"""
			/* Center image */
			body {
				display: flex;
				align-items: center;
				justify-content: center;
			}

			/* Aspect-fill image */
			img {
				width: 100%;
				height: 100%;
				object-fit: cover;
			}
			"""
		)

		evaluateJavaScript(js, completionHandler: nil)
	}
}


extension WKWebView {
	/// Clear all website data like cookies, local storage, caches, etc.
	func clearWebsiteData(completion: (() -> Void)?) {
		HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

		let dataStore = WKWebsiteDataStore.default()
		let types = WKWebsiteDataStore.allWebsiteDataTypes()

		dataStore.fetchDataRecords(ofTypes: types) { records in
			dataStore.removeData(
				ofTypes: types,
				for: records,
				completionHandler: completion ?? {}
			)
		}
	}
}


extension WKPreferences {
	// https://github.com/feedback-assistant/reports/issues/80
	var isDeveloperExtrasEnabled: Bool {
		get {
			value(forKey: "developerExtrasEnabled") as? Bool ?? false
		}
		set {
			setValue(newValue, forKey: "developerExtrasEnabled")
		}
	}
}


extension WKWindowFeatures {
	/// The size of the window.
	/// Defaults to 600 for width/height if not specified.
	var size: CGSize {
		.init(
			width: CGFloat(truncating: width ?? 600),
			height: CGFloat(truncating: height ?? 600)
		)
	}
}


/**
Wrap a value in an `ObservableObject` where the given `Publisher` triggers it to update. Note that the value is static and must be accessed as `.wrappedValue`. The publisher part is only meant to trigger an observable update.

- Important: If you pass a value type, it will obviously not be kept in sync with the source.

```
struct ContentView: View {
	@ObservedObject private var foo = ObservableValue(
		value: someNonReactiveValue,
		publisher: Foo.publisher
	)

	var body: some View {}
}
```

You can even pass in a meta type (`Foo.self`), for example, to wrap an struct:

```
struct Display {
	static var text: String { … }

	static let observable = ObservableValue(
		value: Self.self,
		publisher: NotificationCenter.default
			.publisher(for: NSApplication.didChangeScreenParametersNotification)
	)
}

// …

struct ContentView: View {
	@ObservedObject private var display = Display.observable

	var body: some View {
		Text(display.wrappedValue.text)
	}
}
```
*/
final class ObservableValue<Value>: ObservableObject {
	let objectWillChange = ObservableObjectPublisher()
	private var publisher: AnyCancellable?
	private(set) var wrappedValue: Value

	init<P: Publisher>(value: Value, publisher: P) {
		self.wrappedValue = value

		self.publisher = publisher.sink(
			receiveCompletion: { _ in },
			receiveValue: { [weak self] _ in
				self?.objectWillChange.send()
			}
		)
	}

	/// Manually trigger an update.
	func update() {
		objectWillChange.send()
	}
}


extension NSScreen: Identifiable {
	public var id: CGDirectDisplayID {
		deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
	}
}

extension NSScreen {
	static func from(cgDirectDisplayID id: CGDirectDisplayID) -> NSScreen? {
		screens.first { $0.id == id }
	}

	/// Returns a publisher that sends updates when anything related to screens change.
	/// This includes screens being added/removed, resolution change, and the screen frame changing (dock and menu bar being toggled).
	static var publisher: AnyPublisher<Void, Never> {
		Publishers.Merge(
			NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification),
			// We use a wake up notification as the screen setup might have changed during sleep. For example, a screen could have been unplugged.
			NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
		)
			.map { _ in }
			.eraseToAnyPublisher()
	}

	/// Get the screen that contains the menu bar and has origin at (0, 0).
	static var primary: NSScreen? { screens.first }

	/// This can be useful if you store a reference to a `NSScreen` instance as it may have been disconnected.
	var isConnected: Bool {
		Self.screens.contains { $0 == self }
	}

	/// Get the main screen if the current screen is not connected.
	var withFallbackToMain: NSScreen? { isConnected ? self : .main }

	/// Whether the screen shows a status bar.
	/// Returns `false` if the status bar is set to show/hide automatically as it then doesn't take up any screen space.
	var hasStatusBar: Bool {
		// When `screensHaveSeparateSpaces == true`, the menu bar shows on all the screens.
		!NSStatusBar.isAutomaticallyToggled && (self == .primary || Self.screensHaveSeparateSpaces)
	}

	/// Get the frame of the actual visible part of the screen. This means under the dock, but *not* under the status bar if there's a status bar. This is different from `.visibleFrame` which also includes the space under the status bar.
	var visibleFrameWithoutStatusBar: CGRect {
		var screenFrame = frame

		// Account for the status bar if the window is on the main screen and the status bar is permanently visible, or if on a secondary screen and secondary screens are set to show the status bar.
		if hasStatusBar {
			screenFrame.size.height -= NSStatusBar.system.thickness
		}

		return screenFrame
	}
}


struct Display: Hashable, Codable, Identifiable {
	/// Self wrapped in an observable that updates when display change.
	static let observable = ObservableValue(
		value: Self.self,
		publisher: NSScreen.publisher
	)

	/// The main display.
	static let main = Self(id: CGMainDisplayID())

	/// All displays.
	static var all: [Self] {
		NSScreen.screens.map { self.init(screen: $0) }
	}

	/// The ID of the display.
	let id: CGDirectDisplayID

	/// The `NSScreen` for the display.
	var screen: NSScreen? { NSScreen.from(cgDirectDisplayID: id) }

	/// The localized name of the display.
	var localizedName: String { screen?.localizedName ?? "<Unknown name>" }

	/// Whether the display is connected.
	var isConnected: Bool { screen?.isConnected ?? false }

	/// Get the main display if the current display is not connected.
	var withFallbackToMain: Self { isConnected ? self : .main }

	init(id: CGDirectDisplayID) {
		self.id = id
	}

	init(screen: NSScreen) {
		self.id = screen.id
	}
}


extension String {
	/// Word wrap the string at the given length.
	func wrapped(atLength length: Int) -> Self {
		var string = ""
		var currentLineLength = 0

		for word in components(separatedBy: .whitespaces) {
			let wordLength = word.count

			if currentLineLength + wordLength + 1 > length {
				// Can't wrap as the word is longer than the line.
				if wordLength >= length {
					string += word
				}

				string += "\n"
				currentLineLength = 0
			}

			currentLineLength += wordLength + 1
			string += "\(word) "
		}

		return string
	}
}


extension String {
	/// Make a URL more human-friendly by removing the scheme and `www.`.
	var removingSchemeAndWWWFromURL: Self {
		replacingOccurrences(matchingRegex: #"^https?:\/\/(?:www.)?"#, with: "")
	}
}


extension NSStatusBar {
	/// Whether the user has "Automatically hide and show the menu bar" enabled in system preferences.
	static var isAutomaticallyToggled: Bool {
		guard let screen = NSScreen.primary else {
			return false
		}

		return screen.frame.height - screen.visibleFrame.height < system.thickness
	}
}


/**
A scrollable and editable text view.

- Note: This exist as the SwiftUI `TextField` is unusable for multiline purposes.

It supports the `.lineLimit()` view modifier.

```
struct ContentView: View {
	@State private var text = ""

	var body: some View {
		VStack {
			Text("Custom CSS:")
			ScrollableTextView(text: $text)
				.frame(height: 100)
		}
	}
}
```
*/
struct ScrollableTextView: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	final class Coordinator: NSObject, NSTextViewDelegate {
		let view: ScrollableTextView

		init(_ view: ScrollableTextView) {
			self.view = view
		}

		func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else {
				return
			}

			view.text = textView.string
		}
	}

	@Binding var text: String
	var font = NSFont.controlContentFont(ofSize: 0)

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
		scrollView.borderType = .bezelBorder
		scrollView.drawsBackground = true

		let textView = scrollView.documentView as! NSTextView
		textView.delegate = context.coordinator
		textView.drawsBackground = false
		textView.isEditable = true
		textView.isSelectable = true
		textView.allowsUndo = true
		textView.textContainerInset = CGSize(width: 5, height: 10)
		textView.textColor = .controlTextColor

		return scrollView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		let textView = (nsView.documentView as! NSTextView)

		if text != textView.string {
			textView.string = text
		}

		textView.font = font

		if let lineLimit = context.environment.lineLimit {
			textView.textContainer?.maximumNumberOfLines = lineLimit
		}
	}
}


private struct BoxModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding()
			.background(Color.primary.opacity(0.05))
			.cornerRadius(4)
	}
}

extension View {
	/// Wrap the content in a box.
	func box() -> some View {
		modifier(BoxModifier())
	}
}


final class PowerSourceWatcher {
	enum PowerSource {
		case internalBattery
		case externalUnlimited
		case externalUPS

		var isUsingPowerAdapter: Bool { self == .externalUnlimited || self == .externalUPS }
		var isUsingBattery: Bool { self == .internalBattery }

		fileprivate init(identifier: String) {
			switch identifier {
			case kIOPMBatteryPowerKey:
				self = .internalBattery
			case kIOPMACPowerKey:
				self = .externalUnlimited
			case kIOPMUPSPowerKey:
				self = .externalUPS
			default:
				self = .externalUnlimited

				assertionFailure("This should not happen as `IOPSGetProvidingPowerSourceType` is documented to return one of the defined types")
			}
		}
	}

	var onChange: ((PowerSource) -> Void)?

	var powerSource: PowerSource {
		let identifier = IOPSGetProvidingPowerSourceType(nil)!.takeRetainedValue() as String
		return PowerSource(identifier: identifier)
	}

	init?() {
		let powerSourceCallback: IOPowerSourceCallbackType = { context in
			// Force-unwrapping is safe here as we're the ones passing the `context`.
			let this = Unmanaged<PowerSourceWatcher>.fromOpaque(context!).takeUnretainedValue()
			this.internalOnChange()
		}

		guard
			let runLoopSource = IOPSCreateLimitedPowerNotification(powerSourceCallback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))?.takeRetainedValue()
		else {
			return nil
		}

		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

		onChange?(powerSource)
	}

	private func internalOnChange() {
		onChange?(powerSource)
	}
}


/// A view that doesn't accept any mouse events.
class NonInteractiveView: NSView {
	override var mouseDownCanMoveWindow: Bool { true }
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
	override func hitTest(_ point: CGPoint) -> NSView? { nil }
}


private struct TooltipView: NSViewRepresentable {
	typealias NSViewType = NSView

	private let text: String?

	init(_ text: String?) {
		self.text = text
	}

	func makeNSView(context: Context) -> NSViewType {
		NonInteractiveView()
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.toolTip = text
	}
}

extension View {
	@available(macOS, obsoleted: 11, renamed: "help")
	func help2(_ text: String?) -> some View {
		overlay(TooltipView(text))
	}
}


extension SetAlgebra {
	/// Insert the `value` if it doesn't exist, otherwise remove it.
	mutating func toggleExistence(_ value: Element) {
		if contains(value) {
			remove(value)
		} else {
			insert(value)
		}
	}

	/// Insert the `value` if `shouldExist` is true, otherwise remove it.
	mutating func toggleExistence(_ value: Element, shouldExist: Bool) {
		if shouldExist {
			insert(value)
		} else {
			remove(value)
		}
	}
}


extension Collection {
	/**
	Returns a infinite sequence with consecutively unique random elements from the collection.

	```
	let x = [1, 2, 3].uniqueRandomElementIterator()

	x.next()
	//=> 2
	x.next()
	//=> 1

	for element in x.prefix(2) {
		print(element)
	}
	//=> 3
	//=> 1
	```
	*/
	func uniqueRandomElementIterator() -> AnyIterator<Element> {
		var previousNumber: Int?

		return AnyIterator {
			var offset: Int
			repeat {
				offset = Int.random(in: 0..<count)
			} while offset == previousNumber
			previousNumber = offset

			return self[index(startIndex, offsetBy: offset)]
		}
	}
}


extension NSColor {
	static let systemColors: Set<NSColor> = [
		.systemBlue,
		.systemBrown,
		.systemGray,
		.systemGreen,
		.systemOrange,
		.systemPink,
		.systemPurple,
		.systemRed,
		.systemYellow,
		.systemTeal,
		.systemIndigo
	]

	private static let uniqueRandomSystemColors = systemColors.uniqueRandomElementIterator()

	static func uniqueRandomSystemColor() -> NSColor {
		uniqueRandomSystemColors.next()!
	}
}


extension Timer {
	/// Creates a repeating timer that runs for the given `duration`.
	@discardableResult
	open class func scheduledRepeatingTimer(
		withTimeInterval interval: TimeInterval,
		duration: TimeInterval,
		onRepeat: @escaping (Timer) -> Void,
		onFinish: @escaping () -> Void
	) -> Timer {
		let startDate = Date()

		return Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
			guard Date() <= startDate.addingTimeInterval(duration) else {
				timer.invalidate()
				onFinish()
				return
			}

			onRepeat(timer)
		}
	}
}


extension NSStatusBarButton {
	/**
	Quickly cycles through random colors to make a rainbow animation so the user will notice it.

	- Note: It will do nothing if the user has enabled the “Reduce motion” accessibility preference.
	*/
	func playRainbowAnimation(duration: TimeInterval = 5) {
		guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
			return
		}

		let originalTintColor = contentTintColor

		Timer.scheduledRepeatingTimer(
			withTimeInterval: 0.1,
			duration: duration,
			onRepeat: { [weak self] _ in
				self?.contentTintColor = .uniqueRandomSystemColor()
			},
			onFinish: { [weak self] in
				self?.contentTintColor = originalTintColor
			}
		)
	}
}


extension RangeReplaceableCollection {
	/// Move the element at the `from` index to the `to` index.
	mutating func move(from fromIndex: Index, to toIndex: Index) {
		guard fromIndex != toIndex else {
			return
		}

		insert(remove(at: fromIndex), at: toIndex)
	}
}

extension RangeReplaceableCollection where Element: Equatable {
	/// Move the first equal element to the `to` index.
	mutating func move(_ element: Element, to toIndex: Index) {
		guard let fromIndex = firstIndex(of: element) else {
			return
		}

		move(from: fromIndex, to: toIndex)
	}
}

// TODO: Find a way to remove the `Index == Int` constraint.
extension Collection where Index == Int, Element: Equatable {
	/// Returns an array where the given element has moved to the `to` index.
	func moving(_ element: Element, to toIndex: Index) -> [Element] {
		var array = Array(self)
		array.move(element, to: toIndex)
		return array
	}
}

extension Collection where Index == Int, Element: Equatable {
	/// Returns an array where the given element has moved to the end of the array.
	func movingToEnd(_ element: Element) -> [Element] {
		moving(element, to: endIndex - 1)
	}
}


extension String {
	/**
	```
	"foo bar".replacingPrefix("foo", with: "unicorn")
	//=> "unicorn bar"
	```
	*/
	func replacingPrefix(_ prefix: Self, with replacement: Self) -> Self {
		guard hasPrefix(prefix) else {
			return self
		}

		return replacement + dropFirst(prefix.count)
	}
}


extension URL {
	/// Returns the user's real home directory when called in a sandboxed app.
	static let realHomeDirectory = Self(
		fileURLWithFileSystemRepresentation: getpwuid(getuid())!.pointee.pw_dir!,
		isDirectory: true,
		relativeTo: nil
	)

	/// Ensures the URL points to the closest directory if it's a file or self.
	var directoryURL: Self { hasDirectoryPath ? self : deletingLastPathComponent() }

	var tildePath: String {
		// Note: Can't use `FileManager.default.homeDirectoryForCurrentUser.relativePath` or `NSHomeDirectory()` here as they return the sandboxed home directory, not the real one.
		path.replacingPrefix(Self.realHomeDirectory.path, with: "~")
	}

	var exists: Bool { FileManager.default.fileExists(atPath: path) }
}


extension DispatchQueue {
	/**
	Performs the `execute` closure immediately if we're on the main thread or synchronously puts it on the main thread otherwise.
	*/
	@discardableResult
	static func mainSafeSync<T>(execute work: () throws -> T) rethrows -> T {
		if Thread.isMainThread {
			return try work()
		} else {
			return try main.sync(execute: work)
		}
	}
}


extension URL {
	/**
	Access a security-scoped resource.

	The access will be automatically relinquished at the end of the scope of the given `accessor`.

	- Important: Don't do anything async in the `accessor` as the resource access is only available synchronously in the `accessor` scope.
	*/
	func accessSecurityScopedResource<Value>(_ accessor: (URL) throws -> Value) rethrows -> Value {
		let didStartAccessing = startAccessingSecurityScopedResource()

		defer {
			if didStartAccessing {
				stopAccessingSecurityScopedResource()
			}
		}

		return try accessor(self)
	}

	/**
	Access a security-scoped resource asynchronously.

	The access will be automatically when the `completion` closure is called.

	```
	directoryUrl.accessSecurityScopedResourceAsync { completion in
		startConversion(urls, outputDirectory: directoryUrl) {
			completion()
		}
	}
	```
	*/
	func accessSecurityScopedResourceAsync<Value>(_ accessor: (@escaping () -> Void) throws -> Value) rethrows -> Value {
		let didStartAccessing = startAccessingSecurityScopedResource()

		return try accessor {
			if didStartAccessing {
				stopAccessingSecurityScopedResource()
			}
		}
	}
}


// TODO: I plan to extract this into a Swift Package when it's been battle-tested.
/// This always requests the permission to a directory. If you give it file URL, it will ask for permission to the parent directory.
final class SecurityScopedBookmarkManager {
	private static let lock = NSLock()

	// TODO: Abstract this to a generic class to have a Dictionary like thing that is synced to UserDefaults and the subclass it here.
	private final class BookmarksUserDefaults {
		// TODO: This should probably be an argument to init.
		private let userDefaultsKey = Defaults.Key<[String: Data]>("__securityScopedBookmarks__", default: [:])

		private var bookmarkStore: [String: Data] {
			get { Defaults[userDefaultsKey] }
			set {
				Defaults[userDefaultsKey] = newValue
			}
		}

		subscript(url: URL) -> Data? {
			// TODO: Should it really be resolving symlinks?
			get { bookmarkStore[url.resolvingSymlinksInPath().absoluteString] }
			set {
				var bookmarks = bookmarkStore
				bookmarks[url.resolvingSymlinksInPath().absoluteString] = newValue
				bookmarkStore = bookmarks
			}
		}
	}

	private final class NSOpenSavePanelDelegateHandler: NSObject, NSOpenSavePanelDelegate {
		let currentURL: URL

		init(url: URL) {
			// It's important to resolve symlinks so it doesn't use the sandbox URL.
			self.currentURL = url.resolvingSymlinksInPath()
			super.init()
		}

		/*
		We only allow this directory.

		You might think we could use `didChangeToDirectoryURL` and set `sender.directoryURL = currentURL` there, but that doesn't work. The directory cannot be programmatically changed after the panel is opened.
		*/
		func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
			url == currentURL
		}

		// This should in theory not be needed as we already disable the “Allow” button, but just in case.
		func panel(_ sender: Any, validate url: URL) throws {
			if url != currentURL {
				throw NSError.appError(
					"Incorrect directory.",
					recoverySuggestion: "Select the directory “\(currentURL.tildePath)”."
				)
			}
		}
	}

	private static var bookmarks = BookmarksUserDefaults()

	/// Save the bookmark.
	static func saveBookmark(for url: URL) throws {
		bookmarks[url] = try url.accessSecurityScopedResource {
			try $0.bookmarkData(options: .withSecurityScope)
		}
	}

	/// Load the bookmark.
	/// Returns `nil` if there's no bookmark for the given URL or if the bookmark cannot be loaded.
	static func loadBookmark(for url: URL) -> URL? {
		guard let bookmarkData = bookmarks[url] else {
			return nil
		}

		var isBookmarkDataStale = false

		guard let newUrl = try? URL(
			resolvingBookmarkData: bookmarkData,
			options: .withSecurityScope,
			bookmarkDataIsStale: &isBookmarkDataStale
		) else {
			return nil
		}

		if isBookmarkDataStale {
			guard (try? saveBookmark(for: newUrl)) != nil else {
				return nil
			}
		}

		return newUrl
	}

	/// Returns `nil` if the user didn't give permission or if the bookmark couldn't be saved.
	static func promptUserForPermission(atDirectory directoryURL: URL, message: String? = nil) -> URL? {
		lock.lock()

		defer {
			lock.unlock()
		}

		let delegate = NSOpenSavePanelDelegateHandler(url: directoryURL)

		let userChosenURL: URL? = DispatchQueue.mainSafeSync {
			let openPanel = with(NSOpenPanel()) {
				$0.delegate = delegate
				$0.directoryURL = directoryURL
				$0.allowsMultipleSelection = false
				$0.canChooseDirectories = true
				$0.canChooseFiles = false
				$0.canCreateDirectories = false
				$0.title = "Permission"
				$0.message = message ?? "\(App.name) needs access to the “\(directoryURL.lastPathComponent)” directory. Click “Allow” to proceed."
				$0.prompt = "Allow"
			}

			NSApp.activate(ignoringOtherApps: true)

			guard openPanel.runModal() == .OK else {
				return nil
			}

			return openPanel.url
		}

		guard let securityScopedURL = userChosenURL else {
			return nil
		}

		do {
			try saveBookmark(for: securityScopedURL)
		} catch {
			NSApp.presentError(error)
			return nil
		}

		return securityScopedURL
	}

	/// Access the URL in the given closure and have the access cleaned up afterwards.
	/// The closure receives a boolean of whether the URL is accessible.
	static func accessURL(_ url: URL, accessHandler: () throws -> Void) rethrows {
		_ = url.startAccessingSecurityScopedResource()

		defer {
			url.stopAccessingSecurityScopedResource()
		}

		try accessHandler()
	}

	/// Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.
	/// It handles cleaning up the access to the URL for you.
	static func accessURLByPromptingIfNeeded(_ url: URL, accessHandler: () throws -> Void) {
		let directoryURL = url.directoryURL

		guard let securityScopedURL = loadBookmark(for: directoryURL) ?? promptUserForPermission(atDirectory: directoryURL) else {
			return
		}

		do {
			try accessURL(securityScopedURL, accessHandler: accessHandler)
		} catch {
			NSApp.presentError(error)
			return
		}
	}

	/// Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.
	/// You have to manually call the returned method when you no longer need access to the URL.
	@discardableResult
	static func accessURLByPromptingIfNeeded(_ url: URL) -> (() -> Void) {
		let directoryURL = url.directoryURL

		guard let securityScopedURL = loadBookmark(for: directoryURL) ?? promptUserForPermission(atDirectory: directoryURL) else {
			return {}
		}

		_ = securityScopedURL.startAccessingSecurityScopedResource()

		return {
			securityScopedURL.stopAccessingSecurityScopedResource()
		}
	}
}

extension URL {
	/// Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.
	/// It handles cleaning up the access to the URL for you.
	func accessSandboxedURLByPromptingIfNeeded(accessHandler: () throws -> Void) {
		SecurityScopedBookmarkManager.accessURLByPromptingIfNeeded(self, accessHandler: accessHandler)
	}

	/// Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.
	/// You have to manually call the returned method when you no longer need access to the URL.
	func accessSandboxedURLByPromptingIfNeeded() -> (() -> Void) {
		SecurityScopedBookmarkManager.accessURLByPromptingIfNeeded(self)
	}
}


extension URL {
	/**
	Normalizes the URL to improve equality matching.

	- Note: It's currently very simple and lacks a lot of normalizations.

	```
	URL("https://sindresorhus.com/?").normalized()
	//=> "https://sindresorhus.com"
	```
	*/
	func normalized(
		removeFragment: Bool = false,
		removeQuery: Bool = false
	) -> Self {
		let url = absoluteURL.standardized

		guard var components = url.components else {
			return self
		}

		if components.path == "/" {
			components.path = ""
		}

		// Remove port 80 if it's there as it's the default.
		if components.port == 80 {
			components.port = nil
		}

		// Lowercase host and scheme.
		components.host = components.host?.lowercased()
		components.scheme = components.scheme?.lowercased()

		// Remove empty fragment.
		// - `https://sindresorhus.com/#`
		if components.fragment?.isEmpty == true {
			components.fragment = nil
		}

		// Remove empty query.
		// - `https://sindresorhus.com/?`
		if components.query?.isEmpty == true {
			components.query = nil
		}

		if removeFragment {
			components.fragment = nil
		}

		if removeQuery {
			components.query = nil
		}

		return components.url ?? self
	}
}


extension URL {
	enum PlaceholderError: LocalizedError {
		case failedToEncodePlaceholder(String)
		case invalidURLAfterSubstitution(String)

		var errorDescription: String? {
			switch self {
			case .failedToEncodePlaceholder(let placeholder):
				return "Failed to encode placeholder “\(placeholder)”"
			case .invalidURLAfterSubstitution(let urlString):
				return "New URL was not valid after substituting placeholders. URL string is “\(urlString)”"
			}
		}
	}

	/**
	Replaces any occurrences of `placeholder` in the URL with `replacement`.

	- Throws: An error if the placeholder could not be encoded or if the replacement would create an invalid URL.
	*/
	func replacingPlaceholder(_ placeholder: String, with replacement: String) throws -> URL {
		guard
			let encodedPlaceholder = placeholder.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
		else {
			throw PlaceholderError.failedToEncodePlaceholder(placeholder)
		}

		let urlString = absoluteString
			.replacingOccurrences(of: encodedPlaceholder, with: replacement)

		guard let newURL = URL(string: urlString) else {
			throw PlaceholderError.invalidURLAfterSubstitution(urlString)
		}

		return newURL
	}
}


struct Reachability {
	/// Checks whether we're currently online.
	static func isOnline(host: String = "apple.com") -> Bool {
		guard let ref = SCNetworkReachabilityCreateWithName(nil, host) else {
			return false
		}

		var flags = SCNetworkReachabilityFlags.connectionAutomatic
		if !SCNetworkReachabilityGetFlags(ref, &flags) {
			return false
		}

		return flags.contains(.reachable) && !flags.contains(.connectionRequired)
	}

	/// Checks multiple sources of whether we're currently online.
	static func isOnlineExtensive() -> Bool {
		let hosts = [
			"apple.com",
			"google.com",
			"cloudflare.com",
			"baidu.com",
			"yandex.ru"
		]

		return hosts.contains { isOnline(host: $0) }
	}
}


extension NSError {
	/**
	Use this for generic app errors.

	- Note: Prefer using a specific enum-type error whenever possible.

	- Parameter description: The description of the error. This is shown as the first line in error dialogs.
	- Parameter recoverySuggestion: Explain how the user how they can recover from the error. For example, "Try choosing a different directory". This is usually shown as the second line in error dialogs.
	- Parameter userInfo: Metadata to add to the error. Can be a custom key or any of the `NSLocalizedDescriptionKey` keys except `NSLocalizedDescriptionKey` and `NSLocalizedRecoverySuggestionErrorKey`.
	- Parameter domainPostfix: String to append to the `domain` to make it easier to identify the error. The domain is the app's bundle identifier.
	*/
	static func appError(
		_ description: String,
		recoverySuggestion: String? = nil,
		userInfo: [String: Any] = [:],
		domainPostfix: String? = nil
	) -> Self {
		var userInfo = userInfo
		userInfo[NSLocalizedDescriptionKey] = description

		if let recoverySuggestion = recoverySuggestion {
			userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
		}

		return .init(
			domain: domainPostfix.map { "\(App.id) - \($0)" } ?? App.id,
			code: 1, // This is what Swift errors end up as.
			userInfo: userInfo
		)
	}
}


final class AutofocusedTextField: NSTextField {
	override func viewDidMoveToWindow() {
		window?.makeFirstResponder(self)
	}
}


/**
Hashable wrapper for a metatype value.
*/
struct HashableType<T>: Hashable {
	static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.base == rhs.base
	}

	let base: T.Type

	init(_ base: T.Type) {
		self.base = base
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(base))
	}
}

extension Dictionary {
	subscript<T>(key: T.Type) -> Value? where Key == HashableType<T> {
		get { self[HashableType(key)] }
		set {
			self[HashableType(key)] = newValue
		}
	}
}


extension NSResponder {
	// This method is internally implemented on `NSResponder` as `Error` is generic which comes with many limitations.
	fileprivate func presentErrorAsSheet(
		_ error: Error,
		for window: NSWindow,
		didPresent: (() -> Void)?
	) {
		final class DelegateHandler {
			var didPresent: (() -> Void)?

			@objc
			func didPresentHandler() {
				didPresent?()
			}
		}

		let delegate = DelegateHandler()
		delegate.didPresent = didPresent

		presentError(
			error,
			modalFor: window,
			delegate: delegate,
			didPresent: #selector(delegate.didPresentHandler),
			contextInfo: nil
		)
	}
}

extension Error {
	/// Present the error as an async sheet on the given window.
	/// - Note: This exists because the built-in `NSResponder#presentError(forModal:)` method requires too many arguments, selector as callback, and it says it's modal but it's not blocking, which is surprising.
	func presentAsSheet(for window: NSWindow, didPresent: (() -> Void)?) {
		NSApp.presentErrorAsSheet(self, for: window, didPresent: didPresent)
	}

	/// Present the error as a blocking modal sheet on the given window.
	/// If the window is nil, the error will be presented in an app-level modal dialog.
	func presentAsModalSheet(for window: NSWindow?) {
		guard let window = window else {
			presentAsModal()
			return
		}

		presentAsSheet(for: window) {
			NSApp.stopModal()
		}

		NSApp.runModal(for: window)
	}

	/// Present the error as a blocking app-level modal dialog.
	func presentAsModal() {
		NSApp.presentError(self)
	}
}


/**
Creates a window controller that can only ever have one window.

This can be useful when you need there to be only one window of a type, for example, a preferences window. If the window already exists, and you call `.showWindow()`, it will instead just focus the existing window.

- Important: Don't create an instance of this. Instead, call the static `.showWindow()` method. Also mark your `convenience init` as `private` so you don't accidentally call it.

```
final class PreferencesWindowController: SingletonWindowController {
	private convenience init() {
		let window = NSWindow()
		self.init(window: window)

		window.center()
	}
}

// …

PreferencesWindowController.showWindow()
```
*/
class SingletonWindowController: NSWindowController, NSWindowDelegate {
	private static var instances = [HashableType<SingletonWindowController>: SingletonWindowController]()

	private static var currentInstance: SingletonWindowController {
		guard let instance = instances[self] else {
			let instance = self.init()
			instances[self] = instance
			return instance
		}

		return instance
	}

	static var window: NSWindow? {
		get {
			currentInstance.window
		}
		set {
			currentInstance.window = newValue
		}
	}

	static func showWindow() {
		// Menu bar apps need to be activated, otherwise, things like input focus doesn't work.
		if NSApp.activationPolicy() == .accessory {
			NSApp.activate(ignoringOtherApps: true)
		}

		window?.makeKeyAndOrderFront(nil)
	}

	override init(window: NSWindow?) {
		super.init(window: window)
		window?.delegate = self
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func windowWillClose(_ notification: Notification) {
		Self.instances[Self] = nil
	}

	@available(*, unavailable)
	override func showWindow(_ sender: Any?) {}
}


enum AssociationPolicy {
	case assign
	case retainNonatomic
	case copyNonatomic
	case retain
	case copy

	var rawValue: objc_AssociationPolicy {
		switch self {
		case .assign:
			return .OBJC_ASSOCIATION_ASSIGN
		case .retainNonatomic:
			return .OBJC_ASSOCIATION_RETAIN_NONATOMIC
		case .copyNonatomic:
			return .OBJC_ASSOCIATION_COPY_NONATOMIC
		case .retain:
			return .OBJC_ASSOCIATION_RETAIN
		case .copy:
			return .OBJC_ASSOCIATION_COPY
		}
	}
}

final class ObjectAssociation<Value: Any> {
	private let defaultValue: Value
	private let policy: AssociationPolicy

	init(defaultValue: Value, policy: AssociationPolicy = .retainNonatomic) {
		self.defaultValue = defaultValue
		self.policy = policy
	}

	subscript(index: AnyObject) -> Value {
		get {
			objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as? Value ?? defaultValue
		}
		set {
			objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, policy.rawValue)
		}
	}
}

extension ObjectAssociation {
	convenience init<T>(policy: AssociationPolicy = .retainNonatomic) where Value == T? {
		self.init(defaultValue: nil, policy: policy)
	}
}


private let bindLifetimeAssociatedObjectKey = ObjectAssociation<[AnyObject]>(defaultValue: [])

/// Binds the lifetime of object A to object B, so when B deallocates, so does A, but not before.
func bindLifetime(of object: AnyObject, to target: AnyObject) {
	var retainedObjects = bindLifetimeAssociatedObjectKey[target]
	retainedObjects.append(object)
	bindLifetimeAssociatedObjectKey[target] = retainedObjects
}


// MARK: - KVO utilities
extension NSKeyValueObservation {
	/// Keeps the observation alive as long as the given object.
	@discardableResult
	func tiedToLifetimeOf(_ object: AnyObject) -> Self {
		bindLifetime(of: self, to: object)
		return self
	}
}

extension NSObjectProtocol where Self: NSObject {
	/// Convenience `observe` function that triggers initially and on new values and only provides the new value.
	func observe<Value>(
		_ keyPath: KeyPath<Self, Value>,
		onChange: @escaping (Value) -> Void
	) -> NSKeyValueObservation {
		observe(keyPath, options: [.initial, .new]) { _, change in
			guard let newValue = change.newValue else {
				return
			}

			onChange(newValue)
		}
	}

	/**
	Bind the property of one object to the property of another object.

	```
	window.bind(\.title, to: toolbarItem, at: \.title)
		.tiedToLifetimeOf(self)
	```
	*/
	func bind<Value, Target>(
		_ sourceKeyPath: KeyPath<Self, Value>,
		to target: Target,
		at targetKeyPath: ReferenceWritableKeyPath<Target, Value>
	) -> NSKeyValueObservation {
		observe(sourceKeyPath) {
			target[keyPath: targetKeyPath] = $0
		}
	}

	/**
	Bind the `String?` property of one object to the `String` property of another object.

	If the source property is `nil` and the target is not optional, the target will be set to an empty string.

	```
	webView.bind(\.title, to: window, at: \.title)
		.tiedToLifetimeOf(self)
	```
	*/
	func bind<Target>(
		_ sourceKeyPath: KeyPath<Self, String?>,
		to target: Target,
		at targetKeyPath: ReferenceWritableKeyPath<Target, String>
	) -> NSKeyValueObservation {
		observe(sourceKeyPath) {
			target[keyPath: targetKeyPath] = $0 ?? ""
		}
	}
}
// MARK: -
