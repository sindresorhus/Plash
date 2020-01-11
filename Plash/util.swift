import Cocoa
import WebKit
import SwiftUI
import Combine
import Network
import LaunchAtLogin
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
			self.onUpdate?(self)
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
	file: StaticString = #file,
	line: UInt = #line
) -> Never {
	fatalError("\(function): \(reason)", file: file, line: line)
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


struct App {
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


struct System {
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


struct Meta {
	static func openSubmitFeedbackPage() {
		let metadata =
			"""
			\(App.name) \(App.versionWithBuild) - \(App.id)
			macOS \(System.osVersion)
			\(System.hardwareModel)
			"""

		let query: [String: String] = [
			"product": App.name,
			"metadata": metadata
		]

		URL(string: "https://sindresorhus.com/feedback/")!.addingDictionaryAsQuery(query).open()
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
		self.target = trampoline
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

	func makeNSView(context: NSViewRepresentableContext<Self>) -> NSViewType {
		let nsView = NSButton(title: "", target: nil, action: nil)
		nsView.wantsLayer = true
		nsView.translatesAutoresizingMaskIntoConstraints = false
		nsView.setContentHuggingPriority(.defaultHigh, for: .vertical)
		nsView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: NSViewRepresentableContext<Self>) {
		if attributedTitle == nil {
			nsView.title = title ?? ""
		}

		if title == nil {
			nsView.attributedTitle = attributedTitle ?? "".attributedString
		}

		nsView.keyEquivalent = keyEquivalent?.rawValue ?? ""

		nsView.onAction { _ in
			self.action()
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
		guard let host = self.host else {
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
			let host = self.host
		else {
			return false
		}

		let hostComponents = host.components(separatedBy: ".")

		return hostComponents.count >= 2 &&
			!hostComponents[0].isEmpty &&
			hostComponents.last!.count > 1
	}
}


public final class DefaultsObservable<Value: Codable>: ObservableObject {
	public let objectWillChange = ObservableObjectPublisher()
	private var observation: DefaultsObservation?
	private let key: Defaults.Key<Value>

	public var value: Value {
		get { Defaults[key] }
		set {
			objectWillChange.send()
			Defaults[key] = newValue
		}
	}

	public init(_ key: Defaults.Key<Value>) {
		self.key = key

		self.observation = Defaults.observe(key, options: []) { [weak self] _ in
			self?.objectWillChange.send()
		}
	}
}

public final class DefaultsOptionalObservable<Value: Codable>: ObservableObject {
	public let objectWillChange = ObservableObjectPublisher()
	private var observation: DefaultsObservation?
	private let key: Defaults.OptionalKey<Value>

	public var value: Value? {
		get { Defaults[key] }
		set {
			objectWillChange.send()
			Defaults[key] = newValue
		}
	}

	public init(_ key: Defaults.OptionalKey<Value>) {
		self.key = key

		self.observation = Defaults.observe(key, options: []) { [weak self] _ in
			self?.objectWillChange.send()
		}
	}
}

extension Defaults {
	/**
	Make a Defaults key an observable.

	```
	struct ContentView: View {
		@ObservedObject var unicorn = Defaults.observable(.unicorn)
	}
	```
	*/
	public static func observable<Value: Codable>(_ key: Defaults.Key<Value>) -> DefaultsObservable<Value> {
		DefaultsObservable(key)
	}

	/**
	Make a Defaults optional key an observable.

	```
	struct ContentView: View {
		@ObservedObject var unicorn = Defaults.observable(.unicorn)
	}
	```
	*/
	public static func observable<Value: Codable>(_ key: Defaults.OptionalKey<Value>) -> DefaultsOptionalObservable<Value> {
		DefaultsOptionalObservable(key)
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
			get: { self.wrappedValue },
			set: {
				let oldValue = self.wrappedValue
				self.wrappedValue = $0
				let newValue = self.wrappedValue
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
			get: { self.wrappedValue ?? defaultValue },
			set: {
				self.wrappedValue = $0
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
			get: { self.wrappedValue == nil },
			set: {
				self.wrappedValue = $0 ? nil : falseSetValue
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
			get: { self.wrappedValue != nil },
			set: {
				self.wrappedValue = $0 ? trueSetValue : nil
			}
		)
	}
}


extension StringProtocol where Self: RangeReplaceableCollection {
	var removingNewlines: Self {
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

	var trimmedStart: Self {
		replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
	}

	var trimmedEnd: Self {
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
	func truncated(to number: Int, truncationIndicator: Self = "…") -> Self {
		if number <= 0 {
			return ""
		} else if count > number {
			return Self(prefix(number - truncationIndicator.count)).trimmedEnd + truncationIndicator
		} else {
			return self
		}
	}
}


extension WKWebView {
	static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Safari/605.1.15"

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
}


// TODO: Move this to the `LaunchAtLogin` package.
extension LaunchAtLogin {
	struct Toggle: View {
		@State private var launchAtLogin = isEnabled

		var body: some View {
			SwiftUI.Toggle(
				"Launch at Login",
				isOn: $launchAtLogin.onChange {
					isEnabled = $0
				}
			)
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
			get: { get(self.wrappedValue) },
			set: { newValue in
				self.wrappedValue = set(newValue)
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
			get: { self.wrappedValue },
			set: { newValue in
				self.wrappedValue = set(newValue)
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
			get: { get(self.wrappedValue) },
			set: { newValue in
				self.wrappedValue = newValue
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

	var shouldCloseOnEscapePress = true

	convenience init() {
		self.init(
			contentRect: .zero,
			styleMask: [
				.titled,
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


extension WKUserContentController {
	private func createCSSInjectScript(_ css: String) -> String {
		let textContent = css.addingPercentEncoding(withAllowedCharacters: .letters) ?? css

		return
			"""
			const style = document.createElement('style');
			style.textContent = unescape('\(textContent)');
			document.documentElement.appendChild(style);
			"""
	}

	/// Add CSS to the page.
	func addCSS(_ css: String) {
		let source = createCSSInjectScript(css)

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
		NSScreen.screens.first { $0.id == id }
	}

	/// This can be useful if you store a reference to a `NSScreen` instance as it may have been disconnected.
	var isConnected: Bool {
		NSScreen.screens.contains { $0 == self }
	}
}


struct Display: Hashable, Codable, Identifiable {
	/// Self wrapped in an observable that updates when display change.
	static let observable = ObservableValue(
		value: Self.self,
		publisher: NotificationCenter.default
			.publisher(for: NSApplication.didChangeScreenParametersNotification)
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
	var withFallback: Self { isConnected ? self : .main }

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
