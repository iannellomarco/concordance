import Foundation

public enum ItemKind: String, Codable, Sendable, CaseIterable {
    case application, settings, command, folder, file, image, clipboard, calculator, web, everpaper

    public var label: String {
        switch self {
        case .application: "Application"
        case .settings: "System Settings"
        case .command: "Command"
        case .folder: "Folder"
        case .file: "File"
        case .image: "Image"
        case .clipboard: "Clipboard"
        case .calculator: "Calculator"
        case .web: "Web"
        case .everpaper: "Everpaper"
        }
    }

    /// Small ranking bias: launching things beats opening files, which beats old clipboard entries.
    var prior: Double {
        switch self {
        case .application: 0.08
        case .settings, .command: 0.04
        case .folder, .file, .image: 0
        case .clipboard: -0.03
        case .calculator, .web, .everpaper: 0
        }
    }

    /// Whether the item's file lives on disk (icon from the file, reveal in Finder).
    public var isFileBacked: Bool {
        switch self {
        case .application, .folder, .file, .image: true
        default: false
        }
    }
}

public struct SearchItem: Identifiable, Hashable, Sendable {
    /// Stable identity, also the vector index key: "app:/Applications/Safari.app", "file:/…", "cmd:lock".
    public let id: String
    public let kind: ItemKind
    public var title: String
    public var subtitle: String
    public var keywords: [String]
    public var url: URL?
    /// SF Symbol for items without a file icon.
    public var symbol: String?
    public var date: Date?
    /// Changes whenever the embedded content changes; the index re-embeds an item on mismatch.
    public var signature: String
    /// Text to embed. Files are read at index time instead, images go through the vision encoder.
    public var text: String?
    /// Clipboard text or calculator result.
    public var payload: String?

    let normalizedTitle: String
    let normalizedKeywords: [String]

    public init(id: String, kind: ItemKind, title: String, subtitle: String = "", keywords: [String] = [],
                url: URL? = nil, symbol: String? = nil, date: Date? = nil, signature: String = "",
                text: String? = nil, payload: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.url = url
        self.symbol = symbol
        self.date = date
        self.signature = signature.isEmpty ? (text ?? title) : signature
        self.text = text
        self.payload = payload
        normalizedTitle = Lexical.normalize(title)
        normalizedKeywords = keywords.map(Lexical.normalize)
    }
}

public struct SearchResult: Identifiable, Hashable, Sendable {
    public var item: SearchItem
    public var score: Double
    /// True when the match came from meaning (EmbeddingGemma) rather than from the characters typed.
    public var semantic: Bool
    public var id: String { item.id }
}
