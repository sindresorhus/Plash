import WebKit
import Defaults

final class SSWebView: WKWebView {
	private var excludedMenuItems: Set<MenuItemIdentifier> = [
		.downloadImage,
		.downloadLinkedFile,
		.downloadMedia,
		.openLinkInNewWindow,
		.shareMenu,
		.toggleEnhancedFullScreen,
		.toggleFullScreen
	]

	override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
		for menuItem in menu.items {
			// Debug menu items
			// print("Menu Item:", menuItem.title, menuItem.identifier?.rawValue ?? "")

			if let identifier = MenuItemIdentifier(menuItem) {
				if
					identifier == .openImageInNewWindow,
					menuItem.title == "Open Image in New Window"
				{
					menuItem.title = "Open Image"
				}

				if
					identifier == .openMediaInNewWindow,
					menuItem.title == "Open Video in New Window"
				{
					menuItem.title = "Open Video"
				}

				if
					identifier == .openFrameInNewWindow,
					menuItem.title == "Open Frame in New Window"
				{
					menuItem.title = "Open Frame"
				}

				if
					identifier == .openLinkInNewWindow,
					menuItem.title == "Open Link in New Window"
				{
					menuItem.title = "Open Link"
				}
			}
		}

		menu.items.removeAll {
			guard let identifier = MenuItemIdentifier($0) else {
				return false
			}

			return excludedMenuItems.contains(identifier)
		}

		menu.addSeparator()

		menu.addCallbackItem("Actual Size", isEnabled: zoomLevel != 1) { _ in
			self.zoomLevelWrapper = 1
		}

		menu.addCallbackItem("Zoom In") { _ in
			self.zoomLevelWrapper += 0.2
		}

		menu.addCallbackItem("Zoom Out") { _ in
			self.zoomLevelWrapper -= 0.2
		}

		// Move the “Inspect Element” menu item to the end.
		if let menuItem = (menu.items.first { MenuItemIdentifier($0) == .inspectElement }) {
			menu.addSeparator()
			menu.items = menu.items.movingToEnd(menuItem)
		}

		// For the implicit “Services” menu.
		menu.addSeparator()
	}
}

extension SSWebView {
	// TODO: Use https://developer.apple.com/documentation/webkit/wkwebview/3516411-pagezoom instead when macOS 10.15.4 is out.
	private var zoomLevelDefaultsKey: Defaults.Key<Double?>? {
		guard let url = self.url?.normalized(removeFragment: true, removeQuery: true) else {
			return nil
		}

		return .init("zoomLevel_\(url)")
	}

	var zoomLevelDefaultsValue: Double? {
		guard
			let zoomLevelDefaultsKey = self.zoomLevelDefaultsKey,
			let zoomLevel = Defaults[zoomLevelDefaultsKey]
		else {
			return nil
		}

		return zoomLevel
	}

	var zoomLevelWrapper: Double {
		get { zoomLevelDefaultsValue ?? zoomLevel }
		set {
			zoomLevel = newValue

			if let zoomDefaultsKey = self.zoomLevelDefaultsKey {
				Defaults[zoomDefaultsKey] = newValue
			}
		}
	}
}
