import SwiftUI
import LaunchAtLogin
import Defaults
import KeyboardShortcuts

private struct ShowOnAllSpacesSetting: View {
	var body: some View {
		Defaults.Toggle(
			"Show on all spaces",
			key: .showOnAllSpaces
		)
			.help("While disabled, Plash will display the website on the space that is active at launch.")
	}
}

private struct BringBrowsingModeToFrontSetting: View {
	var body: some View {
		// TODO: Find a better title for this.
		Defaults.Toggle(
			"Bring browsing mode to the front",
			key: .bringBrowsingModeToFront
		)
			.help("Keep the website above all other windows while browsing mode is active.")
	}
}

private struct OpenExternalLinksInBrowserSetting: View {
	var body: some View {
		Defaults.Toggle(
			"Open external links in default browser",
			key: .openExternalLinksInBrowser
		)
			.help("If a website requires login, you should disable this setting while logging in as the website might require you to navigate to a different page, and you don't want that to open in a browser instead of Plash.")
	}
}

private struct OpacitySetting: View {
	@Default(.opacity) private var opacity

	var body: some View {
		Slider(
			value: $opacity,
			in: 0.1...1,
			step: 0.1
		) {
			Text("Opacity:")
		}
			.help("Browsing mode always uses full opacity.")
	}
}


private struct ReloadIntervalSetting: View {
	private static let defaultReloadInterval = 60.0
	private static let minimumReloadInterval = 0.1

	@Default(.reloadInterval) private var reloadInterval
	@FocusState private var isTextFieldFocused: Bool
	@State private var isEnabled = Defaults[.reloadInterval] != nil

	// TODO: Improve VoiceOver accessibility for this control.
	var body: some View {
		HStack {
			Toggle("Reload every", isOn: $isEnabled)
			Stepper(
				value: reloadIntervalInMinutes.didSet { _ in
					// We have to unfocus the text field because sometimes it's in a state where it does not update the value. Some kind of bug with the formatter. (macOS 12.4)
					isTextFieldFocused = false
				},
				in: Self.minimumReloadInterval...(.greatestFiniteMagnitude),
				step: 1
			) {
				TextField(
					"",
					value: reloadIntervalInMinutes,
					format: .number.grouping(.never).precision(.fractionLength(1))
				)
					.focused($isTextFieldFocused)
					.frame(width: 40)
					.labelsHidden()
					.padding(.trailing, -6)
			}
				.disabled(!isEnabled)
				.contentShape(.rectangle)
				.onTapGesture {
					isEnabled = true
				}
			Text("minutes")
		}
			.accessibilityLabel("Reload interval in minutes")
			.contentShape(.rectangle)
			.onChange(of: isEnabled) {
				reloadInterval = $0 ? Self.defaultReloadInterval : nil
			}
	}

	private var reloadIntervalInMinutes: Binding<Double> {
		$reloadInterval.withDefaultValue(Self.defaultReloadInterval).secondsToMinutes
	}

	// TODO: We don't use this binding as it causes the toggle to not always work because of some weirdities with the formatter. (macOS 12.4)
//	private var hasInterval: Binding<Bool> {
//		$reloadInterval.isNotNil(trueSetValue: Self.defaultReloadInterval)
//	}
}

private struct HideMenuBarIconSetting: View {
	@State private var isShowingAlert = false

	var body: some View {
		Defaults.Toggle("Hide menu bar icon", key: .hideMenuBarIcon)
			.onChange {
				isShowingAlert = $0
			}
			.alert2(
				"If you need to access the Plash menu, launch the app again to reveal the menu bar icon for 5 seconds.",
				isPresented: $isShowingAlert
			)
	}
}

private struct DisplaySetting: View {
	@ObservedObject private var displayWrapper = Display.observable
	@Default(.display) private var chosenDisplay

	var body: some View {
		Picker(
			"Show on display:",
			selection: $chosenDisplay.getMap(\.withFallbackToMain)
		) {
			ForEach(displayWrapper.wrappedValue.all) { display in
				Text(display.localizedName)
					.tag(display)
			}
		}
	}
}

private struct ClearWebsiteDataSetting: View {
	@EnvironmentObject private var appState: AppState
	@State private var hasCleared = false

	var body: some View {
		Button("Clear all website data", role: .destructive) {
			Task {
				hasCleared = true
				WebsitesController.shared.thumbnailCache.removeAllImages()
				await appState.webViewController.webView.clearWebsiteData()
			}
		}
			.help("Clears all cookies, local storage, caches, etc.")
			.disabled(hasCleared)
	}
}

private struct GeneralSettings: View {
	var body: some View {
		VStack(alignment: .leading) {
			VStack(alignment: .leading) {
				LaunchAtLogin.Toggle()
				ShowOnAllSpacesSetting()
				Defaults.Toggle("Deactivate while on battery", key: .deactivateOnBattery)
				ReloadIntervalSetting()
			}
				.padding()
				.padding(.horizontal)
			Divider()
			OpacitySetting()
				.padding()
				.padding(.horizontal)
		}
			.padding(.vertical)
	}
}

private struct ShortcutsSettings: View {
	private let maxWidth = 160.0

	var body: some View {
		Form {
			KeyboardShortcuts.Recorder("Toggle browsing mode:", name: .toggleBrowsingMode)
				.fixedSize()
			KeyboardShortcuts.Recorder("Reload website:", name: .reload)
			KeyboardShortcuts.Recorder("Next website:", name: .nextWebsite)
			KeyboardShortcuts.Recorder("Previous website:", name: .previousWebsite)
			KeyboardShortcuts.Recorder("Random website:", name: .randomWebsite)
		}
			.padding()
			.padding()
			.offset(x: -10)
	}
}

private struct AdvancedSettings: View {
	var body: some View {
		VStack {
			Form {
				BringBrowsingModeToFrontSetting()
				OpenExternalLinksInBrowserSetting()
				HideMenuBarIconSetting()
				Defaults.Toggle("Mute audio", key: .muteAudio)
			}
				.padding()
				.padding(.horizontal)
				.fillFrame(.horizontal, alignment: .leading)
			Divider()
			DisplaySetting()
				.padding()
				.padding(.horizontal)
			Divider()
			ClearWebsiteDataSetting()
				.padding()
				.padding(.horizontal)
		}
			.padding(.vertical)
	}
}

struct SettingsScreen: View {
	var body: some View {
		TabView {
			GeneralSettings()
				.settingsTabItem(.general)
			ShortcutsSettings()
				.settingsTabItem(.shortcuts)
			AdvancedSettings()
				.settingsTabItem(.advanced)
		}
			.frame(width: 340)
			.windowLevel(.floating)
	}
}

struct SettingsScreen_Previews: PreviewProvider {
	static var previews: some View {
		SettingsScreen()
	}
}
