import SwiftUI
import Defaults

// TODO: Would be nice to preview the website while adding it. Then the user could try out the various settings.

struct AddWebsiteView: View {
	@Environment(\.presentationMode) private var presentationMode
	@State private var urlString = ""
	@State private var invertColors = false
	@State private var usePrintStyles = false
	@State private var css = ""
	@State private var javaScript = ""

	private var normalizedUrlString: String {
		URL(humanString: urlString)?.absoluteString ?? urlString
	}

	private var firstLaunchView: some View {
		HStack {
			HStack(spacing: 3) {
				Text("You could, for example,")
				Button("show the time.") {
					urlString = "https://time.pablopunk.com/?seconds&fg=white&bg=transparent"
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

	private let isEditing: Bool
	private let showsCancelButtons: Bool
	private let website: Website?
	private let completionHandler: () -> Void

	// TODO: Use some kind of `@Transaction` type.
	init(
		isEditing: Bool,
		showsCancelButtons: Bool,
		website: Website?,
		completionHandler: @escaping () -> Void
	) {
		self.isEditing = isEditing
		self.showsCancelButtons = showsCancelButtons
		self.website = website
		self.completionHandler = completionHandler

		if
			isEditing,
			let website = website
		{
			self._urlString = .init(wrappedValue: website.url.absoluteString.removingPercentEncoding ?? website.url.absoluteString)
			self._invertColors = .init(wrappedValue: website.invertColors)
			self._usePrintStyles = .init(wrappedValue: website.usePrintStyles)
			self._css = .init(wrappedValue: website.css)
			self._javaScript = .init(wrappedValue: website.javaScript)
		}
	}

	var body: some View {
		VStack(alignment: .leading) {
			if SSApp.isFirstLaunch {
				firstLaunchView
			}
			VStack(alignment: .leading) {
				HStack {
					TextField(
						"sindresorhus.com",
						// `removingNewlines` is a workaround for a SwiftUI bug where it doesn't respect the line limit when pasting in multiple lines.
						// TODO: Report to Apple. Still an issue on macOS 12.
						text: $urlString.setMap(\.removingNewlines)
					)
						.lineLimit(1)
						.padding(.vertical)
					Button("Local Website…") {
						chooseLocalWebsite {
							guard let url = $0 else {
								return
							}

							urlString = url.absoluteString
						}
					}
				}
				Divider()
					.padding(.vertical)
				// TODO: When targeting macOS 11, put all of this in a unexpanded `DisclosureGroup`.
				Toggle(
					"Invert colors",
					isOn: $invertColors
				)
					.help2("Creates a fake dark mode for websites without a native dark mode by inverting all the colors on the website.")
				if #available(macOS 11, *) {
					Toggle(
						"Use print styles",
						isOn: $usePrintStyles
					)
						.help2("Forces the website to use its print styles (“@media print”) if any. Some websites have a simpler presentation for printing, for example, Google Calendar.")
				}
				VStack(alignment: .leading) {
					HStack {
						Text("CSS:")
						Spacer()
						InfoPopoverButton("This lets you modify the website with CSS. You could, for example, change some colors or hide some unnecessary elements.")
							.controlSize(.small)
					}
					ScrollableTextView(
						text: $css,
						font: .monospacedSystemFont(ofSize: 11, weight: .regular),
						isAutomaticQuoteSubstitutionEnabled: false,
						isAutomaticDashSubstitutionEnabled: false,
						isAutomaticTextReplacementEnabled: false,
						isAutomaticSpellingCorrectionEnabled: false
					)
						.frame(height: 70)
				}
					.padding(.top, 10)
				VStack(alignment: .leading) {
					HStack {
						Text("JavaScript:")
						Spacer()
						InfoPopoverButton("This lets you modify the website with JavaScript. Prefer using CSS instead whenever possible. You can use “await” at the top-level.")
							.controlSize(.small)
					}
					ScrollableTextView(
						text: $javaScript,
						font: .monospacedSystemFont(ofSize: 11, weight: .regular),
						isAutomaticQuoteSubstitutionEnabled: false,
						isAutomaticDashSubstitutionEnabled: false,
						isAutomaticTextReplacementEnabled: false,
						isAutomaticSpellingCorrectionEnabled: false
					)
						.frame(height: 70)
				}
					.padding(.top, 10)
			}
				.padding()
			// TODO: Use `.toolbar()` when targeting macOS 11.
			// TODO: Use `Button` when targeting macOS 11.
			VStack {
				Divider()
				HStack {
					if showsCancelButtons {
						CocoaButton("Cancel", keyEquivalent: .escape) {
							presentationMode.wrappedValue.dismiss()
						}
					}
					Spacer()
					Group {
						if isEditing {
							CocoaButton("Save") {
								defaultAction(shouldClose: false)
							}
						}
						CocoaButton(isEditing ? "Save & Close" : "Add", keyEquivalent: .return) {
							defaultAction(shouldClose: true)
						}
					}
						.disabled(!URL.isValid(string: normalizedUrlString))
				}
					.padding()
					.offset(y: -9) // TODO: No idea why this is needed.
			}
		}
			.frame(width: 500)
	}

	private func defaultAction(shouldClose: Bool) {
		guard let url = URL(string: normalizedUrlString)?.normalized() else {
			return
		}

		// TODO: Find a way to DRY up this logic.
		if isEditing {
			if let website = website {
				WebsitesController.shared.all = WebsitesController.shared.all.modifying(elementWithID: website.id) {
					$0.url = url
					$0.invertColors = invertColors
					$0.usePrintStyles = usePrintStyles
					$0.css = css
					$0.javaScript = javaScript
				}
			} else {
				assertionFailure()
			}
		} else {
			let newWebsite = Website(
				id: UUID(),
				isCurrent: true,
				url: url,
				invertColors: invertColors,
				usePrintStyles: usePrintStyles,
				css: css,
				javaScript: javaScript
			)

			WebsitesController.shared.add(newWebsite)
		}

		if shouldClose {
			presentationMode.wrappedValue.dismiss()
			completionHandler()
		}
	}

	private func chooseLocalWebsite(_ completionHandler: @escaping (URL?) -> Void) {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.canCreateDirectories = false
		panel.title = "Choose Local Website"
		panel.message = "Choose a directory with a “index.html” file."
		panel.prompt = "Choose"

		// Ensure it's above the window when in "Browsing Mode".
		panel.level = .modalPanel

		if
			isEditing,
			let url = website?.url,
			url.isFileURL
		{
			panel.directoryURL = url
		}

		// TODO: Make it a sheet instead.
		panel.begin {
			guard
				$0 == .OK,
				let url = panel.url
			else {
				completionHandler(nil)
				return
			}

			guard url.appendingPathComponent("index.html", isDirectory: false).exists else {
				NSAlert.showModal(title: "Please choose a directory that contains a “index.html” file.")
				chooseLocalWebsite(completionHandler)
				return
			}

			do {
				try SecurityScopedBookmarkManager.saveBookmark(for: url)
			} catch {
				// TODO: Show the error in SwiftUI.
				NSApp.presentError(error)
				completionHandler(nil)
				return
			}

			completionHandler(url)
		}
	}
}

struct AddWebsiteView_Previews: PreviewProvider {
	static var previews: some View {
		AddWebsiteView(isEditing: false, showsCancelButtons: false, website: nil) {}
	}
}
