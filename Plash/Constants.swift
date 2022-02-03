import SwiftUI
import Defaults
import KeyboardShortcuts

enum Constants {
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
	static let muteAudio = Key<Bool>("muteAudio", default: true)

	// TODO: Remove at some point in the future. Not before 2023.
	// Deprecated
	static let url = Key<URL?>("url")
	static let customCSS = Key<String>("customCSS", default: "")
}

extension Website: Defaults.Serializable {}
extension Display: Defaults.Serializable {}

extension KeyboardShortcuts.Name {
	static let toggleBrowsingMode = Self("toggleBrowsingMode")
	static let reload = Self("reload")
	static let nextWebsite = Self("nextWebsite")
	static let previousWebsite = Self("previousWebsite")
	static let randomWebsite = Self("randomWebsite")
}

extension Notification.Name {
	static let showAddWebsiteDialog = Self("showAddWebsiteDialog")
	static let showEditWebsiteDialog = Self("showEditWebsiteDialog")
}
