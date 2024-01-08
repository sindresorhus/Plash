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
import Sentry
import Defaults

typealias Defaults = _Defaults
typealias Default = _Default
typealias AnyCancellable = Combine.AnyCancellable

// TODO: Check if any of these can be removed when targeting macOS 15.
extension NSImage: @unchecked Sendable {}

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


func delay(_ duration: Duration, closure: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + duration.toTimeInterval, execute: closure)
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
	var onUpdate: (() -> Void)?

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
	}

	func menuDidClose(_ menu: NSMenu) {
		isOpen = false
	}

	func menuNeedsUpdate(_ menu: NSMenu) {
		onUpdate?()
	}
}


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

		if let keyModifiers {
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

		if let keyModifiers {
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

	@MainActor
	@discardableResult
	func addSettingsItem() -> NSMenuItem {
		addCallbackItem("Settings…", key: ",") {
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
			Task { @MainActor in // TODO: Remove this when NSMenu is annotated as main actor.
				SSApp.activateIfAccessory()
			}

			NSApp.orderFrontStandardAboutPanel(nil)
		}
	}

	@MainActor
	@discardableResult
	func addQuitItem() -> NSMenuItem {
		addSeparator()

		return addCallbackItem("Quit \(SSApp.name)", key: "q") {
			SSApp.quit()
		}
	}
}


enum SSApp {
	static let idString = Bundle.main.bundleIdentifier!
	static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
	static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
	static let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
	static let versionWithBuild = "\(version) (\(build))"
	static let icon = NSApp.applicationIconImage!
	static let url = Bundle.main.bundleURL

	@MainActor
	static func quit() {
		NSApp.terminate(nil)
	}

	static let isFirstLaunch: Bool = {
		let key = "SS_hasLaunched"

		if UserDefaults.standard.bool(forKey: key) {
			return false
		}

		UserDefaults.standard.set(true, forKey: key)
		return true
	}()

	static func openSendFeedbackPage() {
		let metadata =
			"""
			\(name) \(versionWithBuild) - \(idString)
			macOS \(Device.osVersion)
			\(Device.hardwareModel)
			"""

		let query: [String: String] = [
			"product": name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback")
			.addingDictionaryAsQuery(query)
			.open()
	}

	@MainActor
	static func activateIfAccessory() {
		guard NSApp.activationPolicy() == .accessory else {
			return
		}

		forceActivate()
	}

//	@MainActor
	static func forceActivate() {
		if #available(macOS 14, *) {
			NSApp.yieldActivation(toApplicationWithBundleIdentifier: idString)
			NSApp.activate()
		} else {
			NSApp.activate(ignoringOtherApps: true)
		}
	}
}

extension SSApp {
	/**
	Manually show the SwiftUI settings window.
	*/
	@MainActor
	static func showSettingsWindow() {
		// Run in the next runloop so it doesn't conflict with SwiftUI if run at startup.
		DispatchQueue.main.async {
			activateIfAccessory()

			if #available(macOS 14, *) {
				NSApp.mainMenu?.items.first?.submenu?.item(withTitle: "Settings…")?.performAction()
			} else {
				NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
			}
		}
	}
}


extension SSApp {
	/**
	Initialize Sentry.
	*/
	static func initSentry(_ dsn: String) {
		#if !DEBUG && canImport(Sentry)
		SentrySDK.start {
			$0.dsn = dsn
			$0.enableSwizzling = false
			$0.enableAppHangTracking = false // https://github.com/getsentry/sentry-cocoa/issues/2643
		}
		#endif
	}
}


extension NSMenuItem {
	func performAction() {
		guard let menu else {
			return
		}

		menu.performActionForItem(at: menu.index(of: self))
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
		// TODO: Make this `compactMapValues(\.self)` when https://github.com/apple/swift/issues/55343 is fixed.
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


extension String {
	var toNSAttributedString: NSAttributedString { .init(string: self) }
}


private var controlActionClosureProtocolAssociatedObjectKey: UInt8 = 0

// TODO: When NSMenu conforms, otherwise it's too annoying.
//@MainActor
protocol ControlActionClosureProtocol: NSObjectProtocol {
	var target: AnyObject? { get set }
	var action: Selector? { get set }
}

//@MainActor
private final class ActionTrampoline {
	fileprivate let action: (NSEvent) -> Void

	init(action: @escaping (NSEvent) -> Void) {
		self.action = action
	}

	@objc
	fileprivate func handleAction(_ sender: AnyObject) {
		action(NSApp.currentEvent!)
	}
}

extension ControlActionClosureProtocol {
	var onAction: ((NSEvent) -> Void)? {
		get {
			guard
				let trampoline = objc_getAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey) as? ActionTrampoline
			else {
				return nil
			}

			return trampoline.action
		}
		set {
			guard let newValue else {
				objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, nil, .OBJC_ASSOCIATION_RETAIN)
				return
			}

			let trampoline = ActionTrampoline(action: newValue)
			target = trampoline
			action = #selector(ActionTrampoline.handleAction)
			objc_setAssociatedObject(self, &controlActionClosureProtocolAssociatedObjectKey, trampoline, .OBJC_ASSOCIATION_RETAIN)
		}
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
			nsView.attributedTitle = attributedTitle ?? "".toNSAttributedString
		}

		nsView.keyEquivalent = keyEquivalent?.rawValue ?? ""
		nsView.bezelStyle = bezelStyle

		nsView.onAction = { _ in
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
		guard let host else {
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
			let host
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


extension Binding {
	/**
	Listen to `didSet` of a Binding.
	*/
	func didSet(_ didSet: @escaping ((newValue: Value, oldValue: Value)) -> Void) -> Self {
		.init(
			get: { wrappedValue },
			set: { newValue in
				let oldValue = wrappedValue
				wrappedValue = newValue
				didSet((newValue, oldValue))
			}
		)
	}
}


extension Binding<Double> {
	// TODO: Maybe make a general `Binding#convert()` function that accepts a converter. Something like `binding.convert(.secondsToMinutes)`?
	var secondsToMinutes: Self {
		map(
			get: { $0 / 60 },
			set: { $0 * 60 }
		)
	}
}


extension String {
	var trimmed: Self {
		trimmingCharacters(in: .whitespacesAndNewlines)
	}

	var trimmedTrailing: Self {
		replacing(/\s+$/, with: "")
	}

	func removingPrefix(_ prefix: Self) -> Self {
		guard hasPrefix(prefix) else {
			return self
		}

		return Self(dropFirst(prefix.count))
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
		}

		if count > number {
			return Self(prefix(number - truncationIndicator.count)).trimmedTrailing + truncationIndicator
		}

		return self
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
	Show an async alert sheet on a window.
	*/
	@MainActor
	@discardableResult
	static func show(
		in window: NSWindow? = nil,
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) async -> NSApplication.ModalResponse {
		let alert = NSAlert(
			title: title,
			message: message,
			style: style,
			buttonTitles: buttonTitles,
			defaultButtonIndex: defaultButtonIndex
		)

		guard let window else {
			return await alert.run()
		}

		return await alert.beginSheetModal(for: window)
	}

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

		if let message {
			self.informativeText = message
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/**
	Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window else {
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


extension NSAlert {
	/**
	Workaround to allow using `NSAlert` in a `Task`.

	[FB9857161](https://github.com/feedback-assistant/reports/issues/288)
	*/
	@MainActor
	@discardableResult
	func run() async -> NSApplication.ModalResponse {
		await withCheckedContinuation { continuation in
			DispatchQueue.main.async { [self] in
				continuation.resume(returning: runModal())
			}
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


extension WKWebView {
	static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15"
	static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"

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

		if let returnError {
			throw returnError
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
	func defaultAlertHandler(message: String) async {
		let alert = NSAlert()
		alert.messageText = message
		await alert.run()
	}

	/**
	Default handler for JavaScript `confirm()` to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultConfirmHandler(message: String) async -> Bool {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = message
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")
		return await alert.run() == .alertFirstButtonReturn
	}

	/**
	Default handler for JavaScript `prompt()` to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultPromptHandler(prompt: String, defaultText: String?) async -> String? {
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = prompt
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")

		let textField = AutofocusedTextField(frame: CGRect(x: 0, y: 0, width: 200, height: 22))
		textField.stringValue = defaultText ?? ""
		alert.accessoryView = textField

		return await alert.run() == .alertFirstButtonReturn ? textField.stringValue : nil
	}

	/**
	Default handler for JavaScript initiated upload panel to be used in `WKDelegate`.
	*/
	@MainActor
	func defaultUploadPanelHandler(parameters: WKOpenPanelParameters) async -> [URL]? { // swiftlint:disable:this discouraged_optional_collection
		let openPanel = NSOpenPanel()
		openPanel.level = .floating
		openPanel.prompt = "Choose"
		openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
		openPanel.canChooseFiles = !parameters.allowsDirectories
		openPanel.canChooseDirectories = parameters.allowsDirectories

		// It's intentionally modal as we don't want the user to interact with the website until they're done with the panel.
		return await openPanel.begin() == .OK ? openPanel.urls : nil
	}

	// Can be tested at https://jigsaw.w3.org/HTTP/Basic/ with `guest` as username and password.
	/**
	Default handler for websites requiring basic authentication. To be used in `WKDelegate`.
	*/
	@MainActor
	func defaultAuthChallengeHandler(
		challenge: URLAuthenticationChallenge,
		allowSelfSignedCertificate: Bool = false
	) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
		guard
			let url,
			let host = url.host
		else {
			return (.performDefaultHandling, nil)
		}

		guard
			challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
				|| challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
		else {
			guard
				allowSelfSignedCertificate || url.isLocal,
				let serverTrust = challenge.protectionSpace.serverTrust
			else {
				return (.performDefaultHandling, nil)
			}

			let exceptions = SecTrustCopyExceptions(serverTrust)

			guard SecTrustSetExceptions(serverTrust, exceptions) else {
				return (.cancelAuthenticationChallenge, nil)
			}

			return (.useCredential, .init(trust: serverTrust))
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

		guard await alert.run() == .alertFirstButtonReturn else {
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


extension URL {
	var isLocal: Bool {
		guard let host = host?.nilIfEmpty?.lowercased() else {
			return false
		}

		return host == "localhost"
			|| host == "127.0.0.1"
			|| host == "::1"
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

	init(value: Value, publisher: some Publisher) {
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


extension CFUUID {
	var toUUID: UUID {
		let bytes = CFUUIDGetUUIDBytes(self)

		let newBytes = (
			bytes.byte0,
			bytes.byte1,
			bytes.byte2,
			bytes.byte3,
			bytes.byte4,
			bytes.byte5,
			bytes.byte6,
			bytes.byte7,
			bytes.byte8,
			bytes.byte9,
			bytes.byte10,
			bytes.byte11,
			bytes.byte12,
			bytes.byte13,
			bytes.byte14,
			bytes.byte15
		)

		return .init(uuid: newBytes)
	}
}


extension UUID {
	var toCFUUID: CFUUID {
		let bytes = uuid

		let newBytes = CFUUIDBytes(
			byte0: bytes.0,
			byte1: bytes.1,
			byte2: bytes.2,
			byte3: bytes.3,
			byte4: bytes.4,
			byte5: bytes.5,
			byte6: bytes.6,
			byte7: bytes.7,
			byte8: bytes.8,
			byte9: bytes.9,
			byte10: bytes.10,
			byte11: bytes.11,
			byte12: bytes.12,
			byte13: bytes.13,
			byte14: bytes.14,
			byte15: bytes.15
		)

		return CFUUIDCreateFromUUIDBytes(nil, newBytes)
	}
}


extension NSScreen: Identifiable {
	public var id: CGDirectDisplayID {
		deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! CGDirectDisplayID
	}
}

extension NSScreen {
	/**
	Convert a persistent display ID to a transient one.
	*/
	static func uuidFromID(_ id: CGDirectDisplayID) -> UUID? {
		// We force an optional as it can be `nil` in some cases even though it's not annotated as that.
		// https://github.com/lwouis/alt-tab-macos/issues/330
		let cfUUID: CFUUID? = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
		return cfUUID?.toUUID
	}

	/**
	Convert a transient display ID to a persistent one.
	*/
	static func idFromUUID(_ uuid: UUID) -> CGDirectDisplayID? {
		let id = CGDisplayGetDisplayIDFromUUID(uuid.toCFUUID)

		// `CGDisplayGetDisplayIDFromUUID` returns `0` if the UUID is not found. We also prevent any potential negative values.
		guard id > 0 else {
			return nil
		}

		return id
	}

	/**
	The persistent identifier of the screen.

	The `.id` property is only persistent for the current session.
	*/
	var uuid: UUID? { Self.uuidFromID(id) }
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
		Self.screens.contains { $0.id == id }
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
	The thickness of the status bar on the screen.

	If the screen does not have a status bar, it returns `0`.

	- Note: There is a 1 point gap between the status bar and a maximized window. You may want to handle that.
	*/
	var statusBarThickness: Double {
		let value = (frame.height - visibleFrame.height - (visibleFrame.origin.y - frame.origin.y) - 1).double
		return max(0, value)
	}

	/**
	Get the frame of the actual visible part of the screen. This means under the dock, but *not* under the status bar if there's a status bar. This is different from `.visibleFrame` which also includes the space under the status bar.
	*/
	var frameWithoutStatusBar: CGRect {
		var frame = frame

		// Account for the status bar if the window is on the main screen and the status bar is permanently visible, or if on a secondary screen and secondary screens are set to show the status bar.
		if hasStatusBar {
			frame.size.height -= statusBarThickness
		}

		return frame
	}

	/**
	Whether the screen has a notch.
	*/
	var hasNotch: Bool {
		guard let width = auxiliaryTopRightArea?.width else {
			return false
		}

		return width < frame.width
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
	static let main = Self(transientID: CGMainDisplayID())

	/**
	All displays.
	*/
	static var all: [Self] {
		NSScreen.screens.compactMap { self.init(screen: $0) }
	}

	/**
	The persistent ID of the display.
	*/
	let id: UUID

	/**
	The transient ID of the display.
	*/
	var transientID: CGDirectDisplayID? { NSScreen.idFromUUID(id) }

	/**
	The `NSScreen` for the display.
	*/
	var screen: NSScreen? {
		NSScreen.screens.first { $0.uuid == id }
	}

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
	var withFallbackToMain: Self? { isConnected ? self : .main }

	init(_ id: UUID) {
		self.id = id
	}

	init?(transientID: CGDirectDisplayID) {
		guard let id = NSScreen.uuidFromID(transientID) else {
			return nil
		}

		self.init(id)
	}

	init?(screen: NSScreen) {
		self.init(transientID: screen.id)
	}
}

extension Display: Defaults.Serializable {
	struct Bridge: Defaults.Bridge {
		typealias Value = Display
		typealias Serializable = UUID

		func serialize(_ value: Value?) -> Serializable? {
			value?.id
		}

		func deserialize(_ object: Serializable?) -> Value? {
			guard let object else {
				return nil
			}

			return .init(object)
		}
	}

	static let bridge = Bridge()
}


extension StringProtocol {
	/**
	Word wrap the string at the given length.
	*/
	func wordWrapped(atLength length: Int) -> String {
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
		String(trimmingPrefix(/https?:\/\/(?:www\.)?/))
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
	Whether the user has "Turn Hiding On" enabled in the Dock settings.
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
	The actual thickness of the primary status bar. `.thickness` confusingly returns the thickness of the content area.

	Keep in mind for screen calculations that the status bar has an additional 1 point padding below it (between it and windows).

	- Note: This only returns the thickness of the menu bar on the primary screen.
	*/
	static var actualThicknessOfPrimary: Double {
		let legacyHeight = 24.0

		guard let screen = NSScreen.primary else {
			return legacyHeight
		}

		return screen.hasNotch ? 33 : legacyHeight
	}

	/**
	Whether the user has "Automatically hide and show the menu bar" enabled in system settings.
	*/
	static var isAutomaticallyToggled: Bool {
		guard let screen = NSScreen.primary else {
			return false
		}

		// There's a 1 point gap between the status bar and any maximized window.
		let statusBarBottomPadding = 1.0

		let menuBarHeight = actualThicknessOfPrimary + statusBarBottomPadding
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
		.systemBlue,
		.systemBrown,
		.systemGray,
		.systemGreen,
		.systemIndigo,
		.systemOrange,
		.systemPink,
		.systemPurple,
		.systemRed,
		.systemTeal,
		.systemYellow
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
	static func scheduledRepeatingTimer(
		withTimeInterval interval: Duration,
		totalDuration: Duration,
		onRepeat: ((Timer) -> Void)? = nil,
		onFinish: (() -> Void)? = nil
	) -> Timer {
		let startDate = Date()

		return scheduledTimer(withTimeInterval: interval.toTimeInterval, repeats: true) { timer in
			guard Date() <= startDate.addingTimeInterval(totalDuration.toTimeInterval) else {
				timer.invalidate()
				onFinish?()
				return
			}

			onRepeat?(timer)
		}
	}
}


extension NSStatusBarButton {
	/**
	Quickly cycles through random colors to make a rainbow animation so the user will notice it.

	- Note: It will do nothing if the user has enabled the “Reduce motion” accessibility settings.
	*/
	func playRainbowAnimation(for duration: Duration = .seconds(5)) {
		guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
			return
		}

		let originalTintColor = contentTintColor

		Timer.scheduledRepeatingTimer(
			withTimeInterval: .seconds(0.1),
			totalDuration: duration,
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

		SSApp.activateIfAccessory()

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
		removeQuery: Bool = false,
		removeDefaultPort: Bool = true,
		removeWWW: Bool = true
	) -> Self {
		let url = absoluteURL.standardized

		guard var components = url.components else {
			return self
		}

		if components.path == "/" {
			components.path = ""
		}

		// Remove port 80 if it's there as it's the default.
		if removeDefaultPort, components.port == 80 {
			components.port = nil
		}

		// Lowercase host and scheme.
		components.host = components.host?.lowercased()
		components.scheme = components.scheme?.lowercased()

		if removeWWW {
			components.host = components.host?.removingPrefix("www.")
		}

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
				"Failed to encode placeholder “\(placeholder)”"
			case .invalidURLAfterSubstitution(let urlString):
				"New URL was not valid after substituting placeholders. URL string is “\(urlString)”"
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

		let urlString = absoluteString.replacing(encodedPlaceholder, with: replacement)

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

		if let recoverySuggestion {
			userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
		}

		return .init(
			domain: domainPostfix.map { "\(SSApp.idString) - \($0)" } ?? SSApp.idString,
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
		guard let window else {
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
		guard let window else {
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
		} catch is CancellationError, URLError.cancelled, CocoaError.userCancelled {
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


enum AssociationPolicy {
	case assign
	case retainNonatomic
	case copyNonatomic
	case retain
	case copy

	var rawValue: objc_AssociationPolicy {
		switch self {
		case .assign:
			.OBJC_ASSOCIATION_ASSIGN
		case .retainNonatomic:
			.OBJC_ASSOCIATION_RETAIN_NONATOMIC
		case .copyNonatomic:
			.OBJC_ASSOCIATION_COPY_NONATOMIC
		case .retain:
			.OBJC_ASSOCIATION_RETAIN
		case .copy:
			.OBJC_ASSOCIATION_COPY
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
			|| string.hasPrefix("http://localhost")
			|| string.hasPrefix("https://localhost")
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

		let url = string.replacing(/^(?!(?:\w+:)?\/\/)/, with: "https://")

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
	func `if`(
		_ condition: @autoclosure () -> Bool,
		modify: (Self) -> some View
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
	func `if`(
		_ condition: @autoclosure () -> Bool,
		if modifyIf: (Self) -> some View,
		else modifyElse: (Self) -> some View
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


private struct EmptyStateTextModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(.title2)
			.foregroundStyle(.tertiary)
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


// Multiple `.alert` are stil broken in macOS 12.
extension View {
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View,
		@ViewBuilder message: () -> some View
	) -> some View {
		background(
			EmptyView()
				.alert(
					title,
					isPresented: isPresented,
					actions: actions,
					message: message
				)
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View,
		@ViewBuilder message: () -> some View
	) -> some View {
		alert2(
			Text(title),
			isPresented: isPresented,
			actions: actions,
			message: message
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		message: String? = nil,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View
	) -> some View {
		// swiftlint:disable:next trailing_closure
		alert2(
			title,
			isPresented: isPresented,
			actions: actions,
			message: {
				if let message {
					Text(message)
				}
			}
		)
	}

	// This is a convenience method and does not exist natively.
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		message: String? = nil,
		isPresented: Binding<Bool>,
		@ViewBuilder actions: () -> some View
	) -> some View {
		// swiftlint:disable:next trailing_closure
		alert2(
			title,
			isPresented: isPresented,
			actions: actions,
			message: {
				if let message {
					Text(message)
				}
			}
		)
	}

	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: Text,
		message: String? = nil,
		isPresented: Binding<Bool>
	) -> some View {
		// swiftlint:disable:next trailing_closure
		alert2(
			title,
			message: message,
			isPresented: isPresented,
			actions: {}
		)
	}

	// This is a convenience method and does not exist natively.
	/**
	This allows multiple alerts on a single view, which `.alert()` doesn't.
	*/
	func alert2(
		_ title: String,
		message: String? = nil,
		isPresented: Binding<Bool>
	) -> some View {
		// swiftlint:disable:next trailing_closure
		alert2(
			title,
			message: message,
			isPresented: isPresented,
			actions: {}
		)
	}
}


// Multiple `.confirmationDialog` are broken in macOS 12.
extension View {
	/**
	This allows multiple confirmation dialogs on a single view, which `.confirmationDialog()` doesn't.
	*/
	func confirmationDialog2(
		_ title: Text,
		isPresented: Binding<Bool>,
		titleVisibility: Visibility = .automatic,
		@ViewBuilder actions: () -> some View,
		@ViewBuilder message: () -> some View
	) -> some View {
		background(
			EmptyView()
				.confirmationDialog(
					title,
					isPresented: isPresented,
					titleVisibility: titleVisibility,
					actions: actions,
					message: message
				)
		)
	}

	/**
	This allows multiple confirmation dialogs on a single view, which `.confirmationDialog()` doesn't.
	*/
	func confirmationDialog2(
		_ title: Text,
		message: String? = nil,
		isPresented: Binding<Bool>,
		titleVisibility: Visibility = .automatic,
		@ViewBuilder actions: () -> some View
	) -> some View {
		// swiftlint:disable:next trailing_closure
		confirmationDialog2(
			title,
			isPresented: isPresented,
			titleVisibility: titleVisibility,
			actions: actions,
			message: {
				if let message {
					Text(message)
				}
			}
		)
	}

	/**
	This allows multiple confirmation dialogs on a single view, which `.confirmationDialog()` doesn't.
	*/
	func confirmationDialog2(
		_ title: String,
		message: String? = nil,
		isPresented: Binding<Bool>,
		titleVisibility: Visibility = .automatic,
		@ViewBuilder actions: () -> some View
	) -> some View {
		confirmationDialog2(
			Text(title),
			message: message,
			isPresented: isPresented,
			titleVisibility: titleVisibility,
			actions: actions
		)
	}
}



extension View {
	/**
	This allows multiple popovers on a single view, which `.popover()` doesn't.
	*/
	func popover2(
		isPresented: Binding<Bool>,
		attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
		arrowEdge: Edge = .top,
		@ViewBuilder content: @escaping () -> some View
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


extension NSItemProvider {
	func loadObject<T>(ofClass: T.Type) async throws -> T? where T: NSItemProviderReading {
		try await withCheckedThrowingContinuation { continuation in
			_ = loadObject(ofClass: ofClass) { data, error in
				if let error {
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
				if let error {
					continuation.resume(throwing: error)
					return
				}

				guard let data else {
					continuation.resume(returning: nil)
					return
				}

				continuation.resume(returning: data)
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
	func hasItemConforming(to contentType: UTType) -> Bool {
		hasItemConformingToTypeIdentifier(contentType.identifier)
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
	var toData: Data { Data(utf8) }
}

extension Data {
	var toString: String? { String(data: self, encoding: .utf8) }
}


extension Data {
	struct HexEncodingOptions: OptionSet {
		let rawValue: Int
		static let upperCase = Self(rawValue: 1 << 0)
	}

	func hexEncodedString(options: HexEncodingOptions = []) -> String {
		let hexDigits = options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef"
		let utf8Digits = Array(hexDigits.utf8)

		return String(unsafeUninitializedCapacity: count * 2) { pointer in
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
		toData.sha256().hexEncodedString()
	}

	func sha512() -> Self {
		toData.sha512().hexEncodedString()
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
			guard let value = object as? Self else {
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
			guard let newValue else {
				// If the value is `nil`, remove the entry from the cache.
				cache.removeObject(forKey: .init(key: key))

				return
			}

			cache.setObject(.init(value: newValue), forKey: .init(key: key))
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
		if let diskCacheName {
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
		guard let cacheDirectory else {
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
			guard let self else {
				return
			}

			guard let tiffData = image.tiffRepresentation else {
				assertionFailure("Could not get TIFF representation from image.")
				return
			}

			// Ensure the cache directory exists in case it was removed by `.removeAllImages()` or the user.
			createCacheDirectoryIfNeeded()

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
			let cacheDirectory
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
		guard let image else {
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
			guard let newValue else {
				removeImage(for: key)
				return
			}

			insertImage(newValue, for: key)
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
		try map { element in
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
		try map { element in
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
			let element,
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
			let element,
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
	static let isMacOS15OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 15, *) {
			return true
		}

		return false
		#else
		false
		#endif
	}()

	/**
	- Note: Only use this when you cannot use an `if #available` check. For example, inline in function calls.
	*/
	static let isMacOS14OrLater: Bool = {
		#if os(macOS)
		if #available(macOS 14, *) {
			return true
		}

		return false
		#else
		false
		#endif
	}()
}

typealias OS = OperatingSystem


extension View {
	@ViewBuilder
	func ifLet<Value>(
		_ value: Value?,
		modifier: (Self, Value) -> some View
	) -> some View {
		if let value {
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

extension InfoPopoverButton<Text> {
	init(_ text: some StringProtocol, maxWidth: Double = 240) {
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
- Make the thumbnail in WebsitesScreen not upscale when using 32x32 favicon.
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
		guard url.isValid else {
			throw NSError.appError("Invalid URL: \(url.absoluteString)")
		}

		return try await self.init().fetch(for: url)
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
			iconProvider.hasItemConforming(to: .image)
		else {
			return nil
		}

		return await iconProvider.getImage()
	}

	// TODO: This is moot as the class is marked as `@MainActor`, but we keep it for now just in case.
	@MainActor
	private func getFromManifest() async throws -> NSImage? {
		let code =
			"""
			document.querySelector('link[rel="manifest"]').href
			"""

		let result = try await webView.evaluateJavaScript(code, contentWorld: .defaultClient)

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

		let result = try await webView.evaluateJavaScript(code, contentWorld: .defaultClient)

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

		let result = try await webView.evaluateJavaScript(code, contentWorld: .defaultClient)

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
		continuation?.resume()
		continuation = nil // These delegate methods can be called multiple times.
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
		continuation = nil
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		continuation?.resume(throwing: error)
		continuation = nil
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
	func border(
		_ content: some ShapeStyle,
		width lineWidth: Double = 1,
		cornerRadius: Double,
		cornerStyle: RoundedCornerStyle = .circular
	) -> some View {
		self.cornerRadius(cornerRadius, style: cornerStyle)
			.overlay {
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
			.overlay {
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
			!isFirstLaunch,
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
	typealias Number = AdditiveArithmetic & Decodable

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
		onReceive(NotificationCenter.default.publisher(for: name, object: object), perform: action)
	}
}


extension View {
	/**
	Fills the frame.
	*/
	func fillFrame(
		_ axis: Axis.Set = [.horizontal, .vertical],
		alignment: Alignment = .center
	) -> some View {
		frame(
			maxWidth: axis.contains(.horizontal) ? .infinity : nil,
			maxHeight: axis.contains(.vertical) ? .infinity : nil,
			alignment: alignment
		)
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
	static func binding<Value>(for key: Key<Value>) -> Binding<Value> {
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
	static func bindingCollection<Value>(for key: Key<Value>) -> BindingCollection<Value> where Value: MutableCollection & RandomAccessCollection {
		.init(base: binding(for: key))
	}
}


// TODO: Remove when targeting macOS 14.
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
	func bindHostingWindow(_ window: Binding<NSWindow?>) -> some View {
		background(WindowAccessor(window))
	}
}

private struct WindowViewModifier: ViewModifier {
	@State private var window: NSWindow?

	let onWindow: (NSWindow?) -> Void

	func body(content: Content) -> some View {
		onWindow(window)

		return content
			.bindHostingWindow($window)
	}
}

extension View {
	/**
	Access the native backing-window of a SwiftUI window.
	*/
	func accessHostingWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
		modifier(WindowViewModifier(onWindow: onWindow))
	}

	/**
	Set the window level of a SwiftUI window.
	*/
	func windowLevel(_ level: NSWindow.Level) -> some View {
		accessHostingWindow {
			$0?.level = level
		}
	}

	func windowIsMinimizable(_ isMinimizable: Bool = true) -> some View {
		accessHostingWindow {
			$0?.styleMask.toggleExistence(.miniaturizable, shouldExist: isMinimizable)
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
			Label("General", systemImage: "gearshape")
		case .advanced:
			Label("Advanced", systemImage: "gearshape.2")
		case .shortcuts:
			Label("Shortcuts", systemImage: "command")
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

			private init() {}

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
				if let id {
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


struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index: Hashable, Label: View, Content: View {
	let selection: Binding<Enum>
	@ViewBuilder let content: (Enum) -> Content
	@ViewBuilder let label: () -> Label

	var body: some View {
		Picker(selection: selection.caseIndex) { // swiftlint:disable:this multiline_arguments
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				content(element)
					.tag(index)
			}
		} label: {
			label()
		}
	}
}

extension EnumPicker where Label == Text {
	init(
		_ title: some StringProtocol,
		selection: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum) -> Content
	) {
		self.selection = selection
		self.content = content
		self.label = { Text(title) }
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
					.foregroundStyle(.secondary)
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


extension Button<Label<Text, Image>> {
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


extension NSWorkspace {
	/**
	Bounces the Downloads folder in the Dock if present.

	Specify the URL to a file in the Downloads folder.
	*/
	func bounceDownloadsFolderInDock(for url: URL) {
		DistributedNotificationCenter.default().post(name: .init("com.apple.DownloadFileFinished"), object: url.path)
	}
}


extension URL {
	func incrementalFilename() -> Self {
		let pathExtension = pathExtension
		let filename = deletingPathExtension().lastPathComponent
		var url = self
		var counter = 0

		while FileManager.default.fileExists(atPath: url.path) {
			counter += 1
			url.deleteLastPathComponent()
			url.appendPathComponent("\(filename) (\(counter))", isDirectory: false)
			url.appendPathExtension(pathExtension)
		}

		return url
	}
}


extension URL {
	/**
	Whether the domain of the URL matches the given domain, with any or no subdomain.
	*/
	func hasDomain(_ domain: String) -> Bool {
		assert(!domain.hasPrefix("."))
		assert(domain.contains("."))

		guard let host else {
			return false
		}

		// `URL` does not have a way to get the domain without subdomains, so we fake it.
		return host == domain || host.hasSuffix(".\(domain)")
	}
}


extension Duration {
	var nanoseconds: Int64 {
		let (seconds, attoseconds) = components
		let secondsNanos = seconds * 1_000_000_000
		let attosecondsNanons = attoseconds / 1_000_000_000
		let (totalNanos, isOverflow) = secondsNanos.addingReportingOverflow(attosecondsNanons)
		return isOverflow ? .max : totalNanos
	}

	var toTimeInterval: TimeInterval { Double(nanoseconds) / 1_000_000_000 }
}


extension UUID: Identifiable {
	public var id: Self { self }
}


extension View {
	/**
	`.task()` with debouncing.
	*/
	func debouncingTask(
		id: some Equatable,
		priority: TaskPriority = .userInitiated,
		interval: Duration,
		@_inheritActorContext @_implicitSelfCapture _ action: @Sendable @escaping () async -> Void
	) -> some View {
		task(id: id, priority: priority) {
			do {
				try await Task.sleep(for: interval)
				await action()
			} catch {}
		}
	}
}


extension View {
	/**
	Add a keyboard shortcut to a view, not a button.
	*/
	func onKeyboardShortcut(
		_ shortcut: KeyboardShortcut?,
		perform action: @escaping () -> Void
	) -> some View {
		overlay {
			Button("", action: action)
				.labelsHidden()
				.opacity(0)
				.frame(width: 0, height: 0)
				.keyboardShortcut(shortcut)
				.accessibilityHidden(true)
		}
	}

	/**
	Add a keyboard shortcut to a view, not a button.
	*/
	func onKeyboardShortcut(
		_ key: KeyEquivalent,
		modifiers: SwiftUI.EventModifiers = .command,
		isEnabled: Bool = true,
		perform action: @escaping () -> Void
	) -> some View {
		onKeyboardShortcut(isEnabled ? .init(key, modifiers: modifiers) : nil, perform: action)
	}
}


extension View {
	/**
	Listen to double click events on the view.

	This exists as it's the only way to make double click not interfere with reordering a list.
	*/
	func onDoubleClick(
		_ action: @escaping () -> Void
	) -> some View {
		OnDoubleClick(action: action, content: self)
	}
}

private struct OnDoubleClick<Content>: View where Content: View {
	let action: () -> Void
	let content: Content

	var body: some View {
		OnDoubleClickRepresentable(action: action, content: content)
	}
}

private struct OnDoubleClickRepresentable<Content: View>: NSViewRepresentable {
	final class HostingView<Content2: View>: NSHostingView<Content2> {
		var action: (() -> Void)?

		override func mouseDown(with event: NSEvent) {
			if event.clickCount == 2 {
				action?()
			}

			super.mouseDown(with: event)
		}
	}

	let action: () -> Void
	let content: Content

	func makeNSView(context: Context) -> HostingView<Content> {
		let nsView = HostingView(rootView: content)
		nsView.action = action
		return nsView
	}

	func updateNSView(_ nsView: HostingView<Content>, context: Context) {}
}
