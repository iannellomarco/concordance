import ConcordanceCore
import SwiftUI

struct LauncherView: View {
    let model: LauncherModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Rectangle().fill(Paper.inkTertiary.opacity(0.16)).frame(height: 1).padding(.horizontal, 14)
            HStack(spacing: 0) {
                resultList
                if let selected = model.selected, showsPreview(selected.item) {
                    PreviewPane(item: selected.item, snippet: model.engine.snippet(for: selected.item))
                        .frame(width: 270)
                        .padding([.vertical, .trailing], 10)
                        .transition(.opacity.combined(with: .offset(x: 12)))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(duration: 0.3), value: model.selected.map { showsPreview($0.item) })
            FooterBar(engine: model.engine, selected: model.selected)
        }
        .frame(width: 760, height: 480)
        // The window itself is warm Liquid Glass (LauncherPanel); everything here sits on it.
        .foregroundStyle(Paper.inkPrimary)
        .tint(Paper.tint)
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { searchFocused = true }
        .onChange(of: model.engine.catalogCount) { model.refresh() }
        .onChange(of: model.engine.modelStatus) { model.refresh() }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Paper.tint)
            TextField("Search apps, files, screenshots, commands… or describe what you need",
                      text: Binding(get: { model.query }, set: { model.setQuery($0) }))
                .textFieldStyle(.plain)
                .font(Paper.serif(22))
                .foregroundStyle(Paper.inkPrimary)
                .focused($searchFocused)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // One pane of glass that slides under the selected row. (A glassEffectID morph flows beautifully but
                // blurs the rows' text while it moves, which a launcher you arrow through quickly cannot afford.)
                ZStack(alignment: .top) {
                    if !model.results.isEmpty {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular.tint(Paper.selectionGlass), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .frame(height: ResultRow.height)
                            .offset(y: CGFloat(model.selection) * (ResultRow.height + ResultRow.spacing))
                            .allowsHitTesting(false)
                    }
                    LazyVStack(spacing: ResultRow.spacing) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { offset, result in
                            ResultRow(result: result, isSelected: offset == model.selection, onGlass: true)
                                .id(result.id)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { model.run(result) }
                                .onTapGesture { model.select(offset) }
                        }
                    }
                }
                .padding(10)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selection) {
                if let id = model.selected?.id { proxy.scrollTo(id) }
            }
        }
    }

    private func showsPreview(_ item: SearchItem) -> Bool {
        switch item.kind {
        case .file, .image, .clipboard, .folder: true
        default: false
        }
    }
}

struct ResultRow: View {
    static let height: CGFloat = 46
    static let spacing: CGFloat = 2

    let result: SearchResult
    let isSelected: Bool
    /// True when the list draws one sliding glass selection behind the rows; otherwise the row tints itself.
    var onGlass = false

    var body: some View {
        HStack(spacing: 12) {
            ItemIcon(item: result.item)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.item.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Paper.inkPrimary)
                    .lineLimit(1)
                if !result.item.subtitle.isEmpty {
                    Text(result.item.subtitle).font(.system(size: 11.5)).foregroundStyle(Paper.inkTertiary).lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if result.semantic {
                // The rubric marks acts of meaning: here, a match by what you meant.
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Paper.tint)
                    .help("Matched by meaning (EmbeddingGemma 2)")
            }
            Text(result.item.kind.label).font(.system(size: 11.5)).foregroundStyle(Paper.inkTertiary)
        }
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .background(isSelected && !onGlass ? Paper.selectionGlass : .clear,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        // Everpaper's non-color selection cue: a rubric edge.
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule().fill(Paper.tint).frame(width: 3).padding(.vertical, 12).padding(.leading, 3)
            }
        }
    }
}

struct PreviewPane: View {
    let item: SearchItem
    let snippet: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.kind == .image, let url = item.url {
                ImagePreview(url: url)
            } else {
                ItemIcon(item: item, side: 56)
            }
            Text(item.title).font(Paper.serif(16, .medium)).foregroundStyle(Paper.inkPrimary).lineLimit(3)
            if let snippet, !snippet.isEmpty {
                Text(snippet).font(Paper.serif(13)).lineSpacing(3).foregroundStyle(Paper.inkSecondary).lineLimit(13)
            }
            Spacer(minLength: 0)
            if let date = item.date {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(Paper.mono(10)).foregroundStyle(Paper.inkTertiary)
            }
            if item.kind.isFileBacked {
                Text(item.subtitle).font(Paper.mono(10)).foregroundStyle(Paper.inkTertiary).lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular.tint(Paper.glassTint), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ImagePreview: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Paper.inkTertiary.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
        .task(id: url) { image = await Icons.thumbnail(for: url, side: 480) }
    }
}

struct FooterBar: View {
    let engine: SearchEngine
    let selected: SearchResult?

    var body: some View {
        HStack(spacing: 14) {
            status.lineLimit(1)
            Spacer()
            if let selected {
                hint("↵", primaryAction(selected.item))
                if selected.item.kind.isFileBacked { hint("⌘↵", "Show in Finder") }
            }
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 16)
        .frame(height: 38)
    }

    @ViewBuilder private var status: some View {
        HStack(spacing: 6) {
            switch engine.modelStatus {
            case .ready:
                Circle().fill(Paper.success).frame(width: 7, height: 7)
                if engine.pendingCount > 0 {
                    Text("EmbeddingGemma 2 · indexing, \(engine.pendingCount) to go")
                } else {
                    Text("EmbeddingGemma 2 · \(engine.indexedCount) items understood")
                }
            case .loading(let since):
                ProgressView().controlSize(.mini)
                TimelineView(.periodic(from: since, by: 1)) { context in
                    Text("Preparing EmbeddingGemma 2… \(Int(context.date.timeIntervalSince(since))) s · first launch only")
                        .help("Core AI specializes the model for this Mac's Neural Engine once; it takes a few minutes.")
                }
            case .missing:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Paper.warning)
                Text("Model not found: run scripts/fetch-model.sh. Matching by name only.")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Paper.warning)
                Text("Model failed: \(message)").lineLimit(1)
            }
        }
        .foregroundStyle(Paper.inkSecondary)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(label).foregroundStyle(Paper.inkSecondary)
            Text(key)
                .foregroundStyle(Paper.inkPrimary)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .glassCapsule()
        }
    }

    private func primaryAction(_ item: SearchItem) -> String {
        switch item.kind {
        case .application: "Open Application"
        case .command: "Run Command"
        case .clipboard, .calculator: "Copy"
        case .web: "Search"
        default: "Open"
        }
    }
}
