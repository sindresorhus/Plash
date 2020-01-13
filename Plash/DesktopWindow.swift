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
			} else {
				level = .desktop
				orderBack(self)
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

		Publishers.Merge(
			NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification),
			NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
		)
			.sink { [weak self] _ in
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
