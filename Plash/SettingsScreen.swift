import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

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
			.formStyle(.grouped)
			.frame(width: 400)
			.fixedSize()
			.windowLevel(.floating + 1) // To ensure it's always above the Plash browser window.
	}
}

private struct GeneralSettings: View {
	var body: some View {
		Form {
			Section {
				LaunchAtLogin.Toggle()
			}
			Section {
				ReloadIntervalSetting()
				OpacitySetting()
			}
			Section {
				DisplaySetting()
				ShowOnAllSpacesSetting()
			}
		}
	}
}

private struct ShortcutsSettings: View {
	private let maxWidth = 160.0

	var body: some View {
		Form {
			KeyboardShortcuts.Recorder("Toggle enabled state", name: .toggleEnabled)
			KeyboardShortcuts.Recorder("Toggle browsing mode", name: .toggleBrowsingMode)
			KeyboardShortcuts.Recorder("Reload website", name: .reload)
			KeyboardShortcuts.Recorder("Next website", name: .nextWebsite)
			KeyboardShortcuts.Recorder("Previous website", name: .previousWebsite)
			KeyboardShortcuts.Recorder("Random website", name: .randomWebsite)
		}
	}
}

private struct AdvancedSettings: View {
	var body: some View {
		Form {
			Section {
				BringBrowsingModeToFrontSetting()
				Defaults.Toggle("Deactivate while on battery", key: .deactivateOnBattery)
				OpenExternalLinksInBrowserSetting()
				HideMenuBarIconSetting()
				Defaults.Toggle("Mute audio", key: .muteAudio)
			}
			Section {} // Padding
			Section {} footer: {
				ClearWebsiteDataSetting()
					.controlSize(.small)
			}
		}
	}
}

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
			Text("Opacity")
		}
			.help("Browsing mode always uses full opacity.")
	}
}

private struct ReloadIntervalSetting: View {
	private static let defaultReloadInterval = 60.0
	private static let minimumReloadInterval = 0.1

	@Default(.reloadInterval) private var reloadInterval
	@FocusState private var isTextFieldFocused: Bool

	// TODO: Improve VoiceOver accessibility for this control.
	var body: some View {
		LabeledContent("Reload every") {
			HStack {
				TextField(
					"",
					value: reloadIntervalInMinutes,
					format: .number.grouping(.never).precision(.fractionLength(1))
				)
					.labelsHidden()
					.focused($isTextFieldFocused)
					.frame(width: 40)
					.disabled(reloadInterval == nil)
				Stepper(
					"",
					value: reloadIntervalInMinutes.didSet { _ in
						// We have to unfocus the text field because sometimes it's in a state where it does not update the value. Some kind of bug with the formatter. (macOS 12.4)
						isTextFieldFocused = false
					},
					in: Self.minimumReloadInterval...(.greatestFiniteMagnitude),
					step: 1
				)
					.labelsHidden()
					.disabled(reloadInterval == nil)
				Text("minutes")
					.textSelection(.disabled)
			}
				.contentShape(.rect)
			Toggle("Reload every", isOn: $reloadInterval.isNotNil(trueSetValue: Self.defaultReloadInterval))
				.labelsHidden()
				.controlSize(.mini)
				.toggleStyle(.switch)
		}
			.accessibilityLabel("Reload interval in minutes")
			.contentShape(.rect)
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
			"Show on",
			selection: $chosenDisplay.getMap(\.?.withFallbackToMain)
		) {
			ForEach(displayWrapper.wrappedValue.all) { display in
				Text(display.localizedName)
					.tag(display as Display?)
					// A view cannot have multiple tags, otherwise, this would have been the best solution.
//					.if(display == .main) {
//						$0.tag(nil as Display?)
//					}
			}
		}
			.task(id: chosenDisplay) {
				guard chosenDisplay == nil else {
					return
				}

				chosenDisplay = .main
			}
	}
}

private struct ClearWebsiteDataSetting: View {
	@State private var hasCleared = false

	var body: some View {
		Button("Clear all website data", role: .destructive) {
			Task {
				hasCleared = true
				WebsitesController.shared.thumbnailCache.removeAllImages()
				await AppState.shared.webViewController.webView.clearWebsiteData()
			}
		}
			.help("Clears all cookies, local storage, caches, etc.")
			.disabled(hasCleared)
	}
}

#Preview {
	SettingsScreen()
}
