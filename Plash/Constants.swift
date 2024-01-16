import SwiftUI
import KeyboardShortcuts

enum Constants {
	static var websitesWindow: NSWindow? {
		NSApp.windows.first { $0.identifier?.rawValue == "websites" }
	}

	static func openWebsitesWindow() {
		SSApp.forceActivate()
		websitesWindow?.makeKeyAndOrderFront(nil)
	}
}

extension Defaults.Keys {
	static let websites = Key<[Website]>("websites", default: [])
	static let isBrowsingMode = Key<Bool>("isBrowsingMode", default: false)

	// Settings
	static let hideMenuBarIcon = Key<Bool>("hideMenuBarIcon", default: false)
	static let opacity = Key<Double>("opacity", default: 1)
	static let reloadInterval = Key<Double?>("reloadInterval")
	static let display = Key<Display?>("display")
	static let deactivateOnBattery = Key<Bool>("deactivateOnBattery", default: false)
	static let showOnAllSpaces = Key<Bool>("showOnAllSpaces", default: false)
	static let bringBrowsingModeToFront = Key<Bool>("bringBrowsingModeToFront", default: false)
	static let openExternalLinksInBrowser = Key<Bool>("openExternalLinksInBrowser", default: false)
	static let muteAudio = Key<Bool>("muteAudio", default: true)

	static let extendPlashBelowMenuBar = Key<Bool>("extendPlashBelowMenuBar", default: false)
}

extension KeyboardShortcuts.Name {
	static let toggleBrowsingMode = Self("toggleBrowsingMode")
	static let toggleEnabled = Self("toggleEnabled")
	static let reload = Self("reload")
	static let nextWebsite = Self("nextWebsite")
	static let previousWebsite = Self("previousWebsite")
	static let randomWebsite = Self("randomWebsite")
}

extension Notification.Name {
	static let showAddWebsiteDialog = Self("showAddWebsiteDialog")
	static let showEditWebsiteDialog = Self("showEditWebsiteDialog")
}
