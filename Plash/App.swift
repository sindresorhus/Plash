import SwiftUI

/**
TODO macOS 14:
- Use SwiftUI for the desktop window and the web view.
- Use `MenuBarExtra`
- Remove `Combine` and `Defaults.publisher` usage.
- Focus filter support.
- Use `EnvironmentValues#requestReview`.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared

	init() {
		setUpConfig()
	}

	var body: some Scene {
		Window("Websites", id: "websites") {
			WebsitesScreen()
				.environmentObject(appState)
		}
			.windowToolbarStyle(.unifiedCompact)
			.windowResizability(.contentSize)
			.defaultPosition(.center)
		Settings {
			SettingsScreen()
				.environmentObject(appState)
		}
	}

	private func setUpConfig() {
		UserDefaults.standard.register(defaults: [
			"NSApplicationCrashOnExceptions": true
		])

		SSApp.initSentry("https://4ad446a4961b44ff8dc808a08379914e@o844094.ingest.sentry.io/6140750")
	}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationWillFinishLaunching(_ notification: Notification) {
		// It's important that this is here so it's registered in time.
		AppState.shared.setUpURLCommands()
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		Constants.websitesWindow?.close()
	}

	// This is only run when the app is started when it's already running.
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		AppState.shared.handleAppReopen()
		return false
	}
}
