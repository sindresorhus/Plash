import SwiftUI
import LaunchAtLogin
import Defaults

private struct OpacityPreference: View {
	@ObservedObject private var opacity = Defaults.observable(.opacity)

	var body: some View {
		HStack {
			Text("Opacity:")
			Slider(value: $opacity.value, in: 0.1...1, step: 0.1)
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

	@ObservedObject private var reloadInterval = Defaults.observable(.reloadInterval)

	private var reloadIntervalInMinutes: Binding<Double> {
		$reloadInterval.value.withDefaultValue(Self.defaultReloadInterval).map(
			get: { $0 / 60 },
			set: { $0 * 60 }
		)
	}

	private var hasInterval: Binding<Bool> {
		$reloadInterval.value.isNotNil(trueSetValue: Self.defaultReloadInterval)
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
	@ObservedObject private var deactivateOnBattery = Defaults.observable(.deactivateOnBattery)

	var body: some View {
		Toggle(
			"Deactivate While on Battery",
			isOn: $deactivateOnBattery.value
		)
	}
}

private struct ShowOnAllSpacesPreference: View {
	@ObservedObject private var showOnAllSpaces = Defaults.observable(.showOnAllSpaces)

	var body: some View {
		Toggle(
			"Show on All Spaces",
			isOn: $showOnAllSpaces.value
		)
			.tooltip("When disabled, the website will be shown on the space that was active when Plash launched.")
	}
}

private struct InvertColorsPreference: View {
	@ObservedObject private var invertColors = Defaults.observable(.invertColors)

	var body: some View {
		VStack {
			Toggle(
				"Invert Website Colors",
				isOn: $invertColors.value
			)
				.tooltip("This creates a fake dark mode.")
		}
	}
}

private struct DisplayPreference: View {
	@ObservedObject private var displayWrapper = Display.observable
	@ObservedObject private var chosenDisplay = Defaults.observable(.display)

	var body: some View {
		Picker(
			"Show On Display:",
			selection: $chosenDisplay.value.getMap { $0.withFallbackToMain }
		) {
			ForEach(displayWrapper.wrappedValue.all, id: \.self) { display in
				Text(display.localizedName)
					.tag(display)
			}
		}
	}
}

private struct CustomCSSPreference: View {
	@ObservedObject private var customCSS = Defaults.observable(.customCSS)

	var body: some View {
		VStack {
			Text("Custom CSS:")
			ScrollableTextView(
				text: $customCSS.value,
				font: .monospacedSystemFont(ofSize: 11, weight: .regular)
			)
				.frame(height: 100)
		}
	}
}

private struct ClearWebsiteDataPreference: View {
	var body: some View {
		Button("Clear Website Data") {
			AppDelegate.shared.webViewController.webView.clearWebsiteData()
		}
			.tooltip("Clears all cookies, local storage, caches, etc.")
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
				CustomCSSPreference()
				Divider()
					.padding(.vertical)
				ClearWebsiteDataPreference()
			}
		}
			.frame(width: 340)
			.padding()
			.padding()
	}
}

struct PreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		PreferencesView()
	}
}
