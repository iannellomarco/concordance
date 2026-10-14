import Foundation

/// A global shortcut: a virtual key code plus NSEvent modifier flags (device-independent bits).
public struct HotKeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt16
    public var modifiers: UInt
    /// Display name of the key ("Space", "K", "F5").
    public var key: String

    public static let control: UInt = 1 << 18
    public static let option: UInt = 1 << 19
    public static let shift: UInt = 1 << 17
    public static let command: UInt = 1 << 20
    public static let modifierMask = control | option | shift | command

    public init(keyCode: UInt16, modifiers: UInt, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
        self.key = key
    }

    public static let space: UInt16 = 49
    public static let optionSpace = HotKeyCombo(keyCode: space, modifiers: option, key: "Space")
    public static let shiftOptionSpace = HotKeyCombo(keyCode: space, modifiers: shift | option, key: "Space")
    public static let controlShiftSpace = HotKeyCombo(keyCode: space, modifiers: control | shift, key: "Space")
    public static let hyperSpace = HotKeyCombo(keyCode: space, modifiers: control | option | command, key: "Space")

    /// Modifier symbols in the standard macOS order, then the key: ["⇧", "⌥", "Space"].
    public var symbols: [String] {
        var result: [String] = []
        if modifiers & Self.control != 0 { result.append("⌃") }
        if modifiers & Self.option != 0 { result.append("⌥") }
        if modifiers & Self.shift != 0 { result.append("⇧") }
        if modifiers & Self.command != 0 { result.append("⌘") }
        return result + [key]
    }

    public var label: String {
        let mods = symbols.dropLast().joined()
        return mods.isEmpty ? key : "\(mods) \(key)"
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var hotKey: HotKeyCombo = .optionSpace
    public var folders: [String] = ["~/Desktop", "~/Documents", "~/Downloads"]
    public var indexImages = true
    public var clipboardHistory = true
    public var maxFiles = 6000
    public var maxImages = 1500

    public init() {}

    /// Tolerant decoding: a field that is missing or changed type keeps its default instead of resetting everything.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        hotKey = (try? c.decode(HotKeyCombo.self, forKey: .hotKey)) ?? d.hotKey
        folders = (try? c.decode([String].self, forKey: .folders)) ?? d.folders
        indexImages = (try? c.decode(Bool.self, forKey: .indexImages)) ?? d.indexImages
        clipboardHistory = (try? c.decode(Bool.self, forKey: .clipboardHistory)) ?? d.clipboardHistory
        maxFiles = (try? c.decode(Int.self, forKey: .maxFiles)) ?? d.maxFiles
        maxImages = (try? c.decode(Int.self, forKey: .maxImages)) ?? d.maxImages
    }

    public var folderURLs: [URL] {
        folders.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }

    private static let key = "preferences"

    public static func load() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        return prefs
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// Set when the setup assistant has been completed.
    public static var setupCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "setupCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "setupCompleted") }
    }
}

public enum Paths {
    public static var appSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Concordance", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Where the setup assistant installs the model when none is found.
    public static var installedModel: URL { appSupport.appendingPathComponent("Model") }

    /// The EmbeddingGemma 2 bundle folder (the one holding config.json): inside the app, in Application Support,
    /// at $CONCORDANCE_MODEL, or in the source tree's Vendor folder.
    public static func modelBundle() -> URL? {
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["CONCORDANCE_MODEL"] {
            candidates.append(URL(fileURLWithPath: env))
        }
        if let resources = Bundle.main.resourceURL { candidates.append(resources.appendingPathComponent("model")) }
        candidates.append(installedModel)
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Vendor/EmbeddingGemma-2-CoreAI/model"))
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("config.json").path) }
    }
}
