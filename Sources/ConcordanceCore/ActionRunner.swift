import AppKit

/// What ↵ (and ⌘↵, "alternate") does for each kind of result.
@MainActor
public enum ActionRunner {
    /// Commands the app itself handles: "reindex", "settings", "quit".
    public static var appCommandHandler: ((String) -> Void)?

    public static func perform(_ item: SearchItem, alternate: Bool) {
        if alternate, item.kind.isFileBacked, let url = item.url {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        switch item.kind {
        case .application, .settings, .folder, .file, .image, .web, .everpaper:
            if let url = item.url { NSWorkspace.shared.open(url) }
        case .clipboard, .calculator:
            if let text = item.payload { copy(text) }
        case .command:
            run(command: String(item.id.dropFirst("cmd:".count)))
        }
    }

    public static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func run(command: String) {
        switch command {
        case "lock": lockScreen()
        case "sleep": shell("/usr/bin/pmset", "sleepnow")
        case "display-sleep": shell("/usr/bin/pmset", "displaysleepnow")
        case "screensaver": shell("/usr/bin/open", "-a", "ScreenSaverEngine")
        // loginwindow shows the system confirmation dialog for these three.
        case "restart": appleScript(#"tell application "loginwindow" to «event aevtrrst»"#)
        case "shutdown": appleScript(#"tell application "loginwindow" to «event aevtrsdn»"#)
        case "logout": appleScript(#"tell application "loginwindow" to «event aevtlogo»"#)
        case "empty-trash":
            if confirm("Empty the Trash?", detail: "The items in the Trash will be deleted permanently.") {
                appleScript(#"tell application "Finder" to empty trash"#)
            }
        case "open-trash":
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
        case "dark-mode":
            appleScript(#"tell application "System Events" to tell appearance preferences to set dark mode to not dark mode"#)
        case "mute":
            appleScript("set volume output muted not (output muted of (get volume settings))")
        case "eject":
            appleScript(#"tell application "Finder" to eject (every disk whose ejectable is true)"#)
        case "screenshot":
            // Give the launcher panel time to leave the screen first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { shell("/usr/sbin/screencapture", "-i", "-c") }
        default:
            appCommandHandler?(command)
        }
    }

    private static func lockScreen() {
        // SACLockScreenImmediate (login.framework) locks right away, like ⌃⌘Q; fall back to sleeping the displays.
        typealias LockFunction = @convention(c) () -> Int32
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let symbol = dlsym(handle, "SACLockScreenImmediate") {
            _ = unsafeBitCast(symbol, to: LockFunction.self)()
        } else {
            shell("/usr/bin/pmset", "displaysleepnow")
        }
    }

    private static func confirm(_ message: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func shell(_ path: String, _ arguments: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }

    private static func appleScript(_ source: String) {
        shell("/usr/bin/osascript", "-e", source)
    }
}
