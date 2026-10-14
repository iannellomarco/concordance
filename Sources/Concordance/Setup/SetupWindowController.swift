import AppKit
import ConcordanceCore
import SwiftUI

/// Hosts the setup assistant in a borderless-looking, movable window: a behind-window blur of the desktop, warm
/// drifting light, and Liquid Glass panes, following the system appearance. While it is open the app shows in the
/// Dock and ⌘-Tab like a regular app; afterwards it returns to being a menu-bar accessory.
@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    let model: SetupModel
    private let window: NSWindow
    var onClose: ((_ finished: Bool) -> Void)?
    private var finished = false

    init(engine: SearchEngine) {
        model = SetupModel(engine: engine)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        super.init()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Welcome to Concordance"
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        // The desktop behind, blurred; the SwiftUI backdrop and the glass panes sit on top of it.
        let blur = NSVisualEffectView()
        blur.material = .underWindowBackground
        blur.blendingMode = .behindWindow
        blur.state = .active
        let hosting = NSHostingView(rootView: SetupView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: blur.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
        window.contentView = blur
        window.delegate = self
        window.center()
        model.onFinish = { [weak self] in
            self?.finished = true
            self?.window.close()
        }
    }

    var isVisible: Bool { window.isVisible }
    var isOnShortcutStep: Bool { window.isVisible && model.step == .shortcut }

    func show() {
        NSApp.setActivationPolicy(.regular)
        // The policy change takes effect on the next run-loop turn; activating before it can be ignored.
        DispatchQueue.main.async { [window] in
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.recorder.stop()
        NSApp.setActivationPolicy(.accessory)
        onClose?(finished)
    }
}
