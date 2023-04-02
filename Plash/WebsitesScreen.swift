import SwiftUI

struct WebsitesScreen: View {
	@Default(.websites) private var websites
	@State private var selection: Website.ID? // We need two states as selection must be independent from actually opening the editing because of keyboard navigation and accessibility.
	@State private var editedWebsite: Website.ID?
	@State private var isAddWebsiteDialogPresented = false
	@Namespace private var bottomScrollID

	var body: some View {
		Form {
			// TODO: The `ScrollViewReader` causes UI issues in a form. (macOS 13.1)
//			ScrollViewReader { scrollViewProxy in
			Section {
				if !websites.isEmpty {
					HideableInfoBox(
						id: "websitesListTips",
						message: "Click a website to edit. Drag and drop to reorder."
					)
						.padding(.leading)
				}
				List($websites, editActions: .all, selection: $selection) { website in
					RowView(
						website: website,
						selection: $editedWebsite
					)
				}
					.frame(height: 500)
					.onKeyboardShortcut(.defaultAction) {
						editedWebsite = selection
					}
			}/* footer: {
				Color.clear
					.frame(height: 1)
					.id(bottomScrollID)
			}*/
				.onChange(of: websites) { [oldWebsites = websites] websites in
					// Check that a website was added.
					guard websites.count > oldWebsites.count else {
						return
					}

					withAnimation {
//							scrollViewProxy.scrollTo(bottomScrollID, anchor: .top)
					}
				}
				.overlay {
					if websites.isEmpty {
						Text("No Websites")
							.emptyStateTextStyle()
					}
				}
				.accessibilityAction(named: Text("Add website")) {
					isAddWebsiteDialogPresented = true
				}
		}
//		}
			.formStyle(.grouped)
			.frame(width: 480)
			.fixedSize()
			.onChange(of: editedWebsite) {
				selection = $0
			}
			.sheet(item: $editedWebsite) {
				AddWebsiteScreen(
					isEditing: true,
					website: $websites[id: $0]
				)
			}
			.sheet(isPresented: $isAddWebsiteDialogPresented) {
				AddWebsiteScreen(
					isEditing: false,
					website: nil
				)
			}
			.onNotification(.showAddWebsiteDialog) { _ in
				isAddWebsiteDialogPresented = true
			}
			.onNotification(.showEditWebsiteDialog) { _ in
				editedWebsite = WebsitesController.shared.current?.id
			}
			.toolbar {
				Button("Add Website", systemImage: "plus") {
					isAddWebsiteDialogPresented = true
				}
			}
			.windowLevel(.floating)
			.windowIsMinimizable(false)
	}
}

struct WebsitesScreen_Previews: PreviewProvider {
	static var previews: some View {
		WebsitesScreen()
	}
}

private struct RowView: View {
	@Binding var website: Website
	@Binding var selection: Website.ID?

	var body: some View {
		HStack {
			Label {
				// TODO: This should use something like `.lineBreakMode = .byCharWrapping` if SwiftUI ever supports that.
				if let title = website.title.nilIfEmpty {
					Text(title)
				}
				Text(website.subtitle)
			} icon: {
				IconView(website: website)
			}
				.lineLimit(1)
			Spacer()
			if website.isCurrent {
				Image(systemName: "checkmark.circle.fill")
					.renderingMode(.original)
					.font(.title2)
			}
		}
			.frame(height: 64) // Note: Setting a fixed height prevents a lot of SwiftUI rendering bugs.
			.padding(.horizontal, 8)
			.help(website.tooltip)
			.swipeActions(edge: .leading, allowsFullSwipe: true) {
				Button("Set as Current") {
					website.makeCurrent()
				}
					.disabled(website.isCurrent)
			}
			.contentShape(.rectangle)
			.onDoubleClick {
				selection = website.id
			}
			.contextMenu { // Must come after `.onDoubleClick`.
				Button("Set as Current") {
					website.makeCurrent()
				}
					.disabled(website.isCurrent)
				Divider()
				Button("Edit…") {
					selection = website.id
				}
				Divider()
				Button("Delete", role: .destructive) {
					website.remove()
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityAddTraits(.isButton)
			.if(website.isCurrent) {
				$0.accessibilityAddTraits(.isSelected)
			}
	}
}

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
			.task(id: website.url) {
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
