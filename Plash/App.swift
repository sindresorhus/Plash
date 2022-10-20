import SwiftUI

/*
TODO:
- Refactor the whole website handling into a controller.
- Fix TODO comments in the codebase.
- Fix "Edit Website" if it's not visible in the list. Use the new `Window` type in macOS 13.

TODO when targeting macOS 13:
- Use SwiftUI for the websites window. We cannot do it until the window can be manually toggled.

TODO when Swift 6 is out:
- Convert all Combine usage to AsyncSequence.

TODO when targeting macOS 13:
= Use `MenuBarExtra`.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared

	var body: some Scene {
		Settings {
			SettingsScreen()
				.environmentObject(appState)
		}
	}
}
