import Accelerate
import Foundation

/// Item id → (content signature, L2-normalized 768-d EmbeddingGemma vector). Brute-force cosine search: 10 000 items
/// take about a millisecond. Persisted as a binary property list in Application Support.
public final class VectorIndex: @unchecked Sendable {
    public static let modelID = "embeddinggemma-2-coreai-1.2"

    struct Entry: Codable {
        var signature: String
        var vector: [Float]   // empty when embedding failed (not retried until the signature changes)
        var snippet: String?

        enum CodingKeys: String, CodingKey { case signature, vector, snippet }

        init(signature: String, vector: [Float], snippet: String?) {
            self.signature = signature
            self.vector = vector
            self.snippet = snippet
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            signature = try c.decode(String.self, forKey: .signature)
            snippet = try c.decodeIfPresent(String.self, forKey: .snippet)
            let data = try c.decode(Data.self, forKey: .vector)
            vector = [Float](unsafeUninitializedCapacity: data.count / MemoryLayout<Float>.size) { buffer, count in
                count = data.copyBytes(to: buffer) / MemoryLayout<Float>.size
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(signature, forKey: .signature)
            try c.encodeIfPresent(snippet, forKey: .snippet)
            try c.encode(vector.withUnsafeBufferPointer { Data(buffer: $0) }, forKey: .vector)
        }
    }

    private struct Stored: Codable {
        var model: String
        var dim: Int
        var entries: [String: Entry]
    }

    public let fileURL: URL
    public let dim: Int
    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    public init(fileURL: URL, dim: Int = 768) {
        self.fileURL = fileURL
        self.dim = dim
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? PropertyListDecoder().decode(Stored.self, from: data),
           stored.model == Self.modelID, stored.dim == dim {
            entries = stored.entries
        }
    }

    public var count: Int { lock.withLock { entries.values.count { !$0.vector.isEmpty } } }

    public func needsEmbedding(_ item: SearchItem) -> Bool {
        lock.withLock { entries[item.id]?.signature != item.signature }
    }

    func set(_ id: String, signature: String, vector: [Float], snippet: String?) {
        lock.withLock { entries[id] = Entry(signature: signature, vector: vector, snippet: snippet) }
    }

    func snippet(for id: String) -> String? { lock.withLock { entries[id]?.snippet } }

    /// Drops entries whose items left the catalog (deleted files, uninstalled apps).
    func retain(only ids: Set<String>) {
        lock.withLock { entries = entries.filter { ids.contains($0.key) } }
    }

    func removeAll() { lock.withLock { entries.removeAll() } }

    /// Cosine similarity of every stored vector with `query` (both L2-normalized, so a dot product).
    func similarities(to query: [Float]) -> [String: Float] {
        precondition(query.count == dim)
        return lock.withLock {
            var result: [String: Float] = [:]
            result.reserveCapacity(entries.count)
            for (id, entry) in entries where entry.vector.count == dim {
                var dot: Float = 0
                vDSP_dotpr(entry.vector, 1, query, 1, &dot, vDSP_Length(dim))
                result[id] = dot
            }
            return result
        }
    }

    public func save() throws {
        let stored = lock.withLock { Stored(model: Self.modelID, dim: dim, entries: entries) }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(stored).write(to: fileURL, options: .atomic)
    }
}
