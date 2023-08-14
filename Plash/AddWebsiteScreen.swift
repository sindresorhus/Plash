import SwiftUI
import LinkPresentation

struct AddWebsiteScreen: View {
	@Environment(\.dismiss) private var dismiss
	@State private var hostingWindow: NSWindow?
	@State private var isFetchingTitle = false
	@State private var isApplyConfirmationPresented = false
	@State private var originalWebsite: Website?
	@State private var urlString = ""

	@State private var newWebsite = Website(
		id: UUID(),
		isCurrent: true,
		url: ".",
		usePrintStyles: false
	)

	private var isURLValid: Bool {
		URL.isValid(string: urlString)
			&& website.wrappedValue.url.isValid
	}

	private var hasChanges: Bool { website.wrappedValue != originalWebsite }

	private let isEditing: Bool

	// TODO: `@OptionalBinding` extension?
	private var existingWebsite: Binding<Website>?

	private var website: Binding<Website> { existingWebsite ?? $newWebsite }

	init(
		isEditing: Bool,
		website: Binding<Website>?
	) {
		self.isEditing = isEditing
		self.existingWebsite = website
		self._originalWebsite = .init(wrappedValue: website?.wrappedValue)

		if isEditing {
			self._urlString = .init(wrappedValue: website?.wrappedValue.url.absoluteString ?? "")
		}
	}

	var body: some View {
		Form {
			topView
			if SSApp.isFirstLaunch, !isEditing {
				firstLaunchView
			}
			if isEditing {
				editingView
			}
		}
			.formStyle(.grouped)
			.frame(width: 500)
			.fixedSize()
			.bindHostingWindow($hostingWindow)
			// Note: Current only works when a text field is focused. (macOS 11.3)
			.onExitCommand {
				guard isEditing, hasChanges else {
					dismiss()
					return
				}

				isApplyConfirmationPresented = true
			}
			.onSubmit {
				submit()
			}
			.confirmationDialog2(
				"Keep changes?",
				isPresented: $isApplyConfirmationPresented
			) {
				Button("Keep") {
					dismiss()
				}
				Button("Don't Keep", role: .destructive) {
					revert()
					dismiss()
				}
				Button("Cancel", role: .cancel) {}
			}
			.toolbar {
				if isEditing {
					ToolbarItem {
						Button("Revert") {
							revert()
						}
							.disabled(!hasChanges)
					}
				} else {
					ToolbarItem(placement: .cancellationAction) {
						Button("Cancel") {
							dismiss()
						}
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditing ? "Done" : "Add") {
						submit()
					}
						.disabled(!isURLValid)
				}
			}
			.task {
				guard isEditing else {
					return
				}

				website.wrappedValue.makeCurrent()
			}
	}

	private var firstLaunchView: some View {
		Section {
			HStack {
				HStack(spacing: 3) {
					Text("You could, for example,")
					Button("show the time.") {
						urlString = "https://time.pablopunk.com/?seconds&fg=white&bg=transparent"
					}
						.buttonStyle(.link)
				}
				Spacer()
				Link("More ideas", destination: "https://github.com/sindresorhus/Plash/discussions/136")
					.buttonStyle(.link)
			}
		}
	}

	private var topView: some View {
		Section {
			TextField("URL", text: $urlString)
				.lineLimit(1)
				// This change listener is used to respond to URL changes from the outside, like the "Revert" button or the Shortcuts actions.
				.onChange(of: website.wrappedValue.url) {
					guard
						$0.absoluteString != "-",
						$0.absoluteString != urlString
					else {
						return
					}

					urlString = $0.absoluteString
				}
				.onChange(of: urlString) {
					guard let url = URL(humanString: $0) else {
						// Makes the “Revert” button work if the user clears the URL field.
						if urlString.trimmed.isEmpty {
							website.wrappedValue.url = "-"
						} else if let url = URL(string: $0), url.isValid {
							website.wrappedValue.url = url
						}

						return
					}

					guard url.isValid else {
						return
					}

					website.wrappedValue.url = url
						.normalized(
							// We need to allow typing `http://172.16.0.100:8080`.
							removeDefaultPort: false
						)
				}
				.debouncingTask(id: website.wrappedValue.url, interval: .seconds(0.5)) {
					await fetchTitle()
				}
			TextField("Title", text: website.title)
				.lineLimit(1)
				.disabled(isFetchingTitle)
				.overlay(alignment: .leading) {
					if isFetchingTitle {
						ProgressView()
							.controlSize(.small)
							.offset(x: 50)
					}
				}
		} footer: {
			Button("Local Website…") {
				Task {
					guard let url = await chooseLocalWebsite() else {
						return
					}

					urlString = url.absoluteString
				}
			}
				.controlSize(.small)
		}
	}

	@ViewBuilder
	private var editingView: some View {
		Section {
			EnumPicker("Invert colors", selection: website.invertColors2) {
				Text($0.title)
			}
				.help("Creates a fake dark mode for websites without a native dark mode by inverting all the colors on the website.")
			Toggle("Use print styles", isOn: website.usePrintStyles)
				.help("Forces the website to use its print styles (“@media print”) if any. Some websites have a simpler presentation for printing, for example, Google Calendar.")
			let cssHelpText = "This lets you modify the website with CSS. You could, for example, change some colors or hide some unnecessary elements."
			VStack(alignment: .leading) {
				HStack {
					Text("CSS")
					Spacer()
					InfoPopoverButton(cssHelpText)
						.controlSize(.small)
				}
				ScrollableTextView(
					text: website.css,
					font: .monospacedSystemFont(ofSize: 11, weight: .regular),
					isAutomaticQuoteSubstitutionEnabled: false,
					isAutomaticDashSubstitutionEnabled: false,
					isAutomaticTextReplacementEnabled: false,
					isAutomaticSpellingCorrectionEnabled: false
				)
					.frame(height: 70)
			}
				.accessibilityElement(children: .combine)
				.accessibilityLabel("CSS")
				.accessibilityHint(Text(cssHelpText))
			let javaScriptHelpText = "This lets you modify the website with JavaScript. Prefer using CSS instead whenever possible. You can use “await” at the top-level."
			VStack(alignment: .leading) {
				HStack {
					Text("JavaScript")
					Spacer()
					InfoPopoverButton(javaScriptHelpText)
						.controlSize(.small)
				}
				ScrollableTextView(
					text: website.javaScript,
					font: .monospacedSystemFont(ofSize: 11, weight: .regular),
					isAutomaticQuoteSubstitutionEnabled: false,
					isAutomaticDashSubstitutionEnabled: false,
					isAutomaticTextReplacementEnabled: false,
					isAutomaticSpellingCorrectionEnabled: false
				)
					.frame(height: 70)
			}
				.accessibilityElement(children: .combine)
				.accessibilityLabel("JavaScript")
				.accessibilityHint(Text(javaScriptHelpText))
			Section("Advanced") {
				Toggle("Allow self-signed certificate", isOn: website.allowSelfSignedCertificate)
			}
		}
	}

	private func submit() {
		guard isURLValid else {
			return
		}

		if isEditing {
			dismiss()
		} else {
			add()
		}
	}

	private func revert() {
		guard let originalWebsite else {
			return
		}

		website.wrappedValue = originalWebsite
	}

	private func add() {
		WebsitesController.shared.add(website.wrappedValue)
		dismiss()

		SSApp.runOnce(identifier: "editWebsiteTip") {
			// TODO: Find a better way to inform the user about this.
			Task {
				await NSAlert.show(
					title: "Click a website in the list to edit it, toggle dark mode, add custom CSS/JavaScript, and more."
				)
			}
		}
	}

	@MainActor
	private func chooseLocalWebsite() async -> URL? {
//		guard let hostingWindow else {
//			return nil
//		}

		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.canCreateDirectories = false
		panel.title = "Choose Local Website"
		panel.message = "Choose a directory with a “index.html” file."
		panel.prompt = "Choose"

		// Ensure it's above the window when in "Browsing Mode".
		panel.level = .modalPanel

		let url = website.wrappedValue.url

		if
			isEditing,
			url.isFileURL
		{
			panel.directoryURL = url
		}

		// TODO: Make it a sheet instead when targeting the macOS bug is fixed. (macOS 13.1)
//		let result = await panel.beginSheet(hostingWindow)
		let result = await panel.begin()

		guard
			result == .OK,
			let url = panel.url
		else {
			return nil
		}

		guard url.appendingPathComponent("index.html", isDirectory: false).exists else {
			await NSAlert.show(title: "Please choose a directory that contains a “index.html” file.")
			return await chooseLocalWebsite()
		}

		do {
			try SecurityScopedBookmarkManager.saveBookmark(for: url)
		} catch {
			await error.present()
			return nil
		}

		return url
	}

	@MainActor
	private func fetchTitle() async {
		// Ensure we don't erase a user's existing title.
		if
			isEditing,
			!website.title.wrappedValue.isEmpty
		{
			return
		}

		let url = website.wrappedValue.url

		guard url.isValid else {
			website.wrappedValue.title = ""
			return
		}

		withAnimation {
			isFetchingTitle = true
		}

		defer {
			withAnimation {
				isFetchingTitle = false
			}
		}

		let metadataProvider = LPMetadataProvider()
		metadataProvider.shouldFetchSubresources = false
		metadataProvider.timeout = 5

		guard
			let metadata = try? await metadataProvider.startFetchingMetadata(for: url),
			let title = metadata.title
		else {
			if !isEditing || website.wrappedValue.title.isEmpty {
				website.wrappedValue.title = ""
			}

			return
		}

		website.wrappedValue.title = title
	}
}

struct AddWebsiteScreen_Previews: PreviewProvider {
	static var previews: some View {
		AddWebsiteScreen(
			isEditing: false,
			website: nil
		)
	}
}
