import SwiftUI
import Defaults
import KeyboardShortcuts

struct Constants {
	static let menuBarIcon = NSImage(named: "MenuBarIcon")!
}

extension Defaults.Keys {
	static let websites = Key<[Website]>("websites", default: [])
	static let isBrowsingMode = Key<Bool>("isBrowsingMode", default: false)

	// Settings
	static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
	static let opacity = Key<Double>("opacity", default: 1)
	static let reloadInterval = Key<Double?>("reloadInterval")
	static let display = Key<Display>("display", default: .main)
	static let deactivateOnBattery = Key<Bool>("deactivateOnBattery", default: false)
	static let showOnAllSpaces = Key<Bool>("showOnAllSpaces", default: false)
	static let bringBrowsingModeToFront = Key<Bool>("bringBrowsingModeToFront", default: false)
	static let openExternalLinksInBrowser = Key<Bool>("openExternalLinksInBrowser", default: false)

	// TODO: Remove at some point in the future. Not before 2022.
	// Deprecated
	static let url = Key<URL?>("url")
	static let invertColors = Key<Bool>("invertColors", default: false)
	static let customCSS = Key<String>("customCSS", default: "")
}

extension KeyboardShortcuts.Name {
	static let toggleBrowsingMode = Self("toggleBrowsingMode")
	static let reload = Self("reload")
	static let nextWebsite = Self("nextWebsite")
	static let previousWebsite = Self("previousWebsite")
}

extension Notification.Name {
	static let showAddWebsiteDialog = Self("showAddWebsiteDialog")
}
