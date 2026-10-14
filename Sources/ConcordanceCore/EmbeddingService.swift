import CoreGraphics
import EmbeddingGemma2CoreAI
import Foundation

/// Owns the EmbeddingGemma 2 model. Calls run one at a time (the Neural Engine serializes them anyway); queries
/// jump ahead of queued indexing work so typing stays responsive while the index builds.
public actor EmbeddingService {
    public let bundleURL: URL
    public let vision: Bool
    private var model: EmbeddingGemma2?
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var queryCache: [String: [Float]] = [:]

    public init(bundleURL: URL, vision: Bool) {
        self.bundleURL = bundleURL
        self.vision = vision
    }

    /// Loads and warms the model. The first load by a new app specializes the graphs for this Mac's Neural Engine,
    /// which takes a few minutes; later loads take about a second.
    public func load() async throws {
        guard model == nil else { return }
        let loaded = try await EmbeddingGemma2(bundle: bundleURL, compute: .neuralEngine, loadVision: vision)
        _ = try await loaded.prewarm()
        model = loaded
    }

    public var isLoaded: Bool { model != nil }
    public var hasVision: Bool { model?.hasVision ?? false }

    public func embedQuery(_ text: String) async throws -> [Float] {
        if let cached = queryCache[text] { return cached }
        let vector = try await run(priority: true) { try await $0.embed(text, kind: "search_query") }
        if queryCache.count > 256 { queryCache.removeAll() }
        queryCache[text] = vector
        return vector
    }

    /// `text` is already in document format ("title: … | text: …"), so no prompt prefix is added.
    public func embedDocument(_ text: String) async throws -> [Float] {
        try await run(priority: false) { try await $0.embed(text, kind: nil) }
    }

    public func embedImage(url: URL) async throws -> [Float] {
        try await run(priority: false) { try await $0.embedImage(url: url, applyEXIFOrientation: true) }
    }

    public func unload() {
        model = nil
        _ = EmbeddingGemma2.removeOwnMPSGraphTempFiles()
    }

    private func run(priority: Bool, _ body: (EmbeddingGemma2) async throws -> [Float]) async throws -> [Float] {
        guard let model else { throw EmbedderError(description: "EmbeddingGemma 2 is not loaded yet") }
        await acquire(priority: priority)
        defer { release() }
        return try await body(model)
    }

    private func acquire(priority: Bool) async {
        guard busy else { busy = true; return }
        await withCheckedContinuation { continuation in
            if priority { waiters.insert(continuation, at: 0) } else { waiters.append(continuation) }
        }
    }

    private func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }
}
