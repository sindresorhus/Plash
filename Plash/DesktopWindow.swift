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

		self.level = .desktop
		self.collectionBehavior = [
			.canJoinAllSpaces,
			.stationary,
			.ignoresCycle
		]

		setFrame()

		NotificationCenter.default
			.publisher(for: NSApplication.didChangeScreenParametersNotification)
			.sink { [weak self] _ in
				self?.setFrame()
			}
			.store(in: &cancelBag)
	}

	private func setFrame() {
		// Ensure the screen still exists.
		guard let screen = (NSScreen.screens.first { $0 == targetScreen }) ?? .main else {
			return
		}

		var screenFrame = screen.frame

		// Account for the menu bar if the window is on the main screen or if secondary screens are set to show the menu bar.
		if screen == .main || NSScreen.screensHaveSeparateSpaces {
			screenFrame.size.height -= NSStatusBar.system.thickness
		}

		setFrame(screenFrame, display: true)
	}
}
