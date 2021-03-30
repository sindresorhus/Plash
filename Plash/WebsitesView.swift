import SwiftUI
import LinkPresentation
import Defaults

@available(macOS 11, *)
private struct IconView: View {
	@State private var iconFetcher: WebsiteIconFetcher?
	@State private var icon: Image?

	let website: Website

	var body: some View {
		Group {
			if let icon = icon {
				icon
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else {
				Color.primary.opacity(0.1)
			}
		}
			.frame(width: 32, height: 32)
			.clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
			.onAppear {
				fetchIcons()
			}
	}

	private func fetchIcons() {
		let cache = WebsitesController.shared.thumbnailCache

		if let image = cache[website.thumbnailCacheKey] {
			icon = Image(nsImage: image)
			return
		}

		LPMetadataProvider().startFetchingMetadata(for: website.url) { metadata, error in
			if error != nil {
				return
			}

			guard
				let iconProvider = metadata?.iconProvider,
				iconProvider.hasItemConformingToTypeIdentifier("public.image")
			else {
				DispatchQueue.main.async {
					iconFetcher = WebsiteIconFetcher()
					iconFetcher?.fetch(for: website.url) {
						guard let image = $0 else {
							return
						}

						cache[website.thumbnailCacheKey] = image
						icon = Image(nsImage: image)
					}
				}

				return
			}

			iconProvider.getImage {
				guard let image = $0 else {
					return
				}

				cache[website.thumbnailCacheKey] = image
				icon = Image(nsImage: image)
			}
		}
	}
}

private struct RowView: View {
	@Binding var website: Website
	@Binding var editSheetItem: Website?

	var body: some View {
		HStack {
			if #available(macOS 11, *) {
				IconView(website: website)
					.padding(.trailing, 10)
					.id(website.url)
			}
			// TODO: This should use something like `.lineBreakMode = .byCharWrapping` if SwiftUI ever supports that.
			Text(website.title)
				.font(.headline)
				.lineLimit(2)
				.help2(website.url.absoluteString.removingPercentEncoding)
			Spacer()
			if website.isCurrent {
				if #available(macOS 11, *) {
					Image(systemName: "checkmark.circle.fill")
						.renderingMode(.original)
						.font(.title2)
				} else {
					Text("Current")
						.font(.subheadline)
				}
			}
		}
			.padding(.horizontal)
			.frame(height: OS.isMacOSBigSurOrLater ? 64 : 44)
			// TODO: This makes `onMove` not work when clicking the text.
			// https://github.com/feedback-assistant/reports/issues/46
			// Still an issue on macOS 11.2.3.
//			.onTapGesture(count: 2) {
//				edit()
//			}
			.contextMenu {
				// TODO: Any better label for this?
				Button("Make Current") {
					website.makeCurrent()
				}
					.disabled(website.isCurrent)
				Divider()
				Button("Edit…") {
					edit()
				}
				Divider()
				Button("Delete") {
					website.remove()
				}
			}
	}

	private func edit() {
		// TODO: This can be removed when I have implemented proper website preview in the add/edit dialog.
		website.makeCurrent()

		editSheetItem = website
	}
}

struct WebsitesView: View {
	@Default(.websites) private var websites
	@State private var isShowingAddSheet = false
	@State private var editSheetItem: Website? // TODO: This is here and not on the row as SwiftUI still doesn't handle that. (macOS 11.2.3)

	var body: some View {
		VStack {
			HStack {
				Spacer()
				CocoaButton("Add…", keyEquivalent: .return) {
					isShowingAddSheet = true
				}
			}
				.padding()
				.padding(.bottom, -28)
			List {
				// TODO: Check if macOS 11.3 fixes this.
				// TODO: This currently crashes when deleting the last element. Seems to be a known SwiftUI bug. (macOS 11.2.3)
				ForEach($websites) { _, website in
					RowView(
						website: website,
						editSheetItem: $editSheetItem
					)
				}
					.onMove(perform: move)
					.onDelete(perform: delete)
					.listRowBackground(
						OS.isMacOSBigSurOrLater
							? Color.primary
								.opacity(0.04)
								.border(Color.primary.opacity(0.07), width: 1, cornerRadius: 6, cornerStyle: .continuous)
								.padding(.vertical, 6)
							: nil
					)
			}
				.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
				.overlay(
					websites.isEmpty
						? Text("No Websites").emptyStateTextStyle()
						: nil,
					alignment: .center
				)
				.padding()
				.padding(.vertical, 4)
			Text("Right-click to edit. Drag and drop to reorder.")
				.font(.system(size: 10))
				.foregroundColor(.secondary)
				.padding(.bottom, 20)
				.padding(.top, -8)
		}
			.frame(
				width: 420,
				height: 520
			)
			.sheet(item: $editSheetItem) {
				AddWebsiteView(isEditing: true, showsCancelButtons: true, website: $0) {}
			}
			.sheet2(isPresented: $isShowingAddSheet) {
				AddWebsiteView(isEditing: false, showsCancelButtons: true, website: nil) {}
			}
			// TODO: When targeting macOS 11 and using `App` protocol.
//			.toolbar {
//				ToolbarItem(placement: .confirmationAction) {
//					Button {
//						isShowingAddSheet = true
//					} label: {
//						Image(systemName: "plus")
//					}
//						.keyboardShortcut(.defaultAction)
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

struct ManageWebsitesView_Previews: PreviewProvider {
    static var previews: some View {
		WebsitesView()
    }
}
