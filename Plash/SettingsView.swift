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

	private static let reloadIntervalFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.formattingContext = .standalone
		formatter.locale = Locale.autoupdatingCurrent
		formatter.numberStyle = .decimal
		formatter.minimum = minimumReloadInterval as NSNumber
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 1
		formatter.isLenient = true
		return formatter
	}()

	@Default(.reloadInterval) private var reloadInterval

	private var reloadIntervalInMinutes: Binding<Double> {
		$reloadInterval.withDefaultValue(Self.defaultReloadInterval).secondsToMinutes
	}

	private var hasInterval: Binding<Bool> {
		$reloadInterval.isNotNil(trueSetValue: Self.defaultReloadInterval)
	}

	// TODO: Improve VoiceOver accessibility for this control.
	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text("Reload interval:")
				.fixedSize(horizontal: true, vertical: false)
			Toggle(isOn: hasInterval) {
				Stepper(
					value: reloadIntervalInMinutes,
					in: Self.minimumReloadInterval...(.greatestFiniteMagnitude),
					step: 1
				) {
					TextField(
						"",
						value: reloadIntervalInMinutes,
						formatter: Self.reloadIntervalFormatter
					)
						.frame(width: 70)
						.labelsHidden()
				}
					.disabled(!hasInterval.wrappedValue)
				Text("minutes")
					.padding(.leading, 4)
			}
				.accessibilityLabel("Reload interval in minutes")
		}
	}
}

private struct HideMenuBarIconSetting: View {
	@State private var isShowingAlert = false

	var body: some View {
		Defaults.Toggle("Hide menu bar icon", key: .hideMenuBarIcon)
			.onChange {
				isShowingAlert = $0
			}
			.alert2(isPresented: $isShowingAlert) {
				Alert(
					title: Text("If you need to access the Plash menu, launch the app again to reveal the menu bar icon for 5 seconds.")
				)
			}
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
			ForEach(displayWrapper.wrappedValue.all, id: \.self) { display in
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
		Button("Clear all website data") {
			Task {
				hasCleared = true
				WebsitesController.shared.thumbnailCache.removeAllImages()
				await appState.webViewController.webView.clearWebsiteData()
			}
		}
			.disabled(hasCleared)
			.help("Clears all cookies, local storage, caches, etc.")
			// TODO: Mark it as destructive when targeting macOS 12.
	}
}

private struct GeneralSettings: View {
	var body: some View {
		Form {
			VStack {
				VStack(alignment: .leading) {
					LaunchAtLogin.Toggle()
					ShowOnAllSpacesSetting()
					Defaults.Toggle("Deactivate while on battery", key: .deactivateOnBattery)
				}
					.padding()
					.padding(.horizontal)
				Divider()
				OpacitySetting()
					.padding()
					.padding(.horizontal)
				Divider()
				ReloadIntervalSetting()
					.padding()
					.padding(.horizontal)
			}
		}
			.padding(.vertical)
	}
}

private struct ShortcutsSettings: View {
	private let maxWidth = 160.0

	var body: some View {
		Form {
			VStack {
				HStack(alignment: .firstTextBaseline) {
					Text("Toggle browsing mode:")
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .toggleBrowsingMode)
				}
					.accessibilityElement(children: .combine)
				HStack(alignment: .firstTextBaseline) {
					Text("Reload website:")
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .reload)
				}
					.accessibilityElement(children: .combine)
				HStack(alignment: .firstTextBaseline) {
					Text("Next website:")
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .nextWebsite)
				}
					.accessibilityElement(children: .combine)
				HStack(alignment: .firstTextBaseline) {
					Text("Previous website:")
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .previousWebsite)
				}
					.accessibilityElement(children: .combine)
				HStack(alignment: .firstTextBaseline) {
					Text("Random website:")
						.frame(width: maxWidth, alignment: .trailing)
					KeyboardShortcuts.Recorder(for: .randomWebsite)
				}
					.accessibilityElement(children: .combine)
			}
		}
			.padding()
			.padding()
			.offset(x: -10)
	}
}

private struct AdvancedSettings: View {
	var body: some View {
		Form {
			VStack {
				VStack(alignment: .leading) {
					BringBrowsingModeToFrontSetting()
					OpenExternalLinksInBrowserSetting()
					HideMenuBarIconSetting()
					Defaults.Toggle("Mute audio", key: .muteAudio)
				}
					.padding()
					.padding(.horizontal)
				Divider()
				DisplaySetting()
					.padding()
					.padding(.horizontal)
				Divider()
				ClearWebsiteDataSetting()
					.padding()
					.padding(.horizontal)
			}
		}
			.padding(.vertical)
	}
}

struct SettingsView: View {
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
			.windowLevel(.modalPanel)
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
