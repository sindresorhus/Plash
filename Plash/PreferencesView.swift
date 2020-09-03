import SwiftUI
import LaunchAtLogin
import Defaults
import KeyboardShortcuts

private struct OpacityPreference: View {
	@Default(.opacity) private var opacity

	var body: some View {
		HStack {
			Text("Opacity:")
			Slider(value: $opacity, in: 0.1...1, step: 0.1)
		}
	}
}

private struct ReloadIntervalPreference: View {
	private static let defaultReloadInterval = 60.0
	private static let minimumReloadInterval = 0.1

	private static let reloadIntervalFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.formattingContext = .standalone
		formatter.locale = Locale.autoupdatingCurrent
		formatter.numberStyle = .decimal
		formatter.minimum = NSNumber(value: minimumReloadInterval)
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

	var body: some View {
		HStack {
			Text("Reload Interval:")
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
				}
					.disabled(!hasInterval.wrappedValue)
				Text("minutes")
			}
				.fixedSize()
		}
	}
}

private struct DeactivateOnBatteryPreference: View {
	@Default(.deactivateOnBattery) private var deactivateOnBattery

	var body: some View {
		Toggle(
			"Deactivate While on Battery",
			isOn: $deactivateOnBattery
		)
	}
}

private struct ShowOnAllSpacesPreference: View {
	@Default(.showOnAllSpaces) private var showOnAllSpaces

	var body: some View {
		Toggle(
			"Show on All Spaces",
			isOn: $showOnAllSpaces
		)
			.help2("When disabled, the website will be shown on the space that was active when Plash launched.")
	}
}

private struct InvertColorsPreference: View {
	@Default(.invertColors) private var invertColors

	var body: some View {
		VStack {
			Toggle(
				"Invert Website Colors",
				isOn: $invertColors
			)
				.help2("This creates a fake dark mode.")
		}
	}
}

private struct DisplayPreference: View {
	@ObservedObject private var displayWrapper = Display.observable
	@Default(.display) private var chosenDisplay

	var body: some View {
		Picker(
			"Show On Display:",
			selection: $chosenDisplay.getMap(\.withFallbackToMain)
		) {
			ForEach(displayWrapper.wrappedValue.all, id: \.self) { display in
				Text(display.localizedName)
					.tag(display)
			}
		}
	}
}

private struct KeyboardShortcutsSection: View {
	private let maxWidth: CGFloat = 160

	var body: some View {
		VStack {
			HStack {
				Text("Toggle “Browsing Mode”:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .toggleBrowsingMode)
			}
			HStack {
				Text("Reload:")
					.frame(width: maxWidth, alignment: .trailing)
				KeyboardShortcuts.Recorder(for: .reload)
			}
		}
	}
}

private struct CustomCSSPreference: View {
	@Default(.customCSS) private var customCSS

	var body: some View {
		VStack {
			Text("Custom CSS:")
			ScrollableTextView(
				text: $customCSS,
				font: .monospacedSystemFont(ofSize: 11, weight: .regular)
			)
				.frame(height: 100)
		}
	}
}

private struct ClearWebsiteDataPreference: View {
	@State private var hasCleared = false

	var body: some View {
		Button("Clear Website Data") {
			self.hasCleared = true
			AppDelegate.shared.webViewController.webView.clearWebsiteData(completion: nil)
		}
			.disabled(hasCleared)
			.help2("Clears all cookies, local storage, caches, etc.")
	}
}

struct PreferencesView: View {
	var body: some View {
		VStack {
			VStack(alignment: .leading) {
				LaunchAtLogin.Toggle()
				DeactivateOnBatteryPreference()
				ShowOnAllSpacesPreference()
				InvertColorsPreference()
			}
			Divider()
				.padding(.vertical)
			OpacityPreference()
			Divider()
				.padding(.vertical)
			ReloadIntervalPreference()
			Divider()
				.padding(.vertical)
			// Work around 10 view limit.
			Group {
				DisplayPreference()
				Divider()
					.padding(.vertical)
				KeyboardShortcutsSection()
				Divider()
					.padding(.vertical)
				CustomCSSPreference()
				Divider()
					.padding(.vertical)
				ClearWebsiteDataPreference()
			}
		}
			.frame(width: 380)
			.padding()
			.padding()
	}
}

struct PreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		PreferencesView()
	}
}
