import SwiftUI
import Defaults

struct OpenURLView: View {
	@State private var urlString: String = {
		guard
			let url = Defaults[.url],
			!url.isFileURL
		else {
			return ""
		}

		return url.absoluteString.removingPercentEncoding ?? url.absoluteString
	}()

	// TODO: Do a `URL(humanString:)` extension.
	private var normalizedUrlString: String {
		let hasScheme = urlString.hasPrefix("https://") || urlString.hasPrefix("http://") || urlString.hasPrefix("file://")
		return hasScheme ? urlString : "http://\(urlString)"
	}

	let loadHandler: (URL) -> Void

	var body: some View {
		VStack(alignment: .trailing) {
			if App.isFirstLaunch {
				HStack {
					HStack(spacing: 3) {
						Text("You could, for example,")
						Button("show the time.") {
							self.urlString = "https://time.pablopunk.com/?seconds&fg=white&bg=transparent"
						}
							.buttonStyle(LinkButtonStyle())
					}
					Spacer()
					Button("More ideas") {
						"https://github.com/sindresorhus/Plash/issues/1".openUrl()
					}
						.buttonStyle(LinkButtonStyle())
				}
					.box()
			}
			TextField(
				"sindresorhus.com",
				// `removingNewlines` is a workaround for a SwiftUI bug where it doesn't respect the line limit when pasting in multiple lines.
				// TODO: Report to Apple.
				text: $urlString.setMap(\.removingNewlines)
			)
				.lineLimit(1)
				.frame(minWidth: 400)
				.padding(.vertical)
			NativeButton("Open", keyEquivalent: .return) {
				guard let url = URL(string: self.normalizedUrlString) else {
					return
				}

				self.loadHandler(url)
			}
				.disabled(!URL.isValid(string: normalizedUrlString))
		}
			.padding()
	}
}

struct OpenURLView_Previews: PreviewProvider {
	static var previews: some View {
		OpenURLView { _ in }
	}
}
