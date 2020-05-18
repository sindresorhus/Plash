import Cocoa
import Combine

final class DesktopWindow: NSWindow {
	override var canBecomeMain: Bool { isInteractive }
	override var canBecomeKey: Bool { isInteractive }
	override var acceptsFirstResponder: Bool { isInteractive }

	private var cancelBag = Set<AnyCancellable>()

	var targetScreen: NSScreen? {
		didSet {
			setFrame()
		}
	}

	var isInteractive = false {
		didSet {
			if isInteractive {
				level = .floating
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
		self.collectionBehavior = [
			.stationary,
			.ignoresCycle
		]

		setFrame()

		NSScreen.publisher
			.sink { [weak self] in
				self?.setFrame()
			}
			.store(in: &cancelBag)
	}

	private func setFrame() {
		// Ensure the screen still exists.
		guard let screen = targetScreen?.withFallbackToMain ?? .main else {
			return
		}

		setFrame(screen.visibleFrameWithoutStatusBar, display: true)
	}
}
