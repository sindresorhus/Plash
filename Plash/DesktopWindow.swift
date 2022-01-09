import Cocoa
import Combine
import Defaults

@MainActor
final class DesktopWindow: NSWindow {
	override var canBecomeMain: Bool { isInteractive }
	override var canBecomeKey: Bool { isInteractive }
	override var acceptsFirstResponder: Bool { isInteractive }

	private var cancellables = Set<AnyCancellable>()

	var targetScreen: NSScreen? {
		didSet {
			setFrame()
		}
	}

	var isInteractive = false {
		didSet {
			if isInteractive {
				level = Defaults[.bringBrowsingModeToFront] ? .floating : (.desktopIcon + 1) // The `+ 1` fixes a weird issue where the window is sometimes not interactive. (macOS 11.2.1)
				makeKeyAndOrderFront(self)
				ignoresMouseEvents = false
			} else {
				level = .desktop
				orderBack(self)

				// Even though the window is on `.desktop` level, the user would be able to interact if they hide desktop icons.
				ignoresMouseEvents = true
			}
		}
	}

	convenience init(screen: NSScreen?) {
		self.init(
			contentRect: .zero,
			styleMask: [
				.borderless
			],
			backing: .buffered,
			defer: false
		)

		self.targetScreen = screen

		self.isOpaque = false
		self.backgroundColor = .clear
		self.level = .desktop
		self.isRestorable = false
		self.canHide = false
		self.displaysWhenScreenProfileChanges = true
		self.collectionBehavior = [
			.stationary,
			.ignoresCycle,
			.fullScreenNone // This ensures that if Plash is launched while an app is fullscreen (fullscreen is a separate space), it will not show behind that app and instead show in the primary space.
		]

		disableSnapshotRestoration()
		setFrame()

		NSScreen.publisher
			.sink { [weak self] in
				self?.setFrame()
			}
			.store(in: &cancellables)
	}

	private func setFrame() {
		// Ensure the screen still exists.
		guard let screen = targetScreen?.withFallbackToMain ?? .main else {
			return
		}

		setFrame(screen.visibleFrameWithoutStatusBar, display: true)
	}
}
