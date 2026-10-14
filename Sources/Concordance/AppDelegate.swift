import AppKit
import ConcordanceCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let engine = SearchEngine(preferences: .load())
    private lazy var model = LauncherModel(engine: engine)
    private lazy var panel = LauncherPanel(rootView: LauncherView(model: model))
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var setup: SetupWindowController?
    private var keyMonitor: Any?
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.delegate = self
        model.onClose = { [weak self] in self?.hide() }
        ActionRunner.appCommandHandler = { [weak self] command in self?.handle(command: command) }
        registerHotKey()
        installStatusItem()
        if !Preferences.setupCompleted || ProcessInfo.processInfo.arguments.contains("--setup") {
            showSetup()
        } else {
            engine.start()
        }
        NotificationCenter.default.addObserver(forName: .concordancePreferencesChanged, object: nil, queue: .main) {
            [weak self] _ in
            // The settings view saves first; re-read so the new hotkey takes effect.
            MainActor.assumeIsolated { self?.registerHotKey() }
        }
        if ProcessInfo.processInfo.arguments.contains("--show") { show() }
        if let query = ProcessInfo.processInfo.environment["CONCORDANCE_QUERY"] {
            show()
            model.setQuery(query)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.prepareForExit()
    }

    // MARK: - Panel

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        panel.positionOnActiveScreen()
        model.willShow()
        engine.isInteractive = true
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        engine.isInteractive = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        model.reset()
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === panel { hide() }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            let command = event.modifierFlags.contains(.command)
            switch Int(event.keyCode) {
            case 125: model.move(1); return nil                         // ↓
            case 126: model.move(-1); return nil                        // ↑
            case 36, 76: model.run(alternate: command); return nil      // ↵ / ⌘↵
            case 53:                                                    // esc
                if model.query.isEmpty { hide() } else { model.setQuery("") }
                return nil
            default:
                if command, event.charactersIgnoringModifiers == "," { hide(); showSettings(); return nil }
                if event.modifierFlags.contains(.control), let c = event.charactersIgnoringModifiers {
                    if c == "n" { model.move(1); return nil }
                    if c == "p" { model.move(-1); return nil }
                }
                return event
            }
        }
    }

    // MARK: - Hotkey, menu bar, settings

    private func registerHotKey() {
        hotKey = nil
        hotKey = HotKey(Preferences.load().hotKey) { [weak self] in
            MainActor.assumeIsolated {
                // On the setup assistant's shortcut step, a press proves the shortcut works.
                if let setup = self?.setup, setup.isOnShortcutStep { setup.model.shortcutPressed() } else { self?.toggle() }
            }
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "Concordance")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Open Concordance", action: #selector(openFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Rebuild Index", action: #selector(rebuildIndex), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Run Setup Again…", action: #selector(runSetup), keyEquivalent: "").target = self
        let everpaperItem = NSMenuItem(title: "Everpaper — private daybook of work & meetings  ↗",
                                       action: #selector(openEverpaper), keyEquivalent: "")
        everpaperItem.target = self
        menu.addItem(everpaperItem)
        menu.addItem(.separator())
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Concordance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        let hotKeyLabel = Preferences.load().hotKey.label
        let state = switch engine.modelStatus {
        case .ready: engine.pendingCount > 0 ? "indexing (\(engine.pendingCount) to go)" : "\(engine.indexedCount) items"
        case .loading: "preparing model…"
        case .missing: "model not found"
        case .failed: "model failed"
        }
        statusLine.title = "EmbeddingGemma 2: \(state)  ·  \(hotKeyLabel)"
    }

    @objc private func openFromMenu() { show() }
    @objc private func openSettings() { showSettings() }
    @objc private func rebuildIndex() { engine.rebuildIndex() }
    @objc private func runSetup() { showSetup() }
    @objc private func openEverpaper() {
        if let url = Everpaper.installedURL { NSWorkspace.shared.open(url) }
        else { NSWorkspace.shared.open(Everpaper.website) }
    }

    func showSetup() {
        hide()
        if setup == nil {
            let controller = SetupWindowController(engine: engine)
            controller.model.onShortcutChange = { [weak self] in self?.registerHotKey() }
            controller.model.isShortcutRegistered = { [weak self] in self?.hotKey?.isRegistered ?? false }
            controller.onClose = { [weak self] finished in
                guard let self else { return }
                setup = nil
                // Closed early: run with whatever was chosen so far.
                if !engine.hasStarted { engine.start() }
                if finished { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.show() } }
            }
            setup = controller
        }
        setup?.show()
    }

    private func handle(command: String) {
        switch command {
        case "reindex": engine.rebuildIndex()
        case "settings": showSettings()
        case "quit": NSApp.terminate(nil)
        case "clear-clipboard": engine.clipboard.clear()
        default: break
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: SettingsView(engine: engine, isHotKeyRegistered: { [weak self] in self?.hotKey?.isRegistered ?? false })))
            window.title = "Concordance Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
