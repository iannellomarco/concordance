import Foundation

/// Character-level matching: exact, prefix, word prefix, acronym, substring, then fuzzy subsequence.
public enum Lexical {
    public static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// 0 (no match) … 1 (exact). `query` must already be normalized.
    static func score(query q: String, item: SearchItem) -> Double {
        guard !q.isEmpty else { return 0 }
        var best = match(q, in: item.normalizedTitle)
        for keyword in item.normalizedKeywords where best < 0.75 {
            best = max(best, match(q, in: keyword) * 0.8)
        }
        return best
    }

    static func match(_ q: String, in t: String) -> Double {
        if t == q { return 1 }
        if t.hasPrefix(q) { return 0.9 + 0.08 * Double(q.count) / Double(max(t.count, 1)) }
        let words = t.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(q) }) { return 0.8 }
        let tokens = q.split(separator: " ")
        if tokens.count > 1, tokens.allSatisfy({ token in words.contains { $0.hasPrefix(token) } }) { return 0.78 }
        if q.count >= 2, String(words.compactMap(\.first)).hasPrefix(q) { return 0.75 }
        // "wifi" → "Wi-Fi", "textedit" → "Text Edit"
        if words.count > 1, words.joined().hasPrefix(q) { return 0.85 }
        if q.count >= 3, t.contains(q) { return 0.6 }
        if q.count >= 3, let compactness = subsequence(q, in: t, words: words), compactness >= 0.5 {
            return 0.25 + 0.3 * compactness
        }
        return 0
    }

    /// Characters of `q` in order inside `t`, starting at the beginning of a word: the ratio of query length to the
    /// matched span, or nil.
    static func subsequence(_ q: String, in t: String, words: [Substring]) -> Double? {
        guard let head = q.first, let start = words.first(where: { $0.first == head })?.startIndex else { return nil }
        var cursor = start
        var first: String.Index?
        var last = cursor
        var count = 0
        for ch in q where ch != " " {
            guard let found = t[cursor...].firstIndex(of: ch) else { return nil }
            if first == nil { first = found }
            last = found
            cursor = t.index(after: found)
            count += 1
        }
        guard let first else { return nil }
        return Double(count) / Double(t.distance(from: first, to: last) + 1)
    }
}
