import SwiftUI

/*
TODO:
- Refactor the whole website handling into a controller.
- Fix TODO comments in the codebase.

TODO when targeting macOS 13:
- Use SwiftUI for the websites window. We cannot do it until the window can be manually toggled.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared

	var body: some Scene {
		// This is needed for standard keyboard shortcuts to work in text fields. (macOS 12.1)
		WindowGroup {
			if false {}
		}
		Settings {
			SettingsView()
				.environmentObject(appState)
		}
	}
}
