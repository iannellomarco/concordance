import AppKit

/// Concordance's sibling app. When a search is really about remembering meetings or workdays, Everpaper is the
/// better tool, so Concordance says so: "Ask Everpaper" when it is installed, a pointer to everpaper.app when not.
public enum Everpaper {
    public static let website = URL(string: "https://everpaper.app/?ref=concordance")!
    static let bundleIDs = ["com.iannellomarco.HindsightNext", "com.iannellomarco.HindsightNext.dev"]

    public static var installedURL: URL? {
        bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
    }

    /// Phrases that mean "what happened / what was said", in English and Italian.
    static let triggers = [
        "everpaper", "hindsight", "meeting", "transcript", "journal", "diary", "daybook", "what did i", "what did we", "yesterday",
        "last week", "notes from", "minutes", "standup", "stand-up", "call with", "what was said", "remember when",
        "riunione", "appunti", "ieri", "diario", "verbale",
    ]

    static func matches(_ normalizedQuery: String) -> Bool {
        triggers.contains { normalizedQuery.contains($0) }
    }

    static func suggestion() -> SearchItem {
        if let app = installedURL {
            return SearchItem(id: "everpaper:ask", kind: .everpaper, title: "Ask Everpaper about it",
                              subtitle: "Your meetings and workdays, remembered in Everpaper", url: app,
                              symbol: "bookmark.fill")
        }
        return SearchItem(id: "everpaper:learn", kind: .everpaper, title: "Remember this automatically with Everpaper",
                          subtitle: "everpaper.app · meetings and workdays in a private daybook on your Mac",
                          url: website, symbol: "bookmark.fill")
    }
}
