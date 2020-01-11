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

private struct DisplayPreference: View {
	@ObservedObject private var displayWrapper = Display.observable
	@ObservedObject private var chosenDisplay = Defaults.observable(.display)

	var body: some View {
		Picker(
			"Show On Display:",
			selection: $chosenDisplay.value.getMap { $0.withFallback }
		) {
			ForEach(displayWrapper.wrappedValue.all, id: \.self) { display in
				Text(display.localizedName)
					.tag(display)
			}
		}
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
			Text("(Fake dark mode)")
				.font(.system(size: 10))
				.foregroundColor(.secondary)
		}
	}
}

struct PreferencesView: View {
	var body: some View {
		VStack {
			LaunchAtLogin.Toggle()
			Divider()
				.padding(.vertical)
			OpacityPreference()
			Divider()
				.padding(.vertical)
			ReloadIntervalPreference()
			Divider()
				.padding(.vertical)
			DisplayPreference()
			Divider()
				.padding(.vertical)
			InvertColorsPreference()
		}
			.frame(width: 300)
			.padding()
			.padding()
	}
}

struct PreferencesView_Previews: PreviewProvider {
	static var previews: some View {
		PreferencesView()
	}
}
