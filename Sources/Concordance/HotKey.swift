import AppKit
import Carbon
import ConcordanceCore

/// A system-wide hotkey (Carbon RegisterEventHotKey: no Accessibility permission needed).
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private(set) var isRegistered = false

    init(_ combo: HotKeyCombo, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x434F_4E43), id: 1)   // 'CONC'
        let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        isRegistered = status == noErr
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

extension HotKeyCombo {
    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers & Self.command != 0 { result |= cmdKey }
        if modifiers & Self.option != 0 { result |= optionKey }
        if modifiers & Self.control != 0 { result |= controlKey }
        if modifiers & Self.shift != 0 { result |= shiftKey }
        return UInt32(result)
    }

    /// The combo of a key press, or nil when it cannot be a global shortcut (no ⌃/⌥/⌘, except function keys).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        let isFunctionKey = Self.functionKeys[event.keyCode] != nil
        guard isFunctionKey || !flags.intersection([.control, .option, .command]).isEmpty else { return nil }
        let name = Self.keyNames[event.keyCode] ?? Self.functionKeys[event.keyCode]
            ?? (event.charactersIgnoringModifiers ?? "").uppercased()
        guard !name.isEmpty else { return nil }
        self.init(keyCode: event.keyCode, modifiers: flags.rawValue, key: name)
    }

    static let keyNames: [UInt16: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 117: "⌦", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
    ]
    static let functionKeys: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]
}

/// Who else wants a shortcut: enabled macOS shortcuts (System Settings › Keyboard Shortcuts) and launchers that
/// claim ⌥ Space by default. Carbon only reports conflicts with other Carbon registrations, which misses both.
enum HotKeyConflicts {
    static func check(_ combo: HotKeyCombo) -> [String] {
        systemConflicts(combo) + appConflicts(combo)
    }

    private static let systemNames: [Int: String] = [
        60: "macOS uses it to switch to the previous input source",
        61: "macOS uses it to switch to the next input source",
        64: "macOS uses it for Spotlight",
        65: "macOS uses it for the Finder search window",
    ]
    /// Symbolic hotkeys that are on by default even when the preferences file has no entry for them.
    private static let defaults: [Int: (keyCode: Int, modifiers: UInt)] = [
        60: (49, HotKeyCombo.control), 61: (49, HotKeyCombo.control | HotKeyCombo.option),
        64: (49, HotKeyCombo.command), 65: (49, HotKeyCombo.command | HotKeyCombo.option),
    ]

    private static func systemConflicts(_ combo: HotKeyCombo) -> [String] {
        let stored = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                               "com.apple.symbolichotkeys" as CFString) as? [String: Any] ?? [:]
        var conflicts: [String] = []
        var seen = Set<Int>()
        for (key, value) in stored {
            guard let id = Int(key), let entry = value as? [String: Any] else { continue }
            seen.insert(id)
            let enabled = (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1)
            guard enabled, let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
                  parameters.count == 3, parameters[1] == Int(combo.keyCode),
                  UInt(parameters[2]) & HotKeyCombo.modifierMask == combo.modifiers else { continue }
            conflicts.append(systemNames[id] ?? "a macOS keyboard shortcut uses it")
        }
        for (id, shortcut) in defaults where !seen.contains(id) {
            if shortcut.keyCode == Int(combo.keyCode), shortcut.modifiers == combo.modifiers {
                conflicts.append(systemNames[id] ?? "a macOS keyboard shortcut uses it")
            }
        }
        return conflicts
    }

    private static let launchers: [(bundlePrefix: String, name: String)] = [
        ("com.iannellomarco.HindsightNext", "Everpaper"),
        ("com.raycast.macos", "Raycast"),
        ("com.runningwithcrayons.Alfred", "Alfred"),
    ]

    private static func appConflicts(_ combo: HotKeyCombo) -> [String] {
        guard combo == .optionSpace else { return [] }
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        return launchers.filter { launcher in running.contains { $0.hasPrefix(launcher.bundlePrefix) } }
            .map { "\($0.name) is running and opens on ⌥ Space too" }
    }
}
