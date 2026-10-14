import Foundation

/// How often and how recently each item was opened; frequently used items rank a little higher.
@MainActor
public final class Frecency {
    struct Record: Codable {
        var count: Int
        var last: Date
    }

    private var records: [String: Record]
    private static let key = "frecency"

    public init() {
        records = (UserDefaults.standard.data(forKey: Self.key))
            .flatMap { try? JSONDecoder().decode([String: Record].self, from: $0) } ?? [:]
    }

    public func record(_ id: String) {
        var r = records[id] ?? Record(count: 0, last: .distantPast)
        r.count += 1
        r.last = Date()
        records[id] = r
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    func boost(_ id: String) -> Double {
        guard let r = records[id] else { return 0 }
        let days = max(0, -r.last.timeIntervalSinceNow / 86_400)
        return min(0.15, 0.04 * log2(1 + Double(r.count))) * exp(-days / 30)
    }

    func topIDs(_ n: Int) -> [String] {
        records.sorted { boost($0.key) > boost($1.key) }.prefix(n).map(\.key)
    }
}
