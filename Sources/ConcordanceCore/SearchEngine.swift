import EmbeddingGemma2CoreAI
import Foundation
import Observation

/// The catalog (apps, settings, commands, files, images, clipboard), its EmbeddingGemma 2 index and the hybrid
/// ranking: what you typed (lexical) and what you meant (cosine similarity in the shared text/image space).
@MainActor @Observable
public final class SearchEngine {
    public enum ModelStatus: Equatable, Sendable {
        case missing
        case loading(since: Date)
        case ready
        case failed(String)
    }

    public private(set) var modelStatus: ModelStatus = .missing
    public private(set) var catalogCount = 0
    public private(set) var indexedCount = 0
    public private(set) var pendingCount = 0
    /// Size of the current indexing pass (progress = 1 - pending / total).
    public private(set) var indexingTotal = 0
    public private(set) var isIndexing = false
    /// The last few items embedded, newest first (the setup assistant shows them as they arrive).
    public private(set) var recentlyIndexed: [SearchItem] = []
    /// Catalog size per kind.
    public private(set) var breakdown: [ItemKind: Int] = [:]
    /// Seconds the last model load took (≈1 s warm, minutes the first time).
    public private(set) var modelLoadSeconds: Double?
    public private(set) var preferences: Preferences
    /// While the launcher is on screen, image embedding (≈0.4 s each) pauses so queries never wait behind it.
    public var isInteractive = false

    @ObservationIgnored public let clipboard: ClipboardHistory
    @ObservationIgnored public let frecency = Frecency()
    @ObservationIgnored private let index: VectorIndex
    @ObservationIgnored private var service: EmbeddingService?
    @ObservationIgnored private var catalog: [SearchItem] = []
    @ObservationIgnored private var byID: [String: SearchItem] = [:]
    @ObservationIgnored private var indexTask: Task<Void, Never>?
    @ObservationIgnored private var indexAgain = false
    @ObservationIgnored private var staticItems: [SearchItem] = []
    @ObservationIgnored private var probeVectors: [[Float]] = []
    @ObservationIgnored private var hubStats: [String: (mean: Double, std: Double)] = [:]
    @ObservationIgnored private var hubStatsCount = -1
    @ObservationIgnored private var hubTask: Task<Void, Never>?
    @ObservationIgnored private var modelTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var lastFeedUpdate = Date.distantPast

    public init(preferences: Preferences, indexURL: URL = Paths.appSupport.appendingPathComponent("index.plist")) {
        self.preferences = preferences
        index = VectorIndex(fileURL: indexURL)
        clipboard = ClipboardHistory()
        indexedCount = index.count
        clipboard.onChange = { [weak self] in self?.clipboardChanged() }
    }

    /// App start: catalog first (lexical search works immediately), then the model, then indexing.
    public func start() {
        guard !started else { return }
        started = true
        if preferences.clipboardHistory { clipboard.start() }
        Task {
            await refreshCatalog()
            await loadModel()
            startIndexing()
        }
    }

    public var hasStarted: Bool { started }

    /// Loads the model once; concurrent callers wait for the same load.
    public func loadModel() async {
        if let modelTask {
            await modelTask.value
            return
        }
        guard service == nil else { return }
        guard let bundle = Paths.modelBundle() else {
            modelStatus = .missing
            return
        }
        let loadStart = Date()
        modelStatus = .loading(since: loadStart)
        let service = EmbeddingService(bundleURL: bundle, vision: preferences.indexImages)
        let task = Task {
            do {
                try await service.load()
                self.service = service
                modelLoadSeconds = Date().timeIntervalSince(loadStart)
                modelStatus = .ready
            } catch {
                modelStatus = .failed(String(describing: error))
            }
        }
        modelTask = task
        await task.value
        modelTask = nil
    }

    /// Starts loading the model without indexing anything (setup assistant, before folders are chosen).
    public func prepareModel() {
        Task { await loadModel() }
    }

    /// Replaces the preferences before `start()` without triggering any re-indexing.
    public func setInitialPreferences(_ new: Preferences) {
        preferences = new
        new.save()
    }

    public func shutdown() async {
        indexTask?.cancel()
        try? index.save()
        await service?.unload()
    }

    /// Synchronous variant for applicationWillTerminate: saves the index and removes this process's MPSGraph temp files.
    public func prepareForExit() {
        indexTask?.cancel()
        try? index.save()
        _ = EmbeddingGemma2.removeOwnMPSGraphTempFiles()
    }

    // MARK: - Catalog

    public func refreshCatalog() async {
        let prefs = preferences
        let collected = await Task.detached(priority: .utility) {
            let apps = ApplicationSource.items()
            let files = FileSource(roots: prefs.folderURLs, maxItems: prefs.maxFiles + prefs.maxImages).items()
            return (apps, files)
        }.value
        staticItems = collected.0 + SettingsSource.items() + CommandSource.items() + collected.1
        rebuildCatalog()
        index.retain(only: Set(byID.keys))
        indexedCount = index.count
    }

    private func rebuildCatalog() {
        let clips = preferences.clipboardHistory ? clipboard.items() : []
        catalog = staticItems + clips
        byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        catalogCount = catalog.count
        breakdown = Dictionary(grouping: catalog, by: \.kind).mapValues(\.count)
    }

    private func clipboardChanged() {
        rebuildCatalog()
        startIndexing()
    }

    public func update(preferences new: Preferences) {
        let old = preferences
        preferences = new
        new.save()
        if new.clipboardHistory != old.clipboardHistory {
            new.clipboardHistory ? clipboard.start() : clipboard.stop()
        }
        Task {
            if new.indexImages != old.indexImages {
                // The vision encoder is loaded (or dropped) with the model.
                indexTask?.cancel()
                await service?.unload()
                service = nil
                await loadModel()
            }
            if new.folders != old.folders || new.maxFiles != old.maxFiles || new.maxImages != old.maxImages
                || new.indexImages != old.indexImages || new.clipboardHistory != old.clipboardHistory {
                await refreshCatalog()
            }
            startIndexing()
        }
    }

    public func rebuildIndex() {
        indexTask?.cancel()
        index.removeAll()
        indexedCount = 0
        Task {
            await refreshCatalog()
            startIndexing()
        }
    }

    // MARK: - Indexing

    public func startIndexing() {
        guard let service else { return }
        if let indexTask, !indexTask.isCancelled {
            indexAgain = true
            return
        }
        indexTask = Task { [weak self] in
            repeat {
                self?.indexAgain = false
                await self?.indexPass(service)
            } while self?.indexAgain == true && !Task.isCancelled
            // A cancelled task may already have been replaced by a newer one; leave that one alone.
            if !Task.isCancelled { self?.indexTask = nil }
        }
    }

    /// Waits until the current indexing pass (if any) is done. Used by the CLI.
    public func waitForIndexing() async {
        await indexTask?.value
    }

    private func indexPass(_ service: EmbeddingService) async {
        let vision = await service.hasVision
        let todo = catalog.filter { $0.kind != .image && index.needsEmbedding($0) }
        let images = vision
            ? Array(catalog.filter { $0.kind == .image }.prefix(preferences.maxImages)).filter(index.needsEmbedding)
            : []
        pendingCount = todo.count + images.count
        indexingTotal = pendingCount
        isIndexing = pendingCount > 0
        defer { isIndexing = false }
        var sinceSave = 0

        for item in todo + images {
            if Task.isCancelled { break }
            while item.kind == .image, isInteractive, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
            }
            do {
                if item.kind == .image, let url = item.url {
                    index.set(item.id, signature: item.signature, vector: try await service.embedImage(url: url),
                              snippet: nil)
                } else {
                    let (text, snippet) = await Task.detached(priority: .utility) {
                        TextExtractor.embeddingText(for: item)
                    }.value
                    index.set(item.id, signature: item.signature, vector: try await service.embedDocument(text),
                              snippet: snippet)
                }
            } catch {
                // Unreadable or undecodable: remember the signature so it is not retried until the file changes.
                index.set(item.id, signature: item.signature, vector: [], snippet: nil)
            }
            pendingCount = max(0, pendingCount - 1)
            // Text items index at ~100/s; sample the feed so it reads as a stream rather than a blur.
            if Date().timeIntervalSince(lastFeedUpdate) > 0.3 {
                recentlyIndexed.insert(item, at: 0)
                if recentlyIndexed.count > 8 { recentlyIndexed.removeLast() }
                lastFeedUpdate = Date()
            }
            sinceSave += 1
            if sinceSave % 25 == 0 { indexedCount = index.count }
            if sinceSave >= 200 {
                sinceSave = 0
                try? index.save()
            }
        }
        indexedCount = index.count
        pendingCount = 0
        try? index.save()
        await refreshHubStats(service)
    }

    // MARK: - Search

    /// `semantic: false` returns instantly (lexical only); `true` also embeds the query and ranks by meaning.
    public func search(_ raw: String, semantic: Bool = true, limit: Int = 60) async -> [SearchResult] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return suggestions() }
        let normalized = Lexical.normalize(query)

        var relevance: [String: Double] = [:]
        if semantic, query.count >= 3, let service {
            do {
                let vector = try await service.embedQuery(query)
                await refreshHubStats(service)
                relevance = semanticRelevance(index.similarities(to: vector))
            } catch {
                Self.debug("embedQuery failed: \(error)")
            }
        }
        Self.debug("search “\(query)” semantic=\(semantic) service=\(service != nil) relevant=\(relevance.count) hub=\(hubStats.count)")

        var results: [SearchResult] = []
        for item in catalog {
            let lexical = Lexical.score(query: normalized, item: item)
            let meaning = relevance[item.id] ?? 0
            // Weak meaning-only matches (z below ≈3.7) are mostly noise; leave them out.
            guard lexical > 0 || meaning >= 0.1 else { continue }
            let score = max(lexical, meaning * 0.92) + 0.1 * min(lexical, meaning) + item.kind.prior
                + frecency.boost(item.id) + recency(item)
            results.append(SearchResult(item: item, score: score, semantic: meaning > lexical))
        }
        results.sort { $0.score > $1.score }
        results = Array(results.prefix(limit))

        if let value = Calculator.evaluate(query) {
            let text = Calculator.format(value)
            let item = SearchItem(id: "calc", kind: .calculator, title: text, subtitle: "\(query) =  ·  ↵ to copy",
                                  symbol: "equal.square.fill", payload: text)
            results.insert(SearchResult(item: item, score: 10, semantic: false), at: 0)
        }
        if Everpaper.matches(normalized) {
            results.append(SearchResult(item: Everpaper.suggestion(), score: 0, semantic: false))
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        results.append(SearchResult(
            item: SearchItem(id: "web:google", kind: .web, title: "Search the web for “\(query)”",
                             subtitle: "Google", url: URL(string: "https://www.google.com/search?q=\(encoded)"),
                             symbol: "globe"),
            score: 0, semantic: false))
        return results
    }

    /// Cosine similarity → 0…1 relevance. EmbeddingGemma's space is anisotropic: for any query every item scores
    /// 0.5–0.6, and that baseline moves from query to query. What carries meaning is how far an item stands out from
    /// the rest, so each query's similarities are turned into z-scores, separately for images and for text (text-to-
    /// image similarities sit on their own scale).
    func semanticRelevance(_ similarities: [String: Float]) -> [String: Double] {
        zScores(similarities).compactMapValues { z in
            let r = Self.calibrate(z: z)
            return r > 0 ? r : nil
        }
    }

    func zScores(_ similarities: [String: Float]) -> [String: Double] {
        var pools: [Bool: [(String, Double)]] = [:]
        for (id, cosine) in similarities {
            guard let kind = byID[id]?.kind else { continue }
            var value = Double(cosine)
            if Self.hubCorrection, let hub = hubStats[id] { value = (value - hub.mean) / hub.std }
            pools[kind == .image, default: []].append((id, value))
        }
        var result: [String: Double] = [:]
        for pool in pools.values where pool.count >= 20 {
            let mean = pool.map(\.1).reduce(0, +) / Double(pool.count)
            let variance = pool.map { ($0.1 - mean) * ($0.1 - mean) }.reduce(0, +) / Double(pool.count)
            let std = max(variance.squareRoot(), 1e-4)
            for (id, value) in pool { result[id] = (value - mean) / std }
        }
        return result
    }

    /// Per-item cosine and z-score for a query, best first (calibration and debugging).
    public func semanticScores(_ query: String) async -> [(item: SearchItem, cosine: Float, z: Double)] {
        guard let service, let vector = try? await service.embedQuery(query) else { return [] }
        await refreshHubStats(service)
        let similarities = index.similarities(to: vector)
        let z = zScores(similarities)
        return similarities.compactMap { id, cos in byID[id].map { ($0, cos, z[id] ?? 0) } }.sorted { $0.z > $1.z }
    }

    /// Hubness correction: some items (long JSON logs, keystores, generic folders) sit close to *every* query. Each
    /// item's similarity is first expressed relative to its own mean and spread over a fixed bank of unrelated probe
    /// queries, so only similarity above what the item gets anyway counts.
    public static var hubCorrection = true

    static let probeQueries = [
        "weather tomorrow", "play some music", "recipe for dinner", "book a flight", "an error message",
        "a photo of a beach", "change my password", "a video call", "football results", "learn a language",
        "a spreadsheet of expenses", "the news today", "fix a bug in the code", "a birthday party", "buy a new phone",
        "a map of the city", "a slide presentation", "a legal document", "a cat", "draw a picture",
        "system preferences", "download a file", "a text message", "an old letter", "a calendar event",
        "the colour blue", "a job interview", "health and fitness", "a car repair", "a screenshot of an app",
        "a song lyric", "printer settings", "a science paper", "a shopping list", "a children's story",
        "the stock market", "a train timetable", "an invoice", "a website", "a logo design",
    ]

    /// Computes the per-item probe statistics in a task of its own: searches are cancelled on every keystroke, and
    /// that must not cancel (or half-fill) this one-time work. Searches wait for it, which never cancels it.
    private func refreshHubStats(_ service: EmbeddingService) async {
        guard Self.hubCorrection else { return }
        if hubTask == nil, hubStatsCount != index.count {
            hubTask = Task { [weak self] in
                await self?.computeHubStats(service)
                self?.hubTask = nil
            }
        }
        await hubTask?.value
    }

    private func computeHubStats(_ service: EmbeddingService) async {
        if probeVectors.count < Self.probeQueries.count {
            var vectors: [[Float]] = []
            for probe in Self.probeQueries {
                if let v = try? await service.embedQuery(probe) { vectors.append(v) }
            }
            guard vectors.count == Self.probeQueries.count else { return }
            probeVectors = vectors
        }
        let count = index.count
        var sums: [String: (Double, Double)] = [:]
        for probe in probeVectors {
            for (id, cosine) in index.similarities(to: probe) {
                let c = Double(cosine)
                let (s1, s2) = sums[id] ?? (0, 0)
                sums[id] = (s1 + c, s2 + c * c)
            }
        }
        let n = Double(probeVectors.count)
        hubStats = sums.mapValues { s1, s2 in
            let mean = s1 / n
            return (mean, max((s2 / n - mean * mean).squareRoot(), 0.01))
        }
        hubStatsCount = count
    }

    /// z-score → relevance in 0…0.9: nothing at or below `zFloor`, then a soft saturation so that order among strong
    /// matches is kept (z 9 still beats z 8).
    public static var zFloor = 3.3
    public static var zSpan = 3.0

    static func calibrate(z: Double) -> Double {
        guard z > zFloor else { return 0 }
        return 0.9 * (1 - exp(-(z - zFloor) / zSpan))
    }

    static let debugEnabled = ProcessInfo.processInfo.environment["CONCORDANCE_DEBUG"] != nil
    static func debug(_ message: @autoclosure () -> String) {
        if debugEnabled { FileHandle.standardError.write(Data("[concordance] \(message())\n".utf8)) }
    }

    private func recency(_ item: SearchItem) -> Double {
        guard item.kind == .clipboard || item.kind == .file || item.kind == .image, let date = item.date else { return 0 }
        return 0.03 * exp(-max(0, -date.timeIntervalSinceNow) / (86_400 * 7))
    }

    private func suggestions() -> [SearchResult] {
        var ids = frecency.topIDs(8).filter { byID[$0] != nil }
        if ids.count < 8 {
            ids += ["cmd:lock", "settings:com.apple.wifi-settings-extension", "cmd:screenshot", "cmd:settings"]
                .filter { !ids.contains($0) && byID[$0] != nil }
        }
        let recentClips = catalog.filter { $0.kind == .clipboard }.prefix(3).map(\.id)
        let items = (ids.prefix(8) + recentClips).compactMap { byID[$0] }
            .map { SearchResult(item: $0, score: 0, semantic: false) }
        // The empty state is the one place a pointer to Everpaper is always welcome, not only on matching searches.
        return items + (items.count < 8 ? [SearchResult(item: Everpaper.suggestion(), score: 0, semantic: false)] : [])
    }

    public func snippet(for item: SearchItem) -> String? {
        item.payload ?? index.snippet(for: item.id)
    }
}
