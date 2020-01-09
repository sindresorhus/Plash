import Cocoa
import Defaults

struct Constants {
	static let menuBarIcon = NSImage(named: "MenuBarIcon")!
}

extension Defaults.Keys {
	static let url = OptionalKey<URL>("url")
	static let opacity = Key<Double>("opacity", default: 1)
	static let reloadInterval = OptionalKey<Double>("reloadInterval")
}
