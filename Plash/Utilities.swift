import IOKit.ps
import IOKit.pwr_mgt
import WebKit
import SwiftUI
import Combine
import Network
import SystemConfiguration
import CryptoKit
import StoreKit
import UniformTypeIdentifiers
import LinkPresentation
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


// swiftlint:disable:next no_cgfloat
extension CGFloat {
	/**
	Get a Double from a CGFloat. This makes it easier to work with optionals.
	*/
	var double: Double { Double(self) }
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
	private let isOpenSubject = CurrentValueSubject<Bool, Never>(false)
	private let needsUpdateSubject = PassthroughSubject<Void, Never>()

	private(set) var isOpen = false
	let isOpenPublisher: AnyPublisher<Bool, Never>
	let needsUpdatePublisher: AnyPublisher<Void, Never>

	override init(title: String) {
		self.isOpenPublisher = isOpenSubject.eraseToAnyPublisher()
		self.needsUpdatePublisher = needsUpdateSubject.eraseToAnyPublisher()
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
		isOpenSubject.send(true)
	}

	func menuDidClose(_ menu: NSMenu) {
		isOpen = false
		isOpenSubject.send(false)
	}

	func menuNeedsUpdate(_ menu: NSMenu) {
		needsUpdateSubject.send()
	}
}


// TODO: Adopt the native method if this lands in Swift
// From: https://github.com/apple/swift-evolution/pull/861/files#diff-7227258cce0fbf6442a789b162652031R110
public struct FatalReason: CustomStringConvertible {
	public static let unreachable = Self("Should never be reached during execution.")
	public static let notYetImplemented = Self("Not yet implemented.")
	public static let subtypeMustOverride = Self("Must be overridden in subtype.")
	public static let mustNotBeCalled = Self("Should never be called.")

	public let reason: String

	public init(_ reason: String) {
		self.reason = reason
	}

	public var description: String { reason }
}

public func fatalError(
	because reason: FatalReason,
	function: StaticString = #function,
	file: StaticString = #fileID,
	line: Int = #line
) -> Never {
	fatalError("\(function): \(reason)", file: file, line: UInt(line))
}



final class CallbackMenuItem: NSMenuItem {
	private static var validateCallback: ((NSMenuItem) -> Bool)?

	static func validate(_ callback: @escaping (NSMenuItem) -> Bool) {
		validateCallback = callback
	}

	private let callback: () -> Void

	init(
		_ title: String,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		data: Any? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		action: @escaping () -> Void
	) {
		self.callback = action
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

	@objc
	private func action(_ sender: NSMenuItem) {
		callback()
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
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(title: title, action: nil, keyEquivalent: key)
		self.isEnabled = isEnabled
		self.isChecked = isChecked
		self.isHidden = isHidden

		if let keyModifiers = keyModifiers {
			self.keyEquivalentModifierMask = keyModifiers
		}
	}

	convenience init(
		_ attributedTitle: NSAttributedString,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) {
		self.init(
			"",
			key: key,
			keyModifiers: keyModifiers,
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
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
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
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false
	) -> NSMenuItem {
		let menuItem = NSMenuItem(
			attributedTitle,
			key: key,
			keyModifiers: keyModifiers,
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
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		action: @escaping () -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			title,
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden,
			action: action
		)
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addCallbackItem(
		_ title: NSAttributedString,
		key: String = "",
		keyModifiers: NSEvent.ModifierFlags? = nil,
		isEnabled: Bool = true,
		isChecked: Bool = false,
		isHidden: Bool = false,
		action: @escaping () -> Void
	) -> NSMenuItem {
		let menuItem = CallbackMenuItem(
			"",
			key: key,
			keyModifiers: keyModifiers,
			isEnabled: isEnabled,
			isChecked: isChecked,
			isHidden: isHidden,
			action: action
		)
		menuItem.attributedTitle = title
		addItem(menuItem)
		return menuItem
	}

	@discardableResult
	func addSettingsItem() -> NSMenuItem {
		addCallbackItem("Preferences…", key: ",") {
			SSApp.showSettingsWindow()
		}
	}

	@discardableResult
	func addLinkItem(_ title: String, destination: URL) -> NSMenuItem {
		addCallbackItem(title) {
			destination.open()
		}
	}

	@discardableResult
	func addLinkItem(_ title: NSAttributedString, destination: URL) -> NSMenuItem {
		addCallbackItem(title) {
			destination.open()
		}
	}

	@discardableResult
	func addMoreAppsItem() -> NSMenuItem {
		addLinkItem(
			"More Apps By Me",
			destination: "macappstore://apps.apple.com/developer/id328077650"
		)
	}

	@discardableResult
	func addAboutItem() -> NSMenuItem {
		addCallbackItem("About") {
			NSApp.activate(ignoringOtherApps: true)
			NSApp.orderFrontStandardAboutPanel(nil)
		}
	}

	@discardableResult
	func addQuitItem() -> NSMenuItem {
		addSeparator()

		return addCallbackItem("Quit \(SSApp.name)", key: "q") {
			SSApp.quit()
		}
	}
}


enum SSApp {
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
			\(SSApp.name) \(SSApp.versionWithBuild) - \(SSApp.id)
			macOS \(Device.osVersion)
			\(Device.hardwareModel)
			"""

		let query: [String: String] = [
			"product": SSApp.name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback/")
			.addingDictionaryAsQuery(query)
			.open()
	}

	static func activateIfAccessory() {
		guard NSApp.activationPolicy() == .accessory else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)
	}
}

extension SSApp {
	/**
	Manually show the SwiftUI settings window.
	*/
	static func showSettingsWindow() {
		SSApp.activateIfAccessory()

		// Run in the next runloop so it doesn't conflict with SwiftUI if run at startup.
		DispatchQueue.main.async {
			NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
		}
	}
}


extension URL {
	/**
	Convenience for opening URLs.
	*/
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


extension URL: ExpressibleByStringLiteral {
	/**
	Example:

	```
	let url: URL = "https://sindresorhus.com"
	```
	*/
	public init(stringLiteral value: StaticString) {
		self.init(string: "\(value)")!
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


enum Device {
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


extension Sequence {
	/**
	Convert a sequence to a dictionary by mapping over the values and using the returned key as the key and the current sequence element as value.

	```
	[1, 2, 3].toDictionary { $0 }
	//=> [1: 1, 2: 2, 3: 3]
	```
	*/
	func toDictionary<Key: Hashable>(withKey pickKey: (Element) -> Key) -> [Key: Element] {
		var dictionary = [Key: Element]()
		for element in self {
			dictionary[pickKey(element)] = element
		}
		return dictionary
	}

	/**
	Convert a sequence to a dictionary by mapping over the elements and returning a key/value tuple representing the new dictionary element.

	```
	[(1, "a"), (2, "b")].toDictionary { ($1, $0) }
	//=> ["a": 1, "b": 2]
	```
	*/
	func toDictionary<Key: Hashable, Value>(withKey pickKeyValue: (Element) -> (Key, Value)) -> [Key: Value] {
		var dictionary = [Key: Value]()
		for element in self {
			let newElement = pickKeyValue(element)
			dictionary[newElement.0] = newElement.1
		}
		return dictionary
	}

	/**
	Same as the above but supports returning optional values.

	```
	[(1, "a"), (nil, "b")].toDictionary { ($1, $0) }
	//=> ["a": 1, "b": nil]
	```
	*/
	func toDictionary<Key: Hashable, Value>(withKey pickKeyValue: (Element) -> (Key, Value?)) -> [Key: Value?] {
		var dictionary = [Key: Value?]()
		for element in self {
			let newElement = pickKeyValue(element)
			dictionary[newElement.0] = newElement.1
		}
		return dictionary
	}
}


extension Dictionary {
	func compactValues<T>() -> [Key: T] where Value == T? {
		// TODO: Make this `compactMapValues(\.self)` when https://bugs.swift.org/browse/SR-12897 is fixed.
		compactMapValues { $0 }
	}
}


extension StringProtocol {
	/**
	Check if the string only contains whitespace characters.
	*/
	var isWhitespace: Bool {
		allSatisfy(\.isWhitespace)
	}

	/**
	Check if the string is empty or only contains whitespace characters.
	*/
	var isEmptyOrWhitespace: Bool { isEmpty || isWhitespace }
}


extension Collection {
	/**
	Works on strings too, since they're just collections.
	*/
	var nilIfEmpty: Self? { isEmpty ? nil : self }
}

extension StringProtocol {
	var nilIfEmptyOrWhitespace: Self? { isEmptyOrWhitespace ? nil : self }
}


extension CharacterSet {
	/**
	Characters allowed to be unescaped in an URL.

	https://tools.ietf.org/html/rfc3986#section-2.3
	*/
	static let urlUnreservedRFC3986 = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
}


/**
This should really not be necessary, but it's at least needed for my `formspree.io` form...

Otherwise is results in "Internal Server Error" after submitting the form

Relevant: https://www.djackson.org/why-we-do-not-use-urlcomponents/
*/
private func escapeQueryComponent(_ query: String) -> String {
	query.addingPercentEncoding(withAllowedCharacters: .urlUnreservedRFC3986)!
}


extension Dictionary where Key == String {
	/**
	This correctly escapes items. See `escapeQueryComponent`.
	*/
	var toQueryItems: [URLQueryItem] {
		map {
			URLQueryItem(
				name: escapeQueryComponent($0),
				value: escapeQueryComponent("\($1)")
			)
		}
	}

	var toQueryString: String {
		var components = URLComponents()
		components.queryItems = toQueryItems
		return components.query!
	}
}


extension URLComponents {
	mutating func addDictionaryAsQuery(_ dict: [String: String]) {
		percentEncodedQuery = dict.toQueryString
	}
}


extension URL {
	func addingDictionaryAsQuery(_ dict: [String: String]) -> Self {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
		components.addDictionaryAsQuery(dict)
		return components.url ?? self
	}
}


extension URLComponents {
	/**
	This correctly escapes items. See `escapeQueryComponent`.
	*/
	var queryDictionary: [String: String] {
		get {
			queryItems?.toDictionary { ($0.name, $0.value) }.compactValues() ?? [:]
		}
		set {
			// Using `percentEncodedQueryItems` instead of `queryItems` since the query items are already custom-escaped. See `escapeQueryComponent`.
			percentEncodedQueryItems = newValue.toQueryItems
		}
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
		self.top = top
		self.left = left
		self.bottom = bottom
		self.right = right
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
			top: vertical,
			left: horizontal,
			bottom: vertical,
			right: horizontal
		)
	}

	var horizontal: Double { left + right }
	var vertical: Double { top + bottom }
}


extension String {
	var nsString: NSString { self as NSString } // swiftlint:disable:this legacy_objc_type

	var nsAttributedString: NSAttributedString { .init(string: self) }
}


private var controlActionClosureProtocolAssociatedObjectKey: UInt8 = 0

protocol ControlActionClosureProtocol: NSObjectProtocol {
	var target: AnyObject? { get set }
	var action: Selector? { get set }
}

private final class ActionTrampoline: NSObject {
	private let action: (NSEvent) -> Void

	init(action: @escaping (NSEvent) -> Void) {
		self.action = action
	}

	@objc
	fileprivate func handleAction(_ sender: AnyObject) {
		action(NSApp.currentEvent!)
	}
}

extension ControlActionClosureProtocol {
	/**
	Closure version of `.action`

	```
	let button = NSButton(title: "Unicorn", target: nil, action: nil)

	button.onAction { _ in
		print("Button action")
	}
	```
	*/
	func onAction(_ action: @escaping (NSEvent) -> Void) {
		let trampoline = ActionTrampoline(action: action)
		target = trampoline
		self.action = #selector(ActionTrampoline.handleAction)
		objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
	}
}

extension NSControl: ControlActionClosureProtocol {}
extension NSMenuItem: ControlActionClosureProtocol {}
extension NSToolbarItem: ControlActionClosureProtocol {}
extension NSGestureRecognizer: ControlActionClosureProtocol {}


struct CocoaButton: NSViewRepresentable {
	typealias NSViewType = NSButton

	enum KeyEquivalent: String {
		case escape = "\u{1b}"
		case `return` = "\r"

		// More here: https://cool8jay.github.io/shortcut-nemenuitem-nsbutton/
	}

	var title: String?
	var attributedTitle: NSAttributedString?
	let keyEquivalent: KeyEquivalent?
	let bezelStyle: NSButton.BezelStyle
	let action: () -> Void

	init(
		_ title: String,
		keyEquivalent: KeyEquivalent? = nil,
		bezelStyle: NSButton.BezelStyle = .rounded,
		action: @escaping () -> Void
	) {
		self.title = title
		self.keyEquivalent = keyEquivalent
		self.bezelStyle = bezelStyle
		self.action = action
	}

	init(
		_ attributedTitle: NSAttributedString,
		keyEquivalent: KeyEquivalent? = nil,
		bezelStyle: NSButton.BezelStyle = .rounded,
		action: @escaping () -> Void
	) {
		self.attributedTitle = attributedTitle
		self.keyEquivalent = keyEquivalent
		self.bezelStyle = bezelStyle
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
			nsView.attributedTitle = attributedTitle ?? "".nsAttributedString
		}

		nsView.keyEquivalent = keyEquivalent?.rawValue ?? ""
		nsView.bezelStyle = bezelStyle

		nsView.onAction { _ in
			action()
		}
	}
}


enum Validators {
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

	/**
	Check if the `host` part of a URL is an IP address.
	*/
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


extension Binding: Identifiable where Value: Identifiable {
	public var id: Value.ID { wrappedValue.id }
}


extension StringProtocol where Self: RangeReplaceableCollection {
	var removingNewlines: Self {
		// TODO: Use `filter(!\.isNewline)` when key paths support negation.
		filter { !$0.isNewline }
	}
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

	/**
	Returns a string with the matches of the given regex replaced with the given replacement string.
	*/
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
	/**
	`URLComponents` have better parsing than `URL` and supports things like `scheme:path` (notice the missing `//`).
	*/
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
	/**
	Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	static func showModal(
		for window: NSWindow? = nil,
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) -> NSApplication.ModalResponse {
		NSAlert(
			title: title,
			message: message,
			style: style,
			buttonTitles: buttonTitles,
			defaultButtonIndex: defaultButtonIndex
		)
			.runModal(for: window)
	}

	/**
	The index in the `buttonTitles` array for the button to use as default.

	Set `-1` to not have any default. Useful for really destructive actions.
	*/
	var defaultButtonIndex: Int {
		get {
			buttons.firstIndex { $0.keyEquivalent == "\r" } ?? -1
		}
		set {
			// Clear the default button indicator from other buttons.
			for button in buttons where button.keyEquivalent == "\r" {
				button.keyEquivalent = ""
			}

			if newValue != -1 {
				buttons[newValue].keyEquivalent = "\r"
			}
		}
	}

	convenience init(
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) {
		self.init()
		self.messageText = title
		self.alertStyle = style

		if let message = message {
			self.informativeText = message
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex = defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/**
	Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
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

	/**
	Adds buttons with the given titles to the alert.
	*/
	func addButtons(withTitles buttonTitles: [String]) {
		for buttonTitle in buttonTitles {
			addButton(withTitle: buttonTitle)
		}
	}
}


extension NSEvent {
	static var modifiers: ModifierFlags {
		modifierFlags
			.intersection(.deviceIndependentFlagsMask)
			// We remove `capsLock` as it shouldn't affect the modifiers.
			// We remove `numericPad`/`function` as arrow keys trigger it, use `event.specialKeys` instead.
			.subtracting([.capsLock, .numericPad, .function])
	}

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
			// It's important that this is not zero as that causes some SwiftUI rendering problems.
			contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
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
	static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
	static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36"

	/**
	Evaluate JavaScript synchronously.

	- Important: This will block the main thread. Don't use it for anything that takes a long time.
	*/
	@discardableResult
	func evaluateSync(script: String) throws -> Any? {
		var isFinished = false
		var returnResult: Any?
		var returnError: Error?

		evaluateJavaScript(script, in: nil, in: .defaultClient) { result in
			switch result {
			case .success(let data):
				returnResult = data
			case .failure(let error):
				returnError = error
			}

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

	// https://github.com/feedback-assistant/reports/issues/81
	/**
	Whether the web view should have a background. Set to `false` to make it transparent.
	*/
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
	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
		webView.defaultAlertHandler(message: message)
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
		webView.defaultConfirmHandler(message: message)
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
		webView.defaultPromptHandler(prompt: prompt, defaultText: defaultText)
	}

	func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
		webView.defaultUploadPanelHandler(parameters: parameters)
	}

	func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
		webView.defaultAuthChallengeHandler(challenge: challenge)
	}
}
```
*/
extension WKWebView {
	/**
	Default handler for JavaScript `alert()` to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultAlertHandler(message: String) {
		let alert = NSAlert()
		alert.messageText = message
		alert.runModal()
	}

	/**
	Default handler for JavaScript `confirm()` to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultConfirmHandler(message: String) -> Bool {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = message
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")
		return alert.runModal() == .alertFirstButtonReturn
	}

	/**
	Default handler for JavaScript `prompt()` to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultPromptHandler(prompt: String, defaultText: String?) -> String? {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = prompt
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")

		let textField = AutofocusedTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 22))
		textField.stringValue = defaultText ?? ""
		alert.accessoryView = textField

		return alert.runModal() == .alertFirstButtonReturn ? textField.stringValue : nil
	}

	/**
	Default handler for JavaScript initiated upload panel to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultUploadPanelHandler(parameters: WKOpenPanelParameters) -> [URL]? { // swiftlint:disable:this discouraged_optional_collection
		let openPanel = NSOpenPanel()
		openPanel.level = .floating
		openPanel.prompt = "Choose"
		openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
		openPanel.canChooseFiles = !parameters.allowsDirectories
		openPanel.canChooseDirectories = parameters.allowsDirectories

		// It's intentionally modal as we don't want the user to interact with the website until they're done with the panel.
		return openPanel.runModal() == .OK ? openPanel.urls : nil
	}

	// Can be tested at https://jigsaw.w3.org/HTTP/Basic/ with `guest` as username and password.
	/**
	Default handler for websites requiring basic authentication. To be used in `WKDelegate`.
	*/
	@MainActor
	func defaultAuthChallengeHandler(challenge: URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
		guard
			let host = url?.host,
			challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
				|| challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
		else {
			return (.performDefaultHandling, nil)
		}

		let alert = NSAlert()
		alert.messageText = "Log in to \(host)"
		alert.addButton(withTitle: "Log In")
		alert.addButton(withTitle: "Cancel")

		let view = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 54))
		alert.accessoryView = view

		let username = AutofocusedTextField(frame: CGRect(x: 0, y: 32, width: 200, height: 22))
		username.contentType = .username
		username.placeholderString = "Username"
		view.addSubview(username)

		let password = NSSecureTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 22))
		password.contentType = .password
		password.placeholderString = "Password"
		view.addSubview(password)

		// TODO: It doesn't continue tabbing to the buttons after the password field.
		username.nextKeyView = password

		SSApp.activateIfAccessory()

		guard alert.runModal() == .alertFirstButtonReturn else {
			return (.rejectProtectionSpace, nil)
		}

		let credential = URLCredential(
			user: username.stringValue,
			password: password.stringValue,
			persistence: .synchronizable
		)

		return (.useCredential, credential)
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
	/**
	Add CSS to the page.
	*/
	func addCSS(_ css: String) {
		let source = WKWebView.createCSSInjectScript(css)

		let userScript = WKUserScript(
			source: source,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: false,
			in: .defaultClient
		)

		addUserScript(userScript)
	}

	/**
	Add JavaScript to the page.

	You can use `await` at the top-level.

	The code runs in a separate realm from the website itself.
	*/
	func addJavaScript(_ javaScript: String) {
		let source =
			"""
			(async () => {
				\(javaScript)
			})();
			"""

		let userScript = WKUserScript(
			source: source,
			injectionTime: .atDocumentEnd,
			forMainFrameOnly: false,
			in: .world(name: UUID().uuidString)
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
		body * [style*="background-image"],
		video,
		iframe {
			filter: invert(100%) hue-rotate(180deg) !important;
			background-color: unset !important;
		}
		"""

	/**
	Invert the colors on the page. Pseudo dark mode.
	*/
	func invertColors(onlyWhenInDarkMode: Bool) {
		if onlyWhenInDarkMode {
			addCSS(
				"""
				@media (prefers-color-scheme: dark) {
					\(Self.invertColorsCSS)
				}
				"""
			)
		} else {
			addCSS(Self.invertColorsCSS)
		}
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
	/**
	Mute all existing and future audio on websites, including audio in videos.
	*/
	func muteAudio() {
		let userScript = WKUserScript(
			source: Self.muteAudioCode,
			injectionTime: .atDocumentStart,
			forMainFrameOnly: false,
			in: .defaultClient
		)

		addUserScript(userScript)
	}
}


extension WKWebView {
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

		evaluateJavaScript(js, in: nil, in: .defaultClient)
	}
}


extension WKWebView {
	/**
	Clear all website data like cookies, local storage, caches, etc.
	*/
	func clearWebsiteData() async {
		HTTPCookieStorage.shared.removeCookies(since: .distantPast)

		let store = WKWebsiteDataStore.default()
		let types = WKWebsiteDataStore.allWebsiteDataTypes()
		let records = await store.dataRecords(ofTypes: types)
		await store.removeData(ofTypes: types, for: records)
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
	/**
	The size of the window.

	Defaults to 600 for width/height if not specified.
	*/
	var size: CGSize {
		.init(
			width: Double(truncating: width ?? 600),
			height: Double(truncating: height ?? 600)
		)
	}
}


/**
Wrap a value in an `ObservableObject` where the given `Publisher` triggers it to update. Note that the value is static and must be accessed as `.wrappedValue`. The publisher part is only meant to trigger an observable update.

- Important: If you pass a value type, it will obviously not be kept in sync with the source.

```
struct ContentView: View {
	@StateObject private var foo = ObservableValue(
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

	/**
	Manually trigger an update.
	*/
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

	/**
	Returns a publisher that sends updates when anything related to screens change.

	This includes screens being added/removed, resolution change, and the screen frame changing (dock and menu bar being toggled).
	*/
	static var publisher: AnyPublisher<Void, Never> {
		Publishers.Merge(
			SSPublishers.screenParametersDidChange,
			// We use a wake up notification as the screen setup might have changed during sleep. For example, a screen could have been unplugged.
			SSPublishers.deviceDidWake
		)
			.eraseToAnyPublisher()
	}

	/**
	Get the screen that contains the menu bar and has origin at (0, 0).
	*/
	static var primary: NSScreen? { screens.first }

	/**
	This can be useful if you store a reference to a `NSScreen` instance as it may have been disconnected.
	*/
	var isConnected: Bool {
		Self.screens.contains { $0 == self }
	}

	/**
	Get the main screen if the current screen is not connected.
	*/
	var withFallbackToMain: NSScreen? { isConnected ? self : .main }

	/**
	Whether the screen shows a status bar.

	Returns `false` if the status bar is set to show/hide automatically as it then doesn't take up any screen space.
	*/
	var hasStatusBar: Bool {
		// When `screensHaveSeparateSpaces == true`, the menu bar shows on all the screens.
		!NSStatusBar.isAutomaticallyToggled && (self == .primary || Self.screensHaveSeparateSpaces)
	}

	/**
	Get the frame of the actual visible part of the screen. This means under the dock, but *not* under the status bar if there's a status bar. This is different from `.visibleFrame` which also includes the space under the status bar.
	*/
	var visibleFrameWithoutStatusBar: CGRect {
		var screenFrame = frame

		// Account for the status bar if the window is on the main screen and the status bar is permanently visible, or if on a secondary screen and secondary screens are set to show the status bar.
		if hasStatusBar {
			// Without this, the website would show through the 1 point padding between the menu bar and the window.
			let statusBarBottomPadding = 1.0

			screenFrame.size.height -= NSStatusBar.actualThickness + statusBarBottomPadding
		}

		return screenFrame
	}
}


struct Display: Hashable, Codable, Identifiable {
	/**
	Self wrapped in an observable that updates when display change.
	*/
	static let observable = ObservableValue(
		value: Self.self,
		publisher: NSScreen.publisher
	)

	/**
	The main display.
	*/
	static let main = Self(id: CGMainDisplayID())

	/**
	All displays.
	*/
	static var all: [Self] {
		NSScreen.screens.map { self.init(screen: $0) }
	}

	/**
	The ID of the display.
	*/
	let id: CGDirectDisplayID

	/**
	The `NSScreen` for the display.
	*/
	var screen: NSScreen? { .from(cgDirectDisplayID: id) }

	/**
	The localized name of the display.
	*/
	var localizedName: String { screen?.localizedName ?? "<Unknown name>" }

	/**
	Whether the display is connected.
	*/
	var isConnected: Bool { screen?.isConnected ?? false }

	/**
	Get the main display if the current display is not connected.
	*/
	var withFallbackToMain: Self { isConnected ? self : .main }

	init(id: CGDirectDisplayID) {
		self.id = id
	}

	init(screen: NSScreen) {
		self.id = screen.id
	}
}


extension String {
	/**
	Word wrap the string at the given length.
	*/
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
	/**
	Make a URL more human-friendly by removing the scheme and `www.`.
	*/
	var removingSchemeAndWWWFromURL: Self {
		replacingOccurrences(matchingRegex: #"^https?:\/\/(?:www.)?"#, with: "")
	}
}


extension URL {
	/**
	Human-friendly representation of the URL: `https://sindresorhus.com/` → `sindresorhus.com`.
	*/
	var humanString: String {
		guard !isFileURL else {
			return tildePath
		}

		let string = normalized().absoluteString.removingSchemeAndWWWFromURL
		return string.removingPercentEncoding ?? string
	}
}


extension NSWorkspace {
	/**
	Returns the height of the Dock.

	It's `nil` if there's no primary screen or if the Dock is set to be automatically hidden.
	*/
	var dockHeight: Double? {
		guard let screen = NSScreen.primary else {
			return nil
		}

		let height = screen.visibleFrame.origin.y - screen.frame.origin.y

		guard height != 0 else {
			return nil
		}

		return height
	}

	/**
	Whether the user has "Turn Hiding On" enabled in the Dock preferences.
	*/
	var isDockAutomaticallyToggled: Bool {
		guard NSScreen.primary != nil else {
			return false
		}

		return dockHeight == nil
	}
}


extension NSStatusBar {
	/**
	The actual thickness of the status bar. `.thickness` confusingly returns the thickness of the content area.

	Keep in mind for screen calculations that the status bar has an additional 1 point padding below it (between it and windows).
	*/
	static let actualThickness = 24.0

	/**
	Whether the user has "Automatically hide and show the menu bar" enabled in system preferences.
	*/
	static var isAutomaticallyToggled: Bool {
		guard let screen = NSScreen.primary else {
			return false
		}

		// There's a 1 point gap between the status bar and any maximized window.
		let statusBarBottomPadding = 1.0

		let menuBarHeight = actualThickness + statusBarBottomPadding
		let dockHeight = NSWorkspace.shared.dockHeight ?? 0

		return (screen.frame.height - screen.visibleFrame.height - dockHeight) < menuBarHeight
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
	var isAutomaticQuoteSubstitutionEnabled = true
	var isAutomaticDashSubstitutionEnabled = true
	var isAutomaticTextReplacementEnabled = true
	var isAutomaticSpellingCorrectionEnabled = true

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

		textView.isAutomaticQuoteSubstitutionEnabled = isAutomaticQuoteSubstitutionEnabled
		textView.isAutomaticDashSubstitutionEnabled = isAutomaticDashSubstitutionEnabled
		textView.isAutomaticTextReplacementEnabled = isAutomaticTextReplacementEnabled
		textView.isAutomaticSpellingCorrectionEnabled = isAutomaticSpellingCorrectionEnabled
	}
}


private struct BoxModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding()
			.backgroundColor(.primary.opacity(0.05))
			.cornerRadius(4)
	}
}

extension View {
	/**
	Wrap the content in a box.
	*/
	func box() -> some View {
		modifier(BoxModifier())
	}
}


extension View {
	func multilineText() -> some View {
		lineLimit(nil)
			.fixedSize(horizontal: false, vertical: true)
	}
}


extension View {
	@inlinable
	func backgroundColor(_ color: Color) -> some View {
		background(color)
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

	private lazy var didChangeSubject = CurrentValueSubject<PowerSource, Never>(powerSource)

	/**
	Publishes the power source when it changes. It also publishes an initial event.
	*/
	private(set) lazy var didChangePublisher = didChangeSubject.eraseToAnyPublisher()

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
	}

	private func internalOnChange() {
		didChangeSubject.send(powerSource)
	}
}


/**
A view that doesn't accept any mouse events.
*/
class NonInteractiveView: NSView { // swiftlint:disable:this final_class
	override var mouseDownCanMoveWindow: Bool { true }
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
	override func hitTest(_ point: CGPoint) -> NSView? { nil }
}


extension SetAlgebra {
	/**
	Insert the `value` if it doesn't exist, otherwise remove it.
	*/
	mutating func toggleExistence(_ value: Element) {
		if contains(value) {
			remove(value)
		} else {
			insert(value)
		}
	}

	/**
	Insert the `value` if `shouldExist` is true, otherwise remove it.
	*/
	mutating func toggleExistence(_ value: Element, shouldExist: Bool) {
		if shouldExist {
			insert(value)
		} else {
			remove(value)
		}
	}
}


extension Sequence {
	func eraseToAnySequence() -> AnySequence<Element> { .init(self) }
}

extension Collection {
	/**
	Returns a infinite sequence with unique random elements from the collection.

	Elements will only repeat after all elements have been seen.

	This can be useful for slideshows and music playlists where you want to ensure that the elements are better spread out.

	If the collection only has a single element, that element will be repeated forever.
	If the collection is empty, it will never return any elements.

	```
	let sequence = [1, 2, 3, 4].infiniteUniformRandomSequence()

	for element in sequence.prefix(3) {
		print(element)
	}
	//=> 3
	//=> 1
	//=> 2

	let iterator = sequence.makeIterator()

	iterator.next()
	//=> 4
	iterator.next()
	//=> 1
	```
	*/
	func infiniteUniformRandomSequence() -> AnySequence<Element> {
		guard !isEmpty else {
			return [].eraseToAnySequence()
		}

		return AnySequence { () -> AnyIterator in
			guard count > 1 else {
				return AnyIterator { first }
			}

			var currentIndices = [Index]()
			var previousIndex: Index?

			return AnyIterator {
				if currentIndices.isEmpty {
					currentIndices = indices.shuffled()

					// Ensure there are no duplicate elements on the edges.
					if currentIndices.last == previousIndex {
						currentIndices = currentIndices.reversed()
					}
				}

				let index = currentIndices.popLast()! // It cannot be nil.
				previousIndex = index
				return self[index]
			}
		}
	}
}


extension NSColor {
	static let systemColors: Set<NSColor> = [
		// TODO: Add the new colors wen targeting macOS 12.
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

	private static let uniqueRandomSystemColors = systemColors.infiniteUniformRandomSequence().makeIterator()

	static func uniqueRandomSystemColor() -> NSColor {
		uniqueRandomSystemColors.next()!
	}
}


extension Timer {
	/**
	Creates a repeating timer that runs for the given `duration`.
	*/
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
	/**
	Move the element at the `from` index to the `to` index.
	*/
	mutating func move(from fromIndex: Index, to toIndex: Index) {
		guard fromIndex != toIndex else {
			return
		}

		insert(remove(at: fromIndex), at: toIndex)
	}
}

extension RangeReplaceableCollection where Element: Equatable {
	/**
	Move the first equal element to the `to` index.
	*/
	mutating func move(_ element: Element, to toIndex: Index) {
		guard let fromIndex = firstIndex(of: element) else {
			return
		}

		move(from: fromIndex, to: toIndex)
	}
}

extension Collection where Index == Int, Element: Equatable {
	/**
	Returns an array where the given element has moved to the `to` index.
	*/
	func moving(_ element: Element, to toIndex: Index) -> [Element] {
		var array = Array(self)
		array.move(element, to: toIndex)
		return array
	}
}

extension Collection where Index == Int, Element: Equatable {
	/**
	Returns an array where the given element has moved to the end of the array.
	*/
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
	/**
	Returns the user's real home directory when called in a sandboxed app.
	*/
	static let realHomeDirectory = Self(
		fileURLWithFileSystemRepresentation: getpwuid(getuid())!.pointee.pw_dir!,
		isDirectory: true,
		relativeTo: nil
	)

	/**
	Ensures the URL points to the closest directory if it's a file or self.
	*/
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
}


// TODO: I plan to extract this into a Swift Package when it's been battle-tested.
/**
This always requests the permission to a directory. If you give it file URL, it will ask for permission to the parent directory.
*/
enum SecurityScopedBookmarkManager {
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
			// Resolving symlinks is important for normalization. For example, sometimes a reference to the Desktop directory is pointed at a symlink in the sandbox container: `file:///Users/sindresorhus/Library/Containers/com.sindresorhus.Plash/Data/Desktop/`.
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

	/**
	Save the bookmark.
	*/
	static func saveBookmark(for url: URL) throws {
		bookmarks[url] = try url.accessSecurityScopedResource {
			try $0.bookmarkData(options: .withSecurityScope)
		}
	}

	/**
	Load the bookmark.

	Returns `nil` if there's no bookmark for the given URL or if the bookmark cannot be loaded.
	*/
	static func loadBookmark(for url: URL) -> URL? {
		guard let bookmarkData = bookmarks[url] else {
			return nil
		}

		var isBookmarkDataStale = false

		guard
			let newUrl = try? URL(
				resolvingBookmarkData: bookmarkData,
				options: .withSecurityScope,
				bookmarkDataIsStale: &isBookmarkDataStale
			)
		else {
			return nil
		}

		if isBookmarkDataStale {
			guard (try? saveBookmark(for: newUrl)) != nil else {
				return nil
			}
		}

		return newUrl
	}

	/**
	Returns `nil` if the user didn't give permission or if the bookmark couldn't be saved.
	*/
	@MainActor
	static func promptUserForPermission(
		atDirectory directoryURL: URL,
		message: String? = nil
	) -> URL? {
		lock.lock()

		defer {
			lock.unlock()
		}

		let delegate = NSOpenSavePanelDelegateHandler(url: directoryURL)

		let openPanel = with(NSOpenPanel()) {
			$0.delegate = delegate
			$0.directoryURL = directoryURL
			$0.allowsMultipleSelection = false
			$0.canChooseDirectories = true
			$0.canChooseFiles = false
			$0.canCreateDirectories = false
			$0.title = "Permission"
			$0.message = message ?? "\(SSApp.name) needs access to the “\(directoryURL.lastPathComponent)” directory. Click “Allow” to proceed."
			$0.prompt = "Allow"
		}

		NSApp.activate(ignoringOtherApps: true)

		guard openPanel.runModal() == .OK else {
			return nil
		}

		guard let securityScopedURL = openPanel.url else {
			return nil
		}

		do {
			try saveBookmark(for: securityScopedURL)
		} catch {
			error.presentAsModal()
			return nil
		}

		return securityScopedURL
	}

	/**
	Access the URL in the given closure and have the access cleaned up afterwards.

	The closure receives a boolean of whether the URL is accessible.
	*/
	static func accessURL(_ url: URL, accessHandler: () throws -> Void) rethrows {
		_ = url.startAccessingSecurityScopedResource()

		defer {
			url.stopAccessingSecurityScopedResource()
		}

		try accessHandler()
	}

	/**
	Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.

	It handles cleaning up the access to the URL for you.
	*/
	@MainActor
	static func accessURLByPromptingIfNeeded(_ url: URL, accessHandler: () throws -> Void) {
		let directoryURL = url.directoryURL

		guard let securityScopedURL = loadBookmark(for: directoryURL) ?? promptUserForPermission(atDirectory: directoryURL) else {
			return
		}

		do {
			try accessURL(securityScopedURL, accessHandler: accessHandler)
		} catch {
			error.presentAsModal()
			return
		}
	}

	/**
	Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.

	You have to manually call the returned method when you no longer need access to the URL.
	*/
	@MainActor
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
	/**
	Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.

	It handles cleaning up the access to the URL for you.
	*/
	@MainActor
	func accessSandboxedURLByPromptingIfNeeded(accessHandler: () throws -> Void) {
		SecurityScopedBookmarkManager.accessURLByPromptingIfNeeded(self, accessHandler: accessHandler)
	}

	/**
	Accepts a file URL to a directory or file. If it's a file, it will prompt for permissions to its containing directory.

	You have to manually call the returned method when you no longer need access to the URL.
	*/
	@MainActor
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


enum Reachability {
	/**
	Checks whether we're currently online.
	*/
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

	/**
	Checks multiple sources of whether we're currently online.
	*/
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
			domain: domainPostfix.map { "\(SSApp.id) - \($0)" } ?? SSApp.id,
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
	/**
	Present the error as an async sheet on the given window.

	The function resumes when the sheet is dismissed.

	- Note: This exists because the built-in `NSResponder#presentError(forModal:)` method requires too many arguments, selector as callback, and it says it's modal but it's not blocking, which is surprising.
	*/
	@MainActor
	func presentAsSheet(for window: NSWindow) async {
		await withCheckedContinuation { continuation in
			NSApp.presentErrorAsSheet(self, for: window) {
				continuation.resume()
			}
		}
	}

	/**
	Present the error as a blocking modal sheet on the given window.

	If the window is nil, the error will be presented in an app-level modal dialog.

	- Important: Prefer `.presentAsSheet()` whenever possible.

	Thread-safe.
	*/
	func presentAsModalSheet(for window: NSWindow?) {
		guard let window = window else {
			presentAsModalLegacy()
			return
		}

		DispatchQueue.main.async {
			NSApp.presentErrorAsSheet(self, for: window) {
				NSApp.stopModal()
			}

			// This is requried as otherwise `NSApp.runModal` somtimes causes exceptions.
			DispatchQueue.main.async {
				NSApp.runModal(for: window)
			}
		}
	}

	/**
	Present the error as a blocking app-level modal dialog.

	Tread-safe.
	*/
	func presentAsModalLegacy() {
		DispatchQueue.main.async {
			SSApp.activateIfAccessory()
			NSApp.presentError(self)
		}
	}

	/**
	Present the error as a blocking app-level modal dialog.
	*/
	@MainActor
	func presentAsModal() {
		// It seems this is not yet working correctly: https://github.com/feedback-assistant/reports/issues/288
//		SSApp.activateIfAccessory()
//		NSApp.presentError(self)

		presentAsModalLegacy()
	}

	/**
	Present the error as an async sheet on the given window if the window is not `nil`, otherwise as an app-modal dialog.

	The function resumes when the dialog is dismissed.
	*/
	@MainActor
	func present(in window: NSWindow? = nil) async {
		guard let window = window else {
			presentAsModal()
			return
		}

		await presentAsSheet(for: window)
	}
}


extension Error {
	// Check if the error is a WKWebView `Plug-in handled load` error, which can happen when you open a video directly. It's more like a notification and it can be safely ignored.
	var isWebViewPluginHandledLoad: Bool {
		let nsError = self as NSError
		return nsError.domain == "WebKitErrorDomain" && nsError.code == 204
	}
}


extension Error {
	public var isCancelled: Bool {
		do {
			throw self
		} catch URLError.cancelled, CocoaError.userCancelled {
			return true
		} catch {
			return false
		}
	}
}


extension WKWebView {
	/**
	Returns `true` if the error can be ignored.
	*/
	static func canIgnoreError(_ error: Error) -> Bool {
		// Ignore the request being cancelled which can happen if the user clicks on a link while a website is loading.
		error.isCancelled || error.isWebViewPluginHandledLoad
	}
}


/**
Creates a window controller that can only ever have one window.

This can be useful when you need there to be only one window of a type, for example, a settings window. If the window already exists, and you call `.showWindow()`, it will instead just focus the existing window.

- Important: Don't create an instance of this. Instead, call the static `.showWindow()` method. Also mark your `convenience init` as `private` so you don't accidentally call it.

```
final class SettingsWindowController: SingletonWindowController {
	private convenience init() {
		let window = NSWindow()
		self.init(window: window)

		window.center()
	}
}

// …

SettingsWindowController.showWindow()
```
*/
class SingletonWindowController: NSWindowController, NSWindowDelegate { // swiftlint:disable:this final_class
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
		SSApp.activateIfAccessory()
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
		Self.instances[Self.self] = nil
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


// MARK: - KVO utilities
extension NSObjectProtocol where Self: NSObject {
	/**
	Bind the property of an object to the property of another object.

	```
	window.bind(\.title, to: toolbarItem, at: \.title)
		.store(forTheLifetimeOf: window)
	```
	*/
	func bind<Value, Target>(
		_ sourceKeyPath: KeyPath<Self, Value>,
		to target: Target,
		at targetKeyPath: ReferenceWritableKeyPath<Target, Value>
	) -> AnyCancellable {
		publisher(for: sourceKeyPath)
			.sink {
				target[keyPath: targetKeyPath] = $0
			}
	}

	/**
	Bind the optional property of an object to the property of another object. If the optional property is `nil`, the given `default` value will be used.

	```
	webView.bind(\.title, to: window, at: \.title)
		.store(forTheLifetimeOf: webView)
	```
	*/
	func bind<Value, Target>(
		_ sourceKeyPath: KeyPath<Self, Value?>,
		to target: Target,
		at targetKeyPath: ReferenceWritableKeyPath<Target, Value>,
		default: Value
	) -> AnyCancellable {
		publisher(for: sourceKeyPath)
			.sink {
				target[keyPath: targetKeyPath] = $0 ?? `default`
			}
	}
}
// MARK: -


extension URL {
	/**
	Create a URL from a human string, gracefully.

	By default, it only accepts `localhost` as a TLD-less URL.

	```
	URL(humanString: "sindresorhus.com")?.absoluteString
	//=> "https://sindresorhus.com"
	```
	*/
	init?(humanString: String) {
		let string = humanString.trimmed

		guard
			!string.isEmpty,
			!string.hasPrefix("."),
			!string.hasSuffix("."),
			string != "https://",
			string != "http://",
			string != "file://"
		else {
			return nil
		}

		let isValid = string.contains(".")
			|| string.hasPrefix("localhost")
			|| string.hasPrefix("file://")

		guard
			!string.hasPrefix("https://"),
			!string.hasPrefix("http://"),
			!string.hasPrefix("file://")
		else {
			guard isValid else {
				return nil
			}

			self.init(string: string)
			return
		}

		guard isValid else {
			return nil
		}

		let url = string.replacingOccurrences(of: #"^(?!(?:\w+:)?\/\/)"#, with: "https://", options: .regularExpression)

		self.init(string: url)
	}
}


extension SSApp {
	/**
	This is like `SSApp.runOnce()` but let's you have an else-statement too.

	```
	if SSApp.runOnceShouldRun(identifier: "foo") {
		// True only the first time and only once.
	} else {

	}
	```
	*/
	static func runOnceShouldRun(identifier: String) -> Bool {
		let key = "SS_App_runOnce__\(identifier)"

		guard !UserDefaults.standard.bool(forKey: key) else {
			return false
		}

		UserDefaults.standard.set(true, forKey: key)
		return true
	}

	/**
	Run a closure only once ever, even between relaunches of the app.
	*/
	static func runOnce(identifier: String, _ execute: () -> Void) {
		guard runOnceShouldRun(identifier: identifier) else {
			return
		}

		execute()
	}
}


extension AnyCancellable {
	private enum AssociatedKeys {
		static let cancellables = ObjectAssociation<Set<AnyCancellable>>(defaultValue: [])
	}

	/**
	Stores this AnyCancellable for the lifetime of the given `object`.
	*/
	func store(forTheLifetimeOf object: AnyObject) {
		store(in: &AssociatedKeys.cancellables[object])
	}
}


extension View {
	/**
	Conditionally modify the view. For example, apply modifiers, wrap the view, etc.

	```
	Text("Foo")
		.padding()
		.if(someCondition) {
			$0.foregroundColor(.pink)
		}
	```

	```
	VStack() {
		Text("Line 1")
		Text("Line 2")
	}
		.if(someCondition) { content in
			ScrollView(.vertical) { content }
		}
	```
	*/
	@ViewBuilder
	func `if`<Content: View>(
		_ condition: @autoclosure () -> Bool,
		modify: (Self) -> Content
	) -> some View {
		if condition() {
			modify(self)
		} else {
			self
		}
	}

	/**
	This overload makes it possible to preserve the type. For example, doing an `if` in a chain of `Text`-only modifiers.

	```
	Text("🦄")
		.if(isOn) {
			$0.fontWeight(.bold)
		}
		.kerning(10)
	```
	*/
	func `if`(
		_ condition: @autoclosure () -> Bool,
		modify: (Self) -> Self
	) -> Self {
		condition() ? modify(self) : self
	}
}


extension View {
	/**
	Conditionally modify the view. For example, apply modifiers, wrap the view, etc.
	*/
	@ViewBuilder
	func `if`<IfContent: View, ElseContent: View>(
		_ condition: @autoclosure () -> Bool,
		if modifyIf: (Self) -> IfContent,
		else modifyElse: (Self) -> ElseContent
	) -> some View {
		if condition() {
			modifyIf(self)
		} else {
			modifyElse(self)
		}
	}

	/**
	Conditionally modify the view. For example, apply modifiers, wrap the view, etc.

	This overload makes it possible to preserve the type. For example, doing an `if` in a chain of `Text`-only modifiers.
	*/
	func `if`(
		_ condition: @autoclosure () -> Bool,
		if modifyIf: (Self) -> Self,
		else modifyElse: (Self) -> Self
	) -> Self {
		condition() ? modifyIf(self) : modifyElse(self)
	}
}

extension Font {
	/**
	Conditionally modify the font. For example, apply modifiers.

	```
	Text("Foo")
		.font(
			Font.system(size: 10, weight: .regular)
				.if(someBool) {
					$0.monospacedDigit()
				}
		)
	```
	*/
	func `if`(
		_ condition: @autoclosure () -> Bool,
		modify: (Self) -> Self
	) -> Self {
		condition() ? modify(self) : self
	}
}


extension Sequence where Element: Equatable {
	/**
	Returns a new sequence without the elements in the sequence that equals the given element.

	```
	[1, 2, 1, 2].removing(2)
	//=> [1, 1]
	```
	*/
	func removingAll(_ element: Element) -> [Element] {
		filter { $0 != element }
	}
}


extension Color {
	static let tertiary = Color(NSColor.tertiaryLabelColor)
	static let quaternary = Color(NSColor.quaternaryLabelColor)
}


extension View {
	func eraseToAnyView() -> AnyView {
		AnyView(self)
	}
}


extension View {
	// The closure unfortunately has to return `AnyView` as `some` cannot yet be used in return values in closures.
	/**
	Modify the view in a closure. This can be useful when you need to conditionally apply a modifier that is unavailable on certain platforms.

	For example, imagine this code needing to run on macOS too where `View#actionSheet()` is not available:

	```
	struct ContentView: View {
		var body: some View {
			Text("Unicorn")
				.modify {
					#if os(iOS)
					return $0.actionSheet(…).eraseToAnyView()
					#endif

					return nil
				}
		}
	}
	```

	```
	.modify {
		guard #available(macOS 11, iOS 14, *) else {
			return nil
		}

		return $0.keyboardShortcut("q")
			.eraseToAnyView()
	}
	```
	*/
	@ViewBuilder
	func modify(_ modifier: (Self) -> AnyView?) -> some View {
		if let view = modifier(self) {
			view
		} else {
			self
		}
	}

	/**
	- Important; You must always return `$0` in the else clause.

	```
	struct ContentView: View {
		var body: some View {
			Text("Unicorn")
				.modifyWithViewBuilder {
					#if os(iOS)
					$0.actionSheet(…)
					#else
					$0
					#endif
				}
		}
	}
	```

	```
	struct ContentView: View {
		var body: some View {
			Text("Unicorn")
				.modifyWithViewBuilder {
					if #available(macOS 11, *) {
						$0.toolbar {
							ToolbarItem(placement: .confirmationAction) {
								Button("Done") {
									presentationMode.wrappedValue.dismiss()
								}
							}
						}
					} else {
						$0
					}
				}
		}
	}
	```
	*/
	@inlinable
	func modifyWithViewBuilder<T: View>(@ViewBuilder modifier: (Self) -> T) -> T {
		modifier(self)
	}
}


private struct EmptyStateTextModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.title2)
			.foregroundColor(.tertiary)
	}
}

extension View {
	/**
	For empty states in the UI. For example, no items in a list, no search results, etc.
	*/
	func emptyStateTextStyle() -> some View {
		modifier(EmptyStateTextModifier())
	}
}


extension View {
	// Note: macOS 11.3 fixed support for multiple `.sheet`. Unclear, when it will be fixed for other methods though.

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		isPresented: Binding<Bool>,
		content: @escaping () -> Alert
	) -> some View {
		background(
			EmptyView().alert(
				isPresented: isPresented,
				content: content
			)
		)
	}

	/**
	This allows multiple popovers on a single view, which `.popover()` doesn't.
	*/
	func popover2<Content: View>(
		isPresented: Binding<Bool>,
		attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
		arrowEdge: Edge = .top,
		@ViewBuilder content: @escaping () -> Content
	) -> some View {
		background(
			EmptyView().popover(
				isPresented: isPresented,
				attachmentAnchor: attachmentAnchor,
				arrowEdge: arrowEdge,
				content: content
			)
		)
	}
}


struct IdentifiableIndices<Base: RandomAccessCollection> where Base.Element: Identifiable {
	typealias Index = Base.Index

	struct Element: Identifiable {
		let id: Base.Element.ID
		let rawValue: Index
	}

	fileprivate var base: Base
}

extension IdentifiableIndices: RandomAccessCollection {
	var startIndex: Index { base.startIndex }
	var endIndex: Index { base.endIndex }

	subscript(position: Index) -> Element {
	Element(id: base[position].id, rawValue: position)
}

	func index(before index: Index) -> Index {
		base.index(before: index)
	}

	func index(after index: Index) -> Index {
		base.index(after: index)
	}
}

extension RandomAccessCollection where Element: Identifiable {
	var identifiableIndices: IdentifiableIndices<Self> {
		IdentifiableIndices(base: self)
	}
}

// TODO: Remove this and the above when targeting macOS 12.
extension ForEach where ID == Data.Element.ID, Data.Element: Identifiable, Content: View {
	init<T>(
		_ data: Binding<T>,
		@ViewBuilder content: @escaping (T.Index, Binding<T.Element>) -> Content
	) where Data == IdentifiableIndices<T>, T: MutableCollection {
		self.init(data.wrappedValue.identifiableIndices) { index in
			content(
				index.rawValue,
				Binding(
					get: { data.wrappedValue[index.rawValue] },
					set: {
						data.wrappedValue[index.rawValue] = $0
					}
				)
			)
		}
	}
}


extension Sequence where Element: Equatable {
	/**
	Returns a new sequence with the elements in the sequence that equals the given element replaced by the element in the `with` parameter.

	```
	[1, 2, 1, 2].replacingAll(2, with: 3)
	//=> [1, 3, 1, 3]
	```
	*/
	func replacingAll(_ element: Element, with newElement: Element) -> [Element] {
		map { $0 == element ? newElement : $0 }
	}
}


extension Collection {
	/**
	Copies the collection and moves all the elements at the specified offsets to the specified destination offset, preserving ordering.
	*/
	func moving(fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
		var copy = Array(self)
		copy.move(fromOffsets: source, toOffset: destination)
		return copy
	}
}

extension RangeReplaceableCollection {
	/**
	Copies the collection and removes all the elements at the specified offsets from the collection.
	*/
	func removing(atOffsets offsets: IndexSet) -> [Element] {
		var copy = Array(self)
		copy.remove(atOffsets: offsets)
		return copy
	}
}


extension NSImage: NSItemProviderReading {
	public static var readableTypeIdentifiersForItemProvider: [String] {
		NSImage.imageTypes
	}

	public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
		guard let image = self.init(data: data) else {
			throw NSError.appError("Unsupported or invalid image")
		}

		return image
	}
}

extension NSImage: NSItemProviderWriting {
	public static var writableTypeIdentifiersForItemProvider: [String] {
		[UTType.tiff.identifier]
	}

	public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
		guard let data = tiffRepresentation else {
			completionHandler(nil, NSError.appError("Could not convert image to data"))
			return nil
		}

		completionHandler(data, nil)
		return nil
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
}


extension NSItemProvider {
	func getImage() async -> NSImage? {
		try? await loadObject(ofClass: NSImage.self)
	}
}


// Strongly-typed versions of some of the methods.
extension NSItemProvider {
	func hasItemConformingTo(_ contentType: UTType) -> Bool {
		hasItemConformingToTypeIdentifier(contentType.identifier)
	}

	func loadItem(
		forType contentType: UTType,
		options: [AnyHashable: Any]? = nil // swiftlint:disable:this discouraged_optional_collection
	) async throws -> NSSecureCoding {
		try await loadItem(
			forTypeIdentifier: contentType.identifier,
			options: options
		)
	}
}


/**
```
let x = ["a", "", "b"].filter(!\.isEmpty)

print(x)
//=> ["a", "b"]
```
*/
prefix func ! <Root>(rhs: KeyPath<Root, Bool>) -> (Root) -> Bool { // swiftlint:disable:this static_operator
	{ !$0[keyPath: rhs] }
}


extension String {
	/**
	Get the string as UTF-8 data.
	*/
	var data: Data { Data(utf8) }
}

extension Data {
	var string: String? { String(data: self, encoding: .utf8) }
}


extension Data {
	struct HexEncodingOptions: OptionSet {
		let rawValue: Int
		static let upperCase = Self(rawValue: 1 << 0)
	}

	func hexEncodedString(options: HexEncodingOptions = []) -> String {
		let hexDigits = options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef"
		let utf8Digits = Array(hexDigits.utf8)

		return String(unsafeUninitializedCapacity: count * 2) { pointer -> Int in
			var string = pointer.baseAddress!

			for byte in self {
				string[0] = utf8Digits[Int(byte / 16)]
				string[1] = utf8Digits[Int(byte % 16)]
				string += 2
			}

			return count * 2
		}
	}
}


extension Data {
	func sha256() -> Self {
		Data(SHA256.hash(data: self))
	}

	func sha512() -> Self {
		Data(SHA512.hash(data: self))
	}
}

extension String {
	/**
	```
	"foo".sha256()
	//=> "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"
	```
	*/
	func sha256() -> Self {
		data.sha256().hexEncodedString()
	}

	func sha512() -> Self {
		data.sha512().hexEncodedString()
	}
}


/**
Wrapper around `NSCache` that enables using any hashable key and any value.
*/
final class Cache<Key: Hashable, Value> {
	private final class WrappedKey: NSObject {
		let key: Key

		init(key: Key) {
			self.key = key
		}

		override var hash: Int { key.hashValue }

		override func isEqual(_ object: Any?) -> Bool {
			guard let value = object as? WrappedKey else {
				return false
			}

			return value.key == key
		}
	}

	private final class WrappedValue {
		let value: Value

		init(value: Value) {
			self.value = value
		}
	}

	private let cache = NSCache<WrappedKey, WrappedValue>()

	/**
	Get, set, or remove an entry from the cache.
	*/
	subscript(key: Key) -> Value? {
		get { cache.object(forKey: .init(key: key))?.value }
		set {
			guard let value = newValue else {
				// If the value is `nil`, remove the entry from the cache.
				cache.removeObject(forKey: .init(key: key))

				return
			}

			cache.setObject(.init(value: value), forKey: .init(key: key))
		}
	}

	/**
	Removes all entries.
	*/
	func removeAll() {
		cache.removeAllObjects()
	}
}


protocol SimpleImageCacheKeyable: Hashable {
	var cacheKey: String { get }
}

extension String: SimpleImageCacheKeyable {
	var cacheKey: String { self }
}

extension URL: SimpleImageCacheKeyable {
	var cacheKey: String { absoluteString }
}

// TODO: Rewrite as an actor.
/**
Extremely simple and naive image cache.

The cache is thread-safe.

You can optionally persist the cache to disk. Reading from the cache is synchronous. Saving to the cache happens asynchronously in a background thread.
*/
final class SimpleImageCache<Key: SimpleImageCacheKeyable> {
	private let lock = NSLock()
	private let diskQueue = DispatchQueue(label: "SimpleImageCache")
	private let cache = Cache<Key, NSImage>()
	private var cacheDirectory: URL?

	private var shouldUseDisk: Bool { cacheDirectory != nil }

	/**
	- Parameter diskCacheName: If you want to cache to disk, pass a name. The name should be a valid directory name.
	*/
	init(diskCacheName: String? = nil) {
		if let diskCacheName = diskCacheName {
			do {
				self.cacheDirectory = try createCacheDirectory(name: diskCacheName)
			} catch {
				assertionFailure("Failed to create cache directory: \(error)")
			}
		}
	}

	private func createCacheDirectory(name: String) throws -> URL {
		let rootCacheDirectory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

		let cacheDirectory = rootCacheDirectory
			.appendingPathComponent(SSApp.name, isDirectory: true)
			.appendingPathComponent(name, isDirectory: true)

		try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

		return cacheDirectory
	}

	private func createCacheDirectoryIfNeeded() {
		guard let cacheDirectory = cacheDirectory else {
			return
		}

		try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
	}

	private func cacheFileFromKey(_ key: Key) -> URL? {
		cacheDirectory?.appendingPathComponent(key.cacheKey.sha256(), isDirectory: false)
	}

	private func loadImageFromDiskIfNeeded(for key: Key) -> NSImage? {
		guard
			shouldUseDisk,
			let cacheFile = cacheFileFromKey(key)
		else {
			return nil
		}

		return NSImage(contentsOf: cacheFile)
	}

	private func saveImageToDiskIfNeeded(_ image: NSImage, for key: Key) {
		guard
			shouldUseDisk,
			let cacheFile = cacheFileFromKey(key)
		else {
			return
		}

		diskQueue.async { [weak self] in
			guard let self = self else {
				return
			}

			guard let tiffData = image.tiffRepresentation else {
				assertionFailure("Could not get TIFF representation from image.")
				return
			}

			// Ensure the cache directory exists in case it was removed by `.removeAllImages()` or the user.
			self.createCacheDirectoryIfNeeded()

			do {
				try tiffData.write(to: cacheFile)
			} catch {
				assertionFailure("Failed to write image to disk: \(error.localizedDescription)")
			}
		}
	}

	private func removeImageFromDiskIfNeeded(for key: Key) {
		guard
			shouldUseDisk,
			let cacheFile = cacheFileFromKey(key)
		else {
			return
		}

		diskQueue.async {
			try? FileManager.default.removeItem(at: cacheFile)
		}
	}

	private func removeAllImagesFromDiskIfNeeded() {
		guard
			shouldUseDisk,
			let cacheDirectory = cacheDirectory
		else {
			return
		}

		diskQueue.async {
			try? FileManager.default.removeItem(at: cacheDirectory)
		}
	}

	/**
	Get the image for the given key.
	*/
	private func image(for key: Key) -> NSImage? {
		lock.lock()
		defer {
			lock.unlock()
		}

		guard let image = cache[key] else {
			guard let image = loadImageFromDiskIfNeeded(for: key) else {
				return nil
			}

			cache[key] = image

			return image
		}

		return image
	}

	/**
	Insert an image into the cache for the given key.
	*/
	private func insertImage(_ image: NSImage?, for key: Key) {
		guard let image = image else {
			removeImage(for: key)
			return
		}

		lock.lock()
		defer {
			lock.unlock()
		}

		cache[key] = image
		saveImageToDiskIfNeeded(image, for: key)
	}

	/**
	Remove an image from the cache for the given key.
	*/
	private func removeImage(for key: Key) {
		lock.lock()
		defer {
			lock.unlock()
		}

		cache[key] = nil
		removeImageFromDiskIfNeeded(for: key)
	}

	/**
	If the cache items exists on disk but not in the memory cache, this adds it them the memory cache too.

	This is run in a background thread.
	*/
	func prewarmCacheFromDisk(for keys: [Key]) {
		DispatchQueue.global().async { [self] in
			for key in keys {
				_ = image(for: key)
			}
		}
	}

	/**
	Remove all images from the cache.
	*/
	func removeAllImages() {
		lock.lock()
		defer {
			lock.unlock()
		}

		cache.removeAll()
		removeAllImagesFromDiskIfNeeded()
	}

	/**
	Get, set, or remove an image from the cache.
	*/
	subscript(_ key: Key) -> NSImage? {
		get { image(for: key) }
		set {
			guard let value = newValue else {
				removeImage(for: key)
				return
			}

			insertImage(value, for: key)
		}
	}
}


extension Collection where Element: Equatable {
	/**
	Returns an array where each element in the collection equal to the given `target` element is modified.

	```
	struct Person: Equatable {
		var name: String
	}

	var people = [
		Person(name: "John"),
		Person(name: "Daniel"),
		Person(name: "John")
	]

	// …

	let personToRename = Person(name: "John")

	people = people.modifying(personToRename) {
		$0.name = "Johnny"
	}

	print(people)
	//=> [{name "Johnny"}, {name "Daniel"}, {name "Johnny"}]
	```
	*/
	func modifying(
		_ target: Element,
		update: (inout Element) throws -> Void
	) rethrows -> [Element] {
		try map { element -> Element in
			guard element == target else {
				return element
			}

			var copy = element
			try update(&copy)
			return copy
		}
	}
}

extension Collection where Element: Identifiable {
	/**
	Returns an array where each element's ID in the collection equal to the given ID is modified.

	```
	struct Person: Identifiable {
		let id = UUID()
		var name: String
	}

	var people = [
		Person(name: "John"),
		Person(name: "Daniel"),
		Person(name: "John")
	]

	// …

	let personToRename = people[0]

	people = people.modifying(elementWithID: personToRename.id) {
		$0.name = "Johnny"
	}

	print(people)
	//=> [{name "Johnny"}, {name "Daniel"}, {name "Johnny"}]
	```
	*/
	func modifying(
		elementWithID id: Element.ID,
		update: (inout Element) throws -> Void
	) rethrows -> [Element] {
		try map { element -> Element in
			guard element.id == id else {
				return element
			}

			var copy = element
			try update(&copy)
			return copy
		}
	}
}

extension Collection {
	/**
	Returns an array where each element in the collection are modified.

	```
	people = people.modifying {
		$0.isCurrent = false
	}
	```
	*/
	func modifying(
		modify: (inout Element) throws -> Void
	) rethrows -> [Element] {
		try map {
			var copy = $0
			try modify(&copy)
			return copy
		}
	}
}


extension Collection where Element: Equatable {
	/**
	Get the element before the first element equaling the given element.

	```
	let x = [1, 2, 3]
	x.element(before: 2)
	//=> 1
	```
	*/
	func element(before element: Element) -> Element? {
		guard
			let elementIndex = firstIndex(of: element),
			let targetIndex = index(elementIndex, offsetBy: -1, limitedBy: startIndex)
		else {
			return nil
		}

		return self[targetIndex]
	}

	/**
	Get the element after the first element equaling the given element.

	```
	let x = [1, 2, 3]
	x.element(after: 2)
	//=> 3
	```
	*/
	func element(after element: Element) -> Element? {
		guard
			let elementIndex = firstIndex(of: element),
			let targetIndex = index(elementIndex, offsetBy: 1, limitedBy: index(endIndex, offsetBy: -1))
		else {
			return nil
		}

		return self[targetIndex]
	}
}

extension BidirectionalCollection where Element: Equatable {
	/**
	Get the element before the first element equaling the given element, or the last element if there's no element before or if the given element is `nil`

	This can be useful when imitating a circular array.
	*/
	func elementBeforeOrLast(_ element: Element?) -> Element? {
		guard
			let element = element,
			let previousElement = self.element(before: element)
		else {
			return last
		}

		return previousElement
	}
}

extension Collection where Element: Equatable {
	/**
	Get the element after the first element equaling the given element, or the first element if there's no element after or if the given element is `nil`

	This can be useful when imitating a circular array.
	*/
	func elementAfterOrFirst(_ element: Element?) -> Element? {
		guard
			let element = element,
			let nextElement = self.element(after: element)
		else {
			return first
		}

		return nextElement
	}
}


extension NSMenuItem {
	/**
	The menu is only created when it's enabled.

	```
	menu.addItem("Foo")
		.withSubmenu(createCalendarEventMenu(with: event))
	```
	*/
	@discardableResult
	func withSubmenu(_ menu: @autoclosure () -> NSMenu) -> Self {
		submenu = isEnabled ? menu() : NSMenu()
		return self
	}

	/**
	The menu is only created when it's enabled.

	```
	menu
		.addItem("Foo")
		.withSubmenu { menu in

		}
	```
	*/
	@discardableResult
	func withSubmenu(_ menuBuilder: (SSMenu) -> NSMenu) -> Self {
		withSubmenu(menuBuilder(SSMenu()))
	}
}


enum OperatingSystem {
	case macOS
	case iOS
	case tvOS
	case watchOS

	#if os(macOS)
	static let current = macOS
	#elseif os(iOS)
	static let current = iOS
	#elseif os(tvOS)
	static let current = tvOS
	#elseif os(watchOS)
	static let current = watchOS
	#else
	#error("Unsupported platform")
	#endif
}

extension OperatingSystem {
	/**
	- Note: Only use this when you cannot use an `if #available` check. For example, inline in function calls.
	*/
	static let isMacOS13OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 13, *) {
			return true
		} else {
			return false
		}
		#else
		return false
		#endif
	}()

	/**
	- Note: Only use this when you cannot use an `if #available` check. For example, inline in function calls.
	*/
	static let isMacOS12OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 12, *) {
			return true
		} else {
			return false
		}
		#else
		return false
		#endif
	}()
}

typealias OS = OperatingSystem


extension View {
	@ViewBuilder
	func ifLet<Value, TrueContent: View>(
		_ value: Value?,
		modifier: (Self, Value) -> TrueContent
	) -> some View {
		if let value = value {
			modifier(self, value)
		} else {
			self
		}
	}
}


/**
Circular button with question mark that shows a popover with the given content when tapped.

The content has automatic padding.
*/
struct InfoPopoverButton<Content: View>: View {
	@State private var isPopoverPresented = false

	var maxWidth: Double?
	@ViewBuilder let content: Content

	var body: some View {
		CocoaButton("", bezelStyle: .helpButton) {
			isPopoverPresented = true
		}
			.popover(isPresented: $isPopoverPresented) {
				content
					.controlSize(.regular) // Setting control size on the button should not affect the content.
					.padding()
					.multilineText()
					.ifLet(maxWidth) {
						// TODO: `maxWidth` doesn't work. Causes the popover to me infinite height. (macOS 11.2.3)
						$0.frame(width: $1)
					}
			}
	}
}

extension InfoPopoverButton where Content == Text {
	init<S>(_ text: S, maxWidth: Double = 240) where S: StringProtocol {
		self.content = Text(text)
		self.maxWidth = maxWidth
	}
}


extension CGSize {
	/**
	Create a CGSize from string dimensions in the format `100x100`.
	*/
	static func from(dimensions: String) -> Self? {
		let parts = dimensions.split(separator: "x").compactMap { Int($0) }

		guard parts.count == 2 else {
			return nil
		}

		return self.init(width: parts[0], height: parts[1])
	}
}


@available(macOS, obsoleted: 12)
extension URLSession {
	func data(from url: URL) async throws -> (Data, URLResponse) {
		try await withCheckedThrowingContinuation { continuation in
			let task = self.dataTask(with: url) { data, response, error in
				guard let data = data, let response = response else {
					let error = error ?? URLError(.badServerResponse)
					return continuation.resume(throwing: error)
				}

				continuation.resume(returning: (data, response))
			}

			task.resume()
		}
	}
}


// TODO: Make it an actor.
// TODO: Ensure it still works well. Try disabling the LinkPresentation API and caching.
/*
TODO when Swift 5.5 is out:
- Support more ways to get the icon: https://stackoverflow.com/a/22007642/64949
- Get all icons concurrently.
- Recreate the webview for each request.
- Use only a single `evaluateJavaScript` call.
- Run on DOM-ready instad of when the whole page has loaded.
	- If not possible, block all subresources: https://stackoverflow.com/questions/32119975/how-to-block-external-resources-to-load-on-a-wkwebview
- Make the thumbnail in WebsitesView not upscale when using 32x32 favicon.
- Support specifying target size and have it return the one closest above the target size, if any.
- Use the icons in the "Switch" menu.
*/
@MainActor
final class WebsiteIconFetcher: NSObject {
	private struct WebAppManifestIcon {
		let url: URL
		let size: CGSize?

		init?(_ dictionary: [String: String]) {
			guard
				// TODO: Handle relative URLs: https://developer.mozilla.org/en-US/docs/Web/Manifest/icons
				let urlString = dictionary["src"],
				let url = URL(string: urlString)
			else {
				return nil
			}

			self.url = url

			// TODO: Handle there being multiple space-separated sizes.
			if
				let sizeString = dictionary["sizes"]?.split(separator: " ").first,
				let size = CGSize.from(dimensions: String(sizeString))
			{
				self.size = size
			} else {
				self.size = nil
			}
		}
	}

	@MainActor
	static func fetch(for url: URL) async throws -> NSImage? {
		try await self.init().fetch(for: url)
	}

	@MainActor
	private lazy var webView: WKWebView = {
		let configuration = WKWebViewConfiguration()

		let userContentController = WKUserContentController()
		configuration.userContentController = userContentController

		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		configuration.preferences = preferences

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		webView.customUserAgent = SSWebView.safariUserAgent

		return webView
	}()

	private var url: URL?
	private var continuation: CheckedContinuation<Void, Error>?
	private var isLoaded = false

	private func getImage(_ url: URL) async throws -> NSImage? {
		let (data, _) = try await URLSession.shared.data(from: url)
		return NSImage(data: data)
	}

	private func getFavicon() async throws -> NSImage? {
		guard
			let faviconURL = URL(string: "favicon.ico", relativeTo: url)
		else {
			return nil
		}

		return try await getImage(faviconURL)
	}

	private func getFromLPMetadataProvider(url: URL) async throws -> NSImage? {
		let metadata = try await LPMetadataProvider().startFetchingMetadata(for: url)

		guard
			let iconProvider = metadata.iconProvider,
			iconProvider.hasItemConformingTo(.image)
		else {
			return nil
		}

		return await iconProvider.getImage()
	}

	@MainActor
	private func getFromManifest() async throws -> NSImage? {
		let code =
			"""
			document.querySelector('link[rel="manifest"]').href
			"""

		let result = try await webView.evaluateJavaScript(code)

		// TODO: When targeting macOS 12:
		// let result = try await webView.evaluateJavaScript(code, in: nil, in: .defaultClient)

		guard
			let urlString = result as? String,
			let url = URL(string: urlString)
		else {
			return nil
		}

		let (data, _) = try await URLSession.shared.data(from: url)

		guard
			let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
			let icons = json["icons"] as? [[String: String]]
		else {
			return nil
		}

		let iconStructs = icons.compactMap { WebAppManifestIcon($0) }

		// TODO: Instead of picking the largest one, we should download all and add them as representations to a single `NSImage`.
		guard
			let largestIcon = (iconStructs.max { ($0.size?.width ?? 0) < ($1.size?.width ?? 0) })
		else {
			return nil
		}

		return try await getImage(largestIcon.url)
	}

	@MainActor
	private func getFromLinkIcon() async throws -> NSImage? {
		// TODO: There can be multiple of this one, some with larger sizes specified in a `sizes` prop.
		// The `~` is because of the `shortcut` link type, which is often seen before icon, but this link type is non-conforming, ignored and web authors must not use it anymore: https://developer.mozilla.org/en-US/docs/Web/HTML/Link_types
		let code =
			"""
			document.querySelector('link[rel~="icon"]').href
			"""

		let result = try await webView.evaluateJavaScript(code)

		// TODO: When targeting macOS 12:
		// let result = try await webView.evaluateJavaScript(code, in: nil, in: .defaultClient)

		guard
			let urlString = result as? String,
			let url = URL(string: urlString)
		else {
			return nil
		}

		return try await getImage(url)
	}

	@MainActor
	private func getFromMetaItemPropImage() async throws -> NSImage? {
		let code =
			"""
			new URL(document.querySelector('meta[itemprop="image"]').content, document.baseURI).toString()
			"""

		let result = try await webView.evaluateJavaScript(code)

		// TODO: When targeting macOS 12:
		// let result = try await webView.evaluateJavaScript(code, in: nil, in: .defaultClient)

		guard
			let urlString = result as? String,
			let url = URL(string: urlString)
		else {
			return nil
		}

		return try await getImage(url)
	}

	@MainActor
	private func fetch(for url: URL) async throws -> NSImage? {
		self.url = url

		var request = URLRequest(url: url)
		request.cachePolicy = .reloadIgnoringLocalCacheData

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.continuation = continuation
			webView.load(request)
		}

		// TODO: Use `??` for all of these when `??` supports await.

		if let image = try? await getFromLPMetadataProvider(url: url) {
			return image
		}

		if let image = try? await getFromManifest() {
			return image
		}

		if let image = try? await getFromMetaItemPropImage() {
			return image
		}

		if let image = try? await getFromLinkIcon() {
			return image
		}

		if let image = try? await getFavicon() {
			return image
		}

		return nil
	}
}

extension WebsiteIconFetcher: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
		navigationResponse.isForMainFrame ? .allow : .cancel
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// For some reason, this is sometimes called more than once. We have to guard against that as `.resume()` can only be called once. (macOS 11.5)
		guard !isLoaded else {
			return
		}

		continuation?.resume()
		isLoaded = true
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
	}
}


extension View {
	/**
	Corner radius with a custom corner style.
	*/
	func cornerRadius(_ radius: Double, style: RoundedCornerStyle) -> some View {
		clipShape(.roundedRectangle(cornerRadius: radius, style: style))
	}

	/**
	Draws a border inside the view.
	*/
	@_disfavoredOverload
	func border<S: ShapeStyle>(
		_ content: S,
		width lineWidth: Double = 1,
		cornerRadius: Double,
		cornerStyle: RoundedCornerStyle = .circular
	) -> some View {
		self.cornerRadius(cornerRadius, style: cornerStyle)
			.overlay2 {
				RoundedRectangle(cornerRadius: cornerRadius, style: cornerStyle)
					.strokeBorder(content, lineWidth: lineWidth)
			}
	}

	/**
	Draws a border inside the view.
	*/
	func border(
		_ color: Color,
		width lineWidth: Double = 1,
		cornerRadius: Double,
		cornerStyle: RoundedCornerStyle = .circular
	) -> some View {
		self.cornerRadius(cornerRadius, style: cornerStyle)
			.overlay2 {
				RoundedRectangle(cornerRadius: cornerRadius, style: cornerStyle)
					.strokeBorder(color, lineWidth: lineWidth)
			}
	}
}


extension Numeric {
	mutating func increment(by value: Self = 1) -> Self {
		self += value
		return self
	}

	mutating func decrement(by value: Self = 1) -> Self {
		self -= value
		return self
	}

	func incremented(by value: Self = 1) -> Self {
		self + value
	}

	func decremented(by value: Self = 1) -> Self {
		self - value
	}
}


extension SSApp {
	private static let key = Defaults.Key("SSApp_requestReview", default: 0)

	/**
	Requests a review only after this method has been called the given amount of times.
	*/
	static func requestReviewAfterBeingCalledThisManyTimes(_ counts: [Int]) {
		guard
			!SSApp.isFirstLaunch,
			counts.contains(Defaults[key].increment())
		else {
			return
		}

		SKStoreReviewController.requestReview()
	}
}


enum DecodableDefault {}

protocol DecodableDefaultSource {
	associatedtype Value: Decodable
	static var defaultValue: Value { get }
}

extension DecodableDefault {
	@propertyWrapper
	struct Wrapper<Source: DecodableDefaultSource> {
		typealias Value = Source.Value
		var wrappedValue = Source.defaultValue
	}
}

extension DecodableDefault.Wrapper: Decodable {
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		wrappedValue = try container.decode(Value.self)
	}
}

extension KeyedDecodingContainer {
	func decode<T>(
		_ type: DecodableDefault.Wrapper<T>.Type,
		forKey key: Key
	) throws -> DecodableDefault.Wrapper<T> {
		try decodeIfPresent(type, forKey: key) ?? .init()
	}
}

extension DecodableDefault {
	typealias Source = DecodableDefaultSource
	typealias List = Decodable & ExpressibleByArrayLiteral
	typealias Map = Decodable & ExpressibleByDictionaryLiteral
	typealias Number = Decodable & AdditiveArithmetic

	enum Sources {
		enum True: Source {
			static let defaultValue = true
		}

		enum False: Source {
			static let defaultValue = false
		}

		enum EmptyString: Source {
			static var defaultValue = ""
		}

		enum EmptyList<T: List>: Source {
			static var defaultValue: T { [] }
		}

		enum EmptyMap<T: Map>: Source {
			static var defaultValue: T { [:] }
		}

		enum Zero<T: Number>: Source {
			static var defaultValue: T { .zero }
		}

		enum One: Source {
			static var defaultValue = 1
		}
	}
}

extension DecodableDefault {
	typealias True = Wrapper<Sources.True>
	typealias False = Wrapper<Sources.False>
	typealias EmptyString = Wrapper<Sources.EmptyString>
	typealias EmptyList<T: List> = Wrapper<Sources.EmptyList<T>>
	typealias EmptyMap<T: Map> = Wrapper<Sources.EmptyMap<T>>
	typealias Zero<T: Number> = Wrapper<Sources.Zero<T>>
	typealias One = Wrapper<Sources.One>

	typealias Custom = Wrapper // Just for readability.
}

extension DecodableDefault.Wrapper: Equatable where Value: Equatable {}
extension DecodableDefault.Wrapper: Hashable where Value: Hashable {}

extension DecodableDefault.Wrapper: Identifiable where Value: Identifiable {
	var id: Value.ID { wrappedValue.id }
}

extension DecodableDefault.Wrapper: Encodable where Value: Encodable {
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(wrappedValue)
	}
}


extension View {
	/**
	Make the view subscribe to the given notification.
	*/
	func onNotification(
		_ name: Notification.Name,
		object: AnyObject? = nil,
		perform action: @escaping (Notification) -> Void
	) -> some View {
		onReceive(NotificationCenter.default.publisher(for: name, object: object)) {
			action($0)
		}
	}
}


/**
A helper that converts a binding to a collection of elements into a collection of bindings to the individual elements.
*/
struct BindingCollection<Base: MutableCollection & RandomAccessCollection>: RandomAccessCollection {
	let base: Binding<Base>

	typealias Element = Binding<Base.Element>
	typealias Index = Base.Index

	var startIndex: Index { base.wrappedValue.startIndex }
	var endIndex: Index { base.wrappedValue.endIndex }

	subscript(position: Base.Index) -> Binding<Base.Element> {
		Binding(
			get: { base.wrappedValue[position] },
			set: {
				var result = base.wrappedValue
				result[position] = $0
				base.wrappedValue = result
			}
		)
	}

	func index(before index: Base.Index) -> Base.Index {
		base.wrappedValue.index(before: index)
	}

	func index(after index: Base.Index) -> Base.Index {
		base.wrappedValue.index(after: index)
	}
}

extension BindingCollection where Base.Element: Identifiable {
	/**
	Get the element with the given `ID` in a collection of `Identifible` elements.

	It assumes there are no duplicates and it will just get the first matching element.
	*/
	subscript(id id: Base.Element.ID) -> Binding<Base.Element>? {
		first { $0.wrappedValue.id == id }
	}
}


extension Collection where Element: Identifiable {
	/**
	Get the element with the given `ID` in a collection of `Identifible` elements.

	It assumes there are no duplicates and it will just get the first matching element.
	*/
	subscript(id id: Element.ID) -> Element? {
		first { $0.id == id }
	}
}


extension Defaults {
	/**
	Get a `Binding` for a `Defaults` key.
	*/
	static func binding<Value: Codable>(for key: Key<Value>) -> Binding<Value> {
		.init(
			get: { self[key] },
			set: {
				self[key] = $0
			}
		)
	}
}

extension Defaults {
	/**
	Get a `BindingCollection` for a `Defaults` key.
	*/
	static func bindingCollection<Value: Codable>(for key: Key<Value>) -> BindingCollection<Value> where Value: MutableCollection & RandomAccessCollection {
		.init(base: binding(for: key))
	}
}


private struct OnChangeDebouncedViewModifier<Value: Equatable>: ViewModifier {
	@State private var subject = PassthroughSubject<Void, Never>()

	let value: Value
	let dueTime: TimeInterval
	let initial: Bool
	let action: (Value) -> Void

	func body(content: Content) -> some View {
		if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
			content
				.onChange(of: value) { _ in
					subject.send()
				}
				.task {
					if initial {
						subject.send()
					}

					let changes = subject
						.debounce(for: .seconds(dueTime), scheduler: DispatchQueue.main)
						.receive(on: DispatchQueue.main)
						.values

					for await _ in changes {
						action(value)
					}
				}
		} else {
			content
				.onChange(of: value) { _ in
					subject.send()
				}
				.onReceive(
					subject
						.debounce(for: .seconds(dueTime), scheduler: DispatchQueue.main)
						.receive(on: DispatchQueue.main)
				) { _ in
					action(value)
				}
				.onAppear {
					if initial {
						subject.send()
					}
				}
		}
	}
}

extension View {
	/**
	`.onChange` version that debounces the value changes.

	It also allows triggering initially (on appear) too, not just on change.
	*/
	func onChangeDebounced<Value: Equatable>(
		of value: Value,
		dueTime: TimeInterval,
		initial: Bool = false,
		perform action: @escaping (Value) -> Void
	) -> some View {
		modifier(
			OnChangeDebouncedViewModifier(
				value: value,
				dueTime: dueTime,
				initial: initial,
				action: action
			)
		)
	}
}


extension Publisher {
	/**
	Convert a publisher to a `Result`.
	*/
	func convertToResult() -> AnyPublisher<Result<Output, Failure>, Never> {
		map(Result.success)
			.catch { Just(.failure($0)) }
			.eraseToAnyPublisher()
	}
}


private struct WindowAccessor: NSViewRepresentable {
	private final class WindowAccessorView: NSView {
		@Binding var windowBinding: NSWindow?

		init(binding: Binding<NSWindow?>) {
			self._windowBinding = binding
			super.init(frame: .zero)
		}

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			windowBinding = window
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError() // swiftlint:disable:this fatal_error_message
		}
	}

	@Binding var window: NSWindow?

	init(_ window: Binding<NSWindow?>) {
		self._window = window
	}

	func makeNSView(context: Context) -> NSView {
		WindowAccessorView(binding: $window)
	}

	func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
	/**
	Bind the native backing-window of a SwiftUI window to a property.
	*/
	func bindNativeWindow(_ window: Binding<NSWindow?>) -> some View {
		background(WindowAccessor(window))
	}
}

private struct WindowViewModifier: ViewModifier {
	@State private var window: NSWindow?

	let onWindow: (NSWindow?) -> Void

	func body(content: Content) -> some View {
		onWindow(window)

		return content
			.bindNativeWindow($window)
	}
}

extension View {
	/**
	Access the native backing-window of a SwiftUI window.
	*/
	func accessNativeWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
		modifier(WindowViewModifier(onWindow: onWindow))
	}

	/**
	Set the window level of a SwiftUI window.
	*/
	func windowLevel(_ level: NSWindow.Level) -> some View {
		accessNativeWindow {
			$0?.level = level
		}
	}
}


enum SettingsTabType {
	case general
	case advanced
	case shortcuts

	fileprivate var label: some View {
		switch self {
		case .general:
			return Label("General", systemImage: "gearshape")
		case .advanced:
			return Label("Advanced", systemImage: "gearshape.2")
		case .shortcuts:
			return Label("Shortcuts", systemImage: "command")
		}
	}
}

extension View {
	/**
	Make the view a settings tab of the given type.
	*/
	func settingsTabItem(_ type: SettingsTabType) -> some View {
		tabItem { type.label }
	}
}


/**
- Important: The `font` option have no effect...

- Note: It respects `View#controlSize` if `roundedStyle: true`. Not without. (macOS 11.3)
*/
struct NativeTextField: NSViewRepresentable {
	typealias NSViewType = NSTextField

	@Binding var text: String
	var placeholder: String?
	var font: NSFont?
	var isFirstResponder = false
	var roundedStyle = false
	var isSingleLine = true

	final class Coordinator: NSObject, NSTextFieldDelegate {
		var parent: NativeTextField
		var didBecomeFirstResponder = false

		init(_ autoFocusTextField: NativeTextField) {
			self.parent = autoFocusTextField
		}

		func controlTextDidChange(_ notification: Notification) {
			parent.text = (notification.object as? NSTextField)?.stringValue ?? ""
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let nsView = NSTextField()
		nsView.delegate = context.coordinator

		// This makes it scroll horizontally when text overflows instead of moving to a new line.
		if isSingleLine {
			nsView.cell?.usesSingleLineMode = true
			nsView.cell?.wraps = false
			nsView.cell?.isScrollable = true
			nsView.maximumNumberOfLines = 1
		}

		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.stringValue = text
		nsView.placeholderString = placeholder

		if let font = font {
			nsView.font = font
		}

		if roundedStyle {
			nsView.bezelStyle = .roundedBezel
		}

		// Note: Does not work without the dispatch call.
		DispatchQueue.main.async {
			if
				isFirstResponder,
				!context.coordinator.didBecomeFirstResponder,
				let window = nsView.window,
				window.firstResponder != nsView
			{
				window.makeFirstResponder(nsView)
				context.coordinator.didBecomeFirstResponder = true
			}
		}
	}
}


extension Notification.Name {
	/**
	Must be used with `DistributedNotificationCenter`.
	*/
	static let screenIsLocked = Self("com.apple.screenIsLocked")

	/**
	Must be used with `DistributedNotificationCenter`.
	*/
	static let screenIsUnlocked = Self("com.apple.screenIsUnlocked")
}


enum SSPublishers {
	/**
	Publishes when the machine wakes from sleep.
	*/
	static let deviceDidWake = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
		.map { _ in }
		.eraseToAnyPublisher()

	/**
	Publishes when the configuration of the displays attached to the computer is changed.

	The configuration change can be made either programmatically or when the user changes settings in the Displays control panel.
	*/
	static let screenParametersDidChange = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
		.map { _ in }
		.eraseToAnyPublisher()

	/**
	Publishes when the screen becomes locked/unlocked.
	*/
	static let isScreenLocked = Publishers.Merge(
		DistributedNotificationCenter.default().publisher(for: .screenIsLocked).map { _ in true },
		DistributedNotificationCenter.default().publisher(for: .screenIsUnlocked).map { _ in false }
	)
		.eraseToAnyPublisher()
}


extension SSPublishers {
	private struct AppOpenURLPublisher: Publisher {
		// We need this abstraction as `kAEGetURL` can only be subscribed to once.
		private final class EventManager {
			typealias Handler = (URLComponents) -> Void

			static let shared = EventManager()

			private var handlers = [UUID: Handler]()

			@objc
			private func handleEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
				guard
					let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
					let urlComponents = URLComponents(string: urlString)
				else {
					return
				}

				for handler in handlers.values {
					handler(urlComponents)
				}
			}

			func add(_ handler: @escaping Handler) -> UUID {
				if handlers.isEmpty {
					NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleEvent(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
				}

				let id = UUID()
				handlers[id] = handler
				return id
			}

			func remove(_ id: UUID) {
				handlers[id] = nil

				if handlers.isEmpty {
					NSAppleEventManager.shared().removeEventHandler(forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
				}
			}
		}

		private final class InternalSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {
			private var id: UUID?

			var subscriber: S?

			init() {
				self.id = EventManager.shared.add { [weak self] in
					_ = self?.subscriber?.receive($0)
				}
			}

			deinit {
				if let id = id {
					EventManager.shared.remove(id)
				}
			}

			func request(_ demand: Subscribers.Demand) {}

			func cancel() {
				subscriber = nil
			}
		}

		typealias Output = URLComponents
		typealias Failure = Never

		func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
			let subscription = InternalSubscription<S>()
			subscription.subscriber = subscriber
			subscriber.receive(subscription: subscription)
		}
	}

	/**
	Publishes when the app receives an open URL event.

	This can be useful for implementing support for a custom URL scheme.

	If you use SwiftUI, you should use `View#onOpenURL` instead.

	It returns `URLComponents` as it's more convenient, and also, `URL` does not support `foo:action` type URLs (without the slashes).

	- Important: You must set up the listener before the app finishes launching. Ideally, in the app controller's initializer.
	*/
	static let appOpenURL: AnyPublisher<URLComponents, Never> = AppOpenURLPublisher().eraseToAnyPublisher()
}


extension Binding where Value: CaseIterable & Equatable {
	/**
	```
	enum Priority: String, CaseIterable {
		case no
		case low
		case medium
		case high
	}

	// …

	Picker("Priority", selection: $priority.caseIndex) {
		ForEach(Priority.allCases.indices) { priorityIndex in
			Text(
				Priority.allCases[priorityIndex].rawValue.capitalized
			)
				.tag(priorityIndex)
		}
	}
	```
	*/
	var caseIndex: Binding<Value.AllCases.Index> {
		.init(
			get: { Value.allCases.firstIndex(of: wrappedValue)! },
			set: {
				wrappedValue = Value.allCases[$0]
			}
		)
	}
}


/**
Useful in SwiftUI:

```
ForEach(persons.indexed(), id: \.1.id) { index, person in
	// …
}
```
*/
struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
	typealias Index = Base.Index
	typealias Element = (index: Index, element: Base.Element)

	let base: Base
	var startIndex: Index { base.startIndex }
	var endIndex: Index { base.endIndex }

	func index(after index: Index) -> Index {
		base.index(after: index)
	}

	func index(before index: Index) -> Index {
		base.index(before: index)
	}

	func index(_ index: Index, offsetBy distance: Int) -> Index {
		base.index(index, offsetBy: distance)
	}

	subscript(position: Index) -> Element {
		(index: position, element: base[position])
	}
}

extension RandomAccessCollection {
	/**
	Returns a sequence with a tuple of both the index and the element.

	- Important: Use this instead of `.enumerated()`. See: https://khanlou.com/2017/03/you-probably-don%27t-want-enumerated/
	*/
	func indexed() -> IndexedCollection<Self> {
		IndexedCollection(base: self)
	}
}


/**
Create a `Picker` from an enum.

- Note: The enum must conform to `CaseIterable`.

```
enum EventIndicatorsInCalendar: String, Codable, CaseIterable {
	case none
	case one
	case maxThree

	var title: String {
		switch self {
		case .none:
			return "None"
		case .one:
			return "Single Gray Dot"
		case .maxThree:
			return "Up To Three Colored Dots"
		}
	}
}

struct ContentView: View {
	@Default(.indicateEventsInCalendar) private var indicator

	var body: some View {
		EnumPicker(
			"Foo",
			enumCase: $indicator
		) { element, isSelected in
			Text(element.title)
		}
	}
}
```
*/
struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index: Hashable, Label: View, Content: View {
	let enumBinding: Binding<Enum>
	@ViewBuilder let content: (Enum, Bool) -> Content
	@ViewBuilder let label: () -> Label

	var body: some View {
		Picker(selection: enumBinding.caseIndex) {
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				// TODO: Is `isSelected` really useful? If not, remove it.
				content(element, element == enumBinding.wrappedValue)
					.tag(index)
			}
		} label: {
			label()
		}
	}
}

extension EnumPicker where Label == Text {
	init<S>(
		_ title: S,
		enumBinding: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum, Bool) -> Content
	) where S: StringProtocol {
		self.enumBinding = enumBinding
		self.content = content
		self.label = { Text(title) }
	}
}


// TODO: Remove when targeting macOS 12.
extension View {
	func overlay2<Overlay: View>(
		alignment: Alignment = .center,
		@ViewBuilder content: () -> Overlay
	) -> some View {
		overlay(ZStack(content: content), alignment: alignment)
	}

	func background2<V: View>(
		alignment: Alignment = .center,
		@ViewBuilder content: () -> V
	) -> some View {
		background(ZStack(content: content), alignment: alignment)
	}
}


/**
A view, which when set to hidden, will never show again.

This can be useful for info boxes that the user can close and should not see again.
*/
struct PersistentlyHideableView<Content: View>: View {
	static func key(id: String, idPrefix: String? = nil) -> Defaults.Key<Bool> {
		.init("SS__\(idPrefix ?? "PersistentlyHideableView")__\(id)", default: false)
	}

	@Default private var isHidden: Bool
	private let content: Content

	init(
		id: String,
		idPrefix: String? = nil,
		@ViewBuilder content: (@escaping () -> Void) -> Content
	) {
		self._isHidden = Default(Self.key(id: id, idPrefix: idPrefix))

		var selfWorkaround: Self?
		self.content = content {
			withAnimation(.spring()) {
				selfWorkaround?.isHidden = true
			}
		}
		selfWorkaround = self
	}

	var body: some View {
		if !isHidden {
			content
		}
	}
}


/**
Info box that is only shown until the user clicks the hide button, and then never again.
*/
struct HideableInfoBox: View {
	let id: String
	let message: String

	var body: some View {
		PersistentlyHideableView(id: id, idPrefix: "HideableInfoBox") { hide in
			HStack {
				CloseOrClearButton("Hide") {
					hide()
				}
				Text(message)
					.font(.system(size: NSFont.smallSystemFontSize))
					.multilineTextAlignment(.leading)
					.foregroundColor(.secondary)
			}
				.padding(.vertical, 6)
				.padding(.horizontal, 8)
				.backgroundColor(.primary.opacity(0.05))
				.clipShape(.roundedRectangle(cornerRadius: 8, style: .continuous))
		}
	}
}


extension Shape where Self == Rectangle {
	static var rectangle: Self { .init() }
}

extension Shape where Self == Circle {
	static var circle: Self { .init() }
}

extension Shape where Self == Capsule {
	static var capsule: Self { .init() }
}

extension Shape where Self == Ellipse {
	static var ellipse: Self { .init() }
}

extension Shape where Self == ContainerRelativeShape {
	static var containerRelative: Self { .init() }
}

extension Shape where Self == RoundedRectangle {
	static func roundedRectangle(cornerRadius: Double, style: RoundedCornerStyle = .circular) -> Self {
		.init(cornerRadius: cornerRadius, style: style)
	}

	static func roundedRectangle(cornerSize: CGSize, style: RoundedCornerStyle = .circular) -> Self {
		.init(cornerSize: cornerSize, style: style)
	}
}


@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension Button where Label == SwiftUI.Label<Text, Image> {
	init(
		_ title: String,
		systemImage: String,
		role: ButtonRole? = nil,
		action: @escaping () -> Void
	) {
		self.init(
			role: role,
			action: action
		) {
			Label(title, systemImage: systemImage)
		}
	}
}

// TODO: Remove when targeting macOS 12.
extension Button where Label == SwiftUI.Label<Text, Image> {
	init(
		_ title: String,
		systemImage: String,
		action: @escaping () -> Void
	) {
		self.init(action: action) {
			Label(title, systemImage: systemImage)
		}
	}
}


private struct IconButtonStyle: ViewModifier {
	func body(content: Content) -> some View {
		content
			.buttonStyle(.borderless)
			.menuStyle(.borderlessButton)
			.labelStyle(.iconOnly)
	}
}

extension View {
	/**
	Make `Button` and `Menu` be borderless and only show the icon.
	*/
	func iconButtonStyle() -> some View {
		modifier(IconButtonStyle())
	}
}


/**
An icon button used for closing or clearing something.
*/
struct CloseOrClearButton: View {
	private let title: String
	private let action: () -> Void

	init(_ title: String, action: @escaping () -> Void) {
		self.title = title
		self.action = action
	}

	var body: some View {
		Button(title, systemImage: "xmark.circle.fill", action: action)
			.iconButtonStyle()
	}
}
