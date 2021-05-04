import SwiftUI
import Combine
import LinkPresentation
import Defaults

struct AddWebsiteView: View {
	@Environment(\.presentationMode) private var presentationMode
	@State private var urlString = ""
	@State private var title = ""
	@State private var invertColors = false
	@State private var usePrintStyles = false
	@State private var css = ""
	@State private var javaScript = ""
	@State private var isFetchingTitle = false

	// TODO: Remove these when targeting macOS 11.
	@State private var urlStringPublisher = PassthroughSubject<Void, Never>()
	@State private var publisher = MutableBox<AnyPublisher<Void, Never>?>()

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
			Link2("More ideas", destination: "https://github.com/sindresorhus/Plash/issues/1")
				.buttonStyle(LinkButtonStyle())
		}
			.box()
	}

	private let isEditing: Bool

	// TODO: `@OptionalBinding` extension?
	private var website: Binding<Website>?

	// TODO: Use some kind of `@Transaction` type.
	init(
		isEditing: Bool,
		website: Binding<Website>?
	) {
		self.isEditing = isEditing
		self.website = website

		if
			isEditing,
			let website = website?.wrappedValue
		{
			self._urlString = .init(wrappedValue: website.url.absoluteString.removingPercentEncoding ?? website.url.absoluteString)
			self._title = .init(wrappedValue: website.title)
			self._invertColors = .init(wrappedValue: website.invertColors)
			self._usePrintStyles = .init(wrappedValue: website.usePrintStyles)
			self._css = .init(wrappedValue: website.css)
			self._javaScript = .init(wrappedValue: website.javaScript)
		}

		// TODO: Remove this when targeting macOS 11.
		publisher.wrappedValue = urlStringPublisher
			.debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
			.eraseToAnyPublisher()
	}

	@ViewBuilder
	private var editing: some View {
		Divider()
			.padding(.vertical)
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

	var body: some View {
		VStack(alignment: .leading) {
			if SSApp.isFirstLaunch {
				firstLaunchView
			}
			VStack(alignment: .leading) {
				HStack {
					TextField(
						"twitter.com",
						// TODO: Remove `.onChange` when targeting macOS 11.
						// `removingNewlines` is a workaround for a SwiftUI bug where it doesn't respect the line limit when pasting in multiple lines.
						// TODO: Report to Apple. Still an issue on macOS 12.
						text: $urlString.setMap(\.removingNewlines).onChange { _ in
							urlStringPublisher.send()
						}
					)
						.textFieldStyle(RoundedBorderTextFieldStyle())
						// TODO: When targeting macOS 11.
						// .controlSize(.large)
						.lineLimit(1)
						.padding(.vertical)
						.modify {
							guard #available(macOS 11, *) else {
								guard let publisher = publisher.wrappedValue else {
									return nil
								}

								return $0.onReceive(publisher) { _ in
									fetchTitle()
								}
									.eraseToAnyView()
							}

							return $0.onChangeDebounced(of: urlString, dueTime: 0.5) { _ in
								fetchTitle()
							}
								.eraseToAnyView()
						}
					Button("Local Website…") {
						chooseLocalWebsite {
							guard let url = $0 else {
								return
							}

							urlString = url.absoluteString
						}
					}
				}
				TextField(
					"Title",
					// `removingNewlines` is a workaround for a SwiftUI bug where it doesn't respect the line limit when pasting in multiple lines.
					text: $title.setMap(\.removingNewlines)
				)
					.textFieldStyle(RoundedBorderTextFieldStyle())
					.lineLimit(1)
					.disabled(isFetchingTitle)
					.overlay(
						Group {
							if #available(macOS 11, *), isFetchingTitle {
								ProgressView()
									.controlSize(.small)
									.offset(x: -4)
							}
						},
						alignment: .trailing
					)
				if isEditing {
					editing
				}
			}
				.padding()
			// TODO: Use `.toolbar()` when targeting macOS 11.
			// TODO: Use `Button` when targeting macOS 11.
			VStack {
				Divider()
				HStack {
					CocoaButton("Cancel", keyEquivalent: .escape) {
						presentationMode.wrappedValue.dismiss()
					}
					Spacer()
					Group {
						if isEditing {
							CocoaButton("Save") {
								save(shouldClose: false)
							}
							CocoaButton("Save & Close", keyEquivalent: .return) {
								save(shouldClose: true)
							}
						} else {
							CocoaButton("Add", keyEquivalent: .return) {
								add()
							}
						}
					}
						.disabled(!URL.isValid(string: normalizedUrlString) || isFetchingTitle)
				}
					.padding()
					.offset(y: -9) // TODO: No idea why this is needed.
			}
		}
			.frame(width: 500)
	}

	private func add() {
		guard let url = URL(string: normalizedUrlString)?.normalized() else {
			return
		}

		WebsitesController.shared.add(
			.init(
				id: UUID(),
				isCurrent: true,
				url: url,
				title: .init(wrappedValue: title),
				invertColors: invertColors,
				usePrintStyles: usePrintStyles,
				css: css,
				javaScript: javaScript
			)
		)

		presentationMode.wrappedValue.dismiss()
	}

	private func save(shouldClose: Bool) {
		guard
			let url = URL(string: normalizedUrlString)?.normalized(),
			var website = website?.wrappedValue
		else {
			assertionFailure()
			return
		}

		website.url = url
		website.title = title
		website.invertColors = invertColors
		website.usePrintStyles = usePrintStyles
		website.css = css
		website.javaScript = javaScript

		self.website?.wrappedValue = website

		if shouldClose {
			presentationMode.wrappedValue.dismiss()
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
			let url = website?.wrappedValue.url,
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

	private func fetchTitle() {
		// Ensure we don't erase a user's existing title.
		if
			isEditing,
			let website = website,
			!website.title.wrappedValue.isEmpty
		{
			return
		}

		guard
			urlString.contains(".") || urlString.hasPrefix("file://"),
			URL.isValid(string: normalizedUrlString),
			let url = URL(string: normalizedUrlString)
		else {
			title = ""
			return
		}

		withAnimation {
			isFetchingTitle = true
		}

		LPMetadataProvider().startFetchingMetadata(for: url) { metadata, error in
			withAnimation {
				isFetchingTitle = false
			}

			guard
				error == nil,
				let title = metadata?.title
			else {
				return
			}

			DispatchQueue.main.async {
				self.title = title
			}
		}
	}
}

struct AddWebsiteView_Previews: PreviewProvider {
	static var previews: some View {
		AddWebsiteView(
			isEditing: false,
			website: nil
		)
	}
}
