import AppKit
import SwiftUI

/// A borderless floating glass panel that takes key focus without activating the app, so the app you were in stays
/// frontmost, like Spotlight and Raycast.
final class LauncherPanel: NSPanel {
    init(rootView: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false

        // The whole window is Liquid Glass, tinted with Everpaper's paper, refracting the desktop behind it.
        let glass = NSGlassEffectView()
        glass.cornerRadius = 26
        glass.tintColor = Paper.nsGlassTint(alpha: 0.42)
        glass.style = .regular
        glass.contentView = NSHostingView(rootView: rootView)
        contentView = glass
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Centered horizontally on the screen with the mouse, a little above the middle.
    func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = frame.size
        setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + visible.height * 0.62 - size.height / 2))
    }
}
