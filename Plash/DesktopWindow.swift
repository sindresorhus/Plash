import Cocoa
import Combine

final class DesktopWindow: NSWindow {
	override var canBecomeMain: Bool { isInteractive }
	override var canBecomeKey: Bool { isInteractive }
	override var acceptsFirstResponder: Bool { isInteractive }

	private var cancelBag = Set<AnyCancellable>()

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

	convenience init() {
		self.init(
			contentRect: .zero,
			styleMask: [
				.borderless
			],
			backing: .buffered,
			defer: false
		)

		self.level = .desktop
		self.collectionBehavior = [
			.canJoinAllSpaces,
			.stationary,
			.ignoresCycle
		]

		setSize()

		NotificationCenter.default
			.publisher(for: NSApplication.didChangeScreenParametersNotification)
			.sink { [weak self] _ in
				self?.setSize()
			}
			.store(in: &cancelBag)
	}

	private func setSize() {
		guard var mainScreenSize = NSScreen.main?.frame.size else {
			return
		}

		mainScreenSize.height -= NSStatusBar.system.thickness
		setContentSize(mainScreenSize)
	}
}
