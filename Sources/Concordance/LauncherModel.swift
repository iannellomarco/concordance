import ConcordanceCore
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class LauncherModel {
    private(set) var query = ""
    private(set) var results: [SearchResult] = []
    var selection = 0
    /// Bumped on every show so the search field takes focus again.
    private(set) var focusToken = 0
    let engine: SearchEngine
    @ObservationIgnored var onClose: (() -> Void)?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(engine: SearchEngine) {
        self.engine = engine
    }

    var selected: SearchResult? { results.indices.contains(selection) ? results[selection] : nil }

    func setQuery(_ text: String) {
        guard text != query else { return }
        query = text
        search()
    }

    func willShow() {
        focusToken += 1
        if query.isEmpty { search() }
    }

    /// Re-runs the current query, e.g. when the catalog finished loading or the model became ready.
    func refresh() {
        search()
    }

    func reset() {
        query = ""
        selection = 0
        search()
    }

    /// Lexical results right away, then the EmbeddingGemma-ranked list a moment later (query embedding ≈5 ms).
    private func search() {
        searchTask?.cancel()
        let text = query
        searchTask = Task {
            apply(await engine.search(text, semantic: false))
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            let ranked = await engine.search(text, semantic: true)
            guard !Task.isCancelled else { return }
            apply(ranked)
        }
    }

    private func apply(_ new: [SearchResult]) {
        // Keep the user's highlighted row if they moved off the top one; otherwise follow the best match.
        let keep = selection > 0 ? selected?.id : nil
        results = new
        selection = keep.flatMap { id in new.firstIndex { $0.id == id } } ?? 0
    }

    /// Animated, so the glass selection flows to the new row.
    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        select((selection + delta + results.count) % results.count)
    }

    func select(_ index: Int) {
        withAnimation(.spring(duration: 0.32, bounce: 0.22)) { selection = index }
    }

    func run(_ result: SearchResult? = nil, alternate: Bool = false) {
        guard let result = result ?? selected else { return }
        onClose?()
        engine.frecency.record(result.id)
        ActionRunner.perform(result.item, alternate: alternate)
    }
}
