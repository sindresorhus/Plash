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
