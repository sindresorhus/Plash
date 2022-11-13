import SwiftUI
import LaunchAtLogin

/*
TODO:
- Refactor the whole website handling into a controller.
- Fix TODO comments in the codebase.
- Fix "Edit Website" if it's not visible in the list. Use the new `Window` type in macOS 13.

TODO when targeting macOS 13:
- Focus filter support - set a certain website when in a specific focus.
	- Document it.
- Use SwiftUI for the websites window. We cannot do it until the window can be manually toggled.
- Upload non-App Store version.
- Change the list to open on click instead of right-click.
	- Also use `Foo.ID` instead of `Foo`.
	- $rules[id: selection]
	- Change the instruction about right-clicking.

TODO when Swift 6 is out:
- Convert all Combine usage to AsyncSequence.

TODO when targeting macOS 14:
= Use `MenuBarExtra`.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState.shared

	init() {
		LaunchAtLogin.migrateIfNeeded()
	}

	var body: some Scene {
		Settings {
			SettingsScreen()
				.environmentObject(appState)
		}
	}
}
