import SwiftUI
import Defaults

private struct IconView: View {
	@State private var icon: Image?

	let website: Website

	var body: some View {
		VStack {
			if let icon {
				icon
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else {
				Color.primary.opacity(0.1)
			}
		}
			.frame(width: 32, height: 32)
			.clipShape(.roundedRectangle(cornerRadius: 4, style: .continuous))
			.task {
				guard let image = await fetchIcons() else {
					return
				}

				icon = Image(nsImage: image)
			}
	}

	@MainActor
	private func fetchIcons() async -> NSImage? {
		let cache = WebsitesController.shared.thumbnailCache

		if let image = cache[website.thumbnailCacheKey] {
			return image
		}

		guard let image = try? await WebsiteIconFetcher.fetch(for: website.url) else {
			return nil
		}

		cache[website.thumbnailCacheKey] = image

		return image
	}
}

private struct RowView: View {
	@State private var isEditScreenPresented = false

	@Binding var website: Website

	var body: some View {
		HStack {
			IconView(website: website)
				.padding(.trailing, 7)
				.id(website.url)
			// TODO: This should use something like `.lineBreakMode = .byCharWrapping` if SwiftUI ever supports that.
			VStack(alignment: .leading) {
				Text(website.title)
					.font(.headline)
					.lineLimit(1)
				Text(website.subtitle)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer()
			if website.isCurrent {
				Image(systemName: "checkmark.circle.fill")
					.renderingMode(.original)
					.font(.title2)
			}
		}
			.padding(.horizontal)
			.frame(height: 64) // Note: Setting a fixed height prevents a lot of SwiftUI rendering bugs.
			// TODO: This makes `onMove` not work when clicking the text.
			// https://github.com/feedback-assistant/reports/issues/46
			// Still an issue on macOS 11.2.3.
//			.onTapGesture(count: 2) {
//				edit()
//			}
			.help(website.tooltip)
			.sheet(isPresented: $isEditScreenPresented) {
				AddWebsiteScreen(
					isEditing: true,
					website: $website
				)
			}
			.onNotification(.showEditWebsiteDialog) { _ in
				DispatchQueue.main.async { // Attempt at working around SwiftUI crash.
					guard website.isCurrent else {
						return
					}

					isEditScreenPresented = true
				}
			}
			.contextMenu {
				Button("Set as Current") {
					website.makeCurrent()
				}
					.disabled(website.isCurrent)
				Divider()
				Button("Edit…") {
					edit()
				}
				Divider()
				Button("Delete", role: .destructive) {
					website.remove()
				}
			}
	}

	private func edit() {
		website.makeCurrent()
		isEditScreenPresented = true
	}
}

struct WebsitesScreen: View {
	@Default(.websites) private var websites
	@State private var isEditScreenPresented = false
	@Namespace private var bottomScrollID

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Spacer()
				Button("Add Website", systemImage: "plus") {
					isEditScreenPresented = true
				}
					.labelStyle(.iconOnly)
					.keyboardShortcut(.defaultAction)
			}
				.padding()
				.overlay(alignment: .leading) {
					if !websites.isEmpty {
						HideableInfoBox(
							id: "websitesListTips",
							message: "Right-click to edit. Drag and drop to reorder."
						)
							.padding(.leading)
					}
				}
			ScrollViewReader { scrollViewProxy in
				List {
					ForEach($websites) { website in
						RowView(website: website)
					}
						.onMove(perform: move)
						.onDelete(perform: delete)
					Color.clear
						.frame(height: 1)
						.padding(.bottom, 30) // Ensures it scrolls fully to the bottom when adding new websites.
						.id(bottomScrollID)
				}
					.onChange(of: websites) { [oldWebsites = websites] websites in
						// Check that a website was added.
						guard websites.count > oldWebsites.count else {
							return
						}

						withAnimation {
							scrollViewProxy.scrollTo(bottomScrollID, anchor: .top)
						}
					}
					.overlay {
						if websites.isEmpty {
							Text("No Websites")
								.emptyStateTextStyle()
						}
					}
					.overlay(alignment: .top) {
						Divider()
					}
					.if(!websites.isEmpty) {
						$0.listStyle(.inset(alternatesRowBackgrounds: true))
					}
			}
		}
			.frame(
				width: 420,
				height: 520
			)
			.sheet(isPresented: $isEditScreenPresented) {
				AddWebsiteScreen(
					isEditing: false,
					website: nil
				)
			}
			.onNotification(.showAddWebsiteDialog) { _ in
				isEditScreenPresented = true
			}
			// TODO: When using SwiftUI for the window.
//			.toolbar {
//				ToolbarItem(placement: .confirmationAction) {
//					Button("Add Website", systemImage: "plus") {
//						isShowingAddSheet = true
//					}
//				}
//			}
	}

	private func move(from source: IndexSet, to destination: Int) {
		websites = websites.moving(fromOffsets: source, toOffset: destination)
	}

	private func delete(at offsets: IndexSet) {
		websites = websites.removing(atOffsets: offsets)
	}
}

// TODO
//@MainActor
final class WebsitesWindowController: SingletonWindowController {
	private convenience init() {
		let window = SwiftUIWindowForMenuBarApp()
		self.init(window: window)

		let view = WebsitesScreen()

		window.title = "Websites"
		window.styleMask = [
			.titled,
			.fullSizeContentView,
			.closable
		]
		window.level = .floating
		window.contentViewController = NSHostingController(rootView: view)
		window.center()
	}
}

struct WebsitesScreen_Previews: PreviewProvider {
	static var previews: some View {
		WebsitesScreen()
	}
}
