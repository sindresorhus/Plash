import Cocoa
import Defaults

struct Constants {
	static let menuBarIcon = NSImage(named: "MenuBarIcon")!
}

extension Defaults.Keys {
	static let url = Key<URL?>("url")
	static let opacity = Key<Double>("opacity", default: 1)
	static let reloadInterval = Key<Double?>("reloadInterval")
	static let display = Key<Display>("display", default: .main)
	static let invertColors = Key<Bool>("invertColors", default: false)
	static let customCSS = Key<String>("customCSS", default: "")
	static let deactivateOnBattery = Key<Bool>("deactivateOnBattery", default: false)
	static let showOnAllSpaces = Key<Bool>("showOnAllSpaces", default: false)
}
