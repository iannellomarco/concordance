import ConcordanceCore
import SwiftUI

struct SetupView: View {
    @Bindable var model: SetupModel

    var body: some View {
        ZStack {
            GlassBackdrop(glow: model.step.glow)
            VStack(spacing: 0) {
                ZStack {
                    stepView
                        .id(model.step)
                        .transition(.asymmetric(
                            insertion: .offset(x: model.forward ? 60 : -60).combined(with: .opacity),
                            removal: .offset(x: model.forward ? -60 : 60).combined(with: .opacity)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if model.step != .welcome && model.step != .done {
                    footer.transition(.opacity)
                }
            }
            .padding(.horizontal, 52)
            .padding(.top, 44)
            .padding(.bottom, 26)
        }
        .frame(width: 940, height: 640)
        .tint(Paper.tint)
        .foregroundStyle(Paper.inkPrimary)
        .onAppear { model.begin() }
    }

    @ViewBuilder private var stepView: some View {
        switch model.step {
        case .welcome: WelcomeStep(model: model)
        case .model: ModelStep(model: model)
        case .shortcut: ShortcutStep(model: model)
        case .folders: FoldersStep(model: model)
        case .indexing: IndexingStep(model: model)
        case .done: DoneStep(model: model)
        }
    }

    private var footer: some View {
        HStack {
            Button { model.back() } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .secondaryGlassButton()
            .keyboardShortcut(.cancelAction)

            Spacer()
            StepDots(current: model.step.rawValue - 1, count: 4)
            Spacer()

            Button { model.next() } label: {
                Text(primaryLabel).frame(minWidth: 96)
            }
            .primaryGlassButton()
            .keyboardShortcut(.defaultAction)
            .disabled(model.step == .folders && model.prefs.folders.isEmpty && !model.prefs.indexImages
                && !model.prefs.clipboardHistory)
        }
    }

    private var primaryLabel: String {
        switch model.step {
        case .folders: "Start Indexing"
        case .indexing: model.engine.isIndexing ? "Continue in Background" : "Continue"
        default: "Continue"
        }
    }
}

// MARK: - Shared pieces

/// Folio-style progress: past steps inked, the current one a rubric rule, future ones hairlines.
struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Paper.tint : (i < current ? Paper.inkTertiary : Paper.edge))
                    .frame(width: i == current ? 26 : 8, height: i == current ? 3 : 8)
            }
        }
        .frame(height: 8)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: current)
    }
}

struct StepHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(eyebrow).eyebrow().entrance(0)
            Text(title)
                .font(Paper.serif(34, .medium))
                .tracking(-0.4)
                .foregroundStyle(Paper.inkPrimary)
                .entrance(0.05)
            // Everpaper's rubric rule under page titles, drawn left to right on appear.
            RubricRule().frame(width: 44).entrance(0.08)
            Text(subtitle)
                .font(Paper.serif(16))
                .lineSpacing(4)
                .foregroundStyle(Paper.inkSecondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(0.1)
        }
    }
}

struct RubricRule: View {
    @State private var drawn = false

    var body: some View {
        Capsule().fill(Paper.tint).frame(height: 2)
            .scaleEffect(x: drawn ? 1 : 0, anchor: .leading)
            .onAppear { withAnimation(.easeOut(duration: 0.2).delay(0.25)) { drawn = true } }
    }
}

/// Fade, settle and un-blur in on appear, after `delay`.
private struct Entrance: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            .blur(radius: visible ? 0 : 4)
            .onAppear {
                withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(delay)) { visible = true }
            }
    }
}

extension View {
    func entrance(_ delay: Double) -> some View { modifier(Entrance(delay: delay)) }
}

// MARK: - Welcome

struct WelcomeStep: View {
    let model: SetupModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HeroOrb(size: 112).entrance(0)
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("Concordance")
                        .font(Paper.serif(60, .medium))
                        .tracking(-0.8)
                        .foregroundStyle(Paper.inkPrimary)
                    // The mono face's baseline sits slightly high against the serif; nudge it down to meet it.
                    Text("by everpaper.app")
                        .font(Paper.mono(15))
                        .foregroundStyle(Paper.tint)
                        .offset(y: 3)
                }
                Text("Find anything on your Mac by what it means,\nnot just by what it's called.")
                    .font(Paper.serifItalic(19))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .foregroundStyle(Paper.inkSecondary)
            }
            .padding(.top, 8)
            .entrance(0.15)
            DemoSearchBar()
                .padding(.top, 30)
                .frame(height: 140, alignment: .top)
                .entrance(0.35)
            Spacer(minLength: 0)
            Button { model.next() } label: {
                Text("Get Started").frame(width: 180)
            }
            .primaryGlassButton(large: true)
            .keyboardShortcut(.defaultAction)
            .entrance(0.55)
            Label("Runs on your Mac's Neural Engine. Nothing you search or index leaves this computer.",
                  systemImage: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkTertiary)
                .padding(.top, 16)
                .entrance(0.65)
        }
    }
}

// MARK: - Model

struct ModelStep: View {
    let model: SetupModel

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 22) {
                StepHeader(eyebrow: "Step 1 of 4", title: "Meet EmbeddingGemma\u{00A0}2",
                           subtitle: "Google's open embedding model, converted for Apple's Core AI. It turns text and images into meaning, right here on the Neural Engine.")
                VStack(spacing: 0) {
                    filesRow
                    Rectangle().fill(Paper.inkTertiary.opacity(0.18)).frame(height: 1).padding(.horizontal, 16)
                    engineRow
                }
                .glassPane(padding: 0)
                .entrance(0.2)
                HStack(spacing: 8) {
                    ForEach(["768 dimensions", "Text + images", "Multilingual", "Private"], id: \.self) { fact in
                        Text(fact)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Paper.inkSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassCapsule()
                    }
                }
                .entrance(0.3)
            }
            .frame(width: 430)

            ZStack(alignment: .bottomLeading) {
                NeuralField(activity: engineActivity, done: model.engine.modelStatus == .ready)
                    .padding(22)
                HStack(spacing: 8) {
                    Image(systemName: "cpu").font(.system(size: 11, weight: .semibold))
                    Text("Apple Neural Engine")
                }
                .eyebrow()
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: 380)
            .glassEffect(.regular.tint(Paper.well.opacity(0.35)), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .entrance(0.15)
        }
    }

    private var engineActivity: Double {
        switch model.engine.modelStatus {
        case .loading: 1
        case .ready: 0
        default: model.installer.phase == .downloading ? 0.35 : 0.1
        }
    }

    @ViewBuilder private var filesRow: some View {
        let installer = model.installer
        switch installer.phase {
        case .idle where model.modelFound, .installed:
            ChecklistRow(state: .done, title: "Model files",
                         detail: installer.phase == .installed ? "Downloaded and verified" : "Installed · text 603 MB, vision 293 MB")
        case .idle, .listing:
            ChecklistRow(state: .active, title: "Model files", detail: "Contacting Hugging Face…")
        case .downloading:
            ChecklistRow(state: .active, title: "Downloading model",
                         detail: downloadDetail(installer), progress: installer.fraction)
        case .verifying:
            ChecklistRow(state: .active, title: "Verifying", detail: "Checking every file against its SHA-256…")
        case .failed(let message):
            ChecklistRow(state: .failed, title: "Download failed", detail: message) {
                Button("Retry") { model.downloadModel() }.secondaryGlassButton()
            }
        }
    }

    private func downloadDetail(_ installer: ModelInstaller) -> String {
        let done = ByteCountFormatter.string(fromByteCount: installer.receivedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: installer.totalBytes, countStyle: .file)
        var text = "\(done) of \(total)"
        if installer.speed > 0 {
            text += " · \(ByteCountFormatter.string(fromByteCount: Int64(installer.speed), countStyle: .file))/s"
        }
        return text
    }

    @ViewBuilder private var engineRow: some View {
        switch model.engine.modelStatus {
        case .missing:
            ChecklistRow(state: .pending, title: "Optimize for this Mac", detail: "Starts when the files are ready")
        case .loading(let since):
            TimelineView(.periodic(from: since, by: 1)) { context in
                let elapsed = Int(context.date.timeIntervalSince(since))
                ChecklistRow(state: .active, title: "Optimizing for your Neural Engine",
                             detail: "\(elapsed / 60):\(String(format: "%02d", elapsed % 60)) · only once, usually about 3 minutes. You can continue.")
            }
        case .ready:
            ChecklistRow(state: .done, title: "Ready on the Neural Engine",
                         detail: model.engine.modelLoadSeconds.map { "Loaded in \(String(format: "%.1f", $0)) s" } ?? "Loaded")
        case .failed(let message):
            ChecklistRow(state: .failed, title: "Could not load the model", detail: message)
        }
    }
}

struct ChecklistRow<Accessory: View>: View {
    enum State { case pending, active, done, failed }
    let state: State
    let title: String
    let detail: String
    var progress: Double?
    @ViewBuilder var accessory: () -> Accessory

    init(state: State, title: String, detail: String, progress: Double? = nil,
         @ViewBuilder accessory: @escaping () -> Accessory) {
        self.state = state
        self.title = title
        self.detail = detail
        self.progress = progress
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                switch state {
                case .pending:
                    Circle().strokeBorder(Paper.edge, lineWidth: 1.5)
                case .active:
                    ProgressView().controlSize(.small)
                case .done:
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 21)).foregroundStyle(Paper.success)
                        .transition(.scale.combined(with: .opacity))
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 18)).foregroundStyle(Paper.warning)
                }
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.inkPrimary)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Paper.inkSecondary)
                if let progress {
                    ProgressView(value: progress).progressViewStyle(.linear).tint(Paper.tint).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            accessory()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .animation(.spring(duration: 0.4), value: state)
    }
}

extension ChecklistRow where Accessory == EmptyView {
    init(state: State, title: String, detail: String, progress: Double? = nil) {
        self.init(state: state, title: title, detail: detail, progress: progress) { EmptyView() }
    }
}

// MARK: - Shortcut

struct ShortcutStep: View {
    let model: SetupModel

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(eyebrow: "Step 2 of 4", title: "Summon it from anywhere",
                       subtitle: "Pick a shortcut that nothing else on this Mac already uses.", alignment: .center)
            Spacer(minLength: 0)
            ZStack {
                KeyCapRow(combo: model.prefs.hotKey, size: 76, pressed: model.keyPressed,
                          glow: model.shortcutTested ? Paper.success : nil)
                    .opacity(model.recorder.isRecording ? 0.2 : 1)
                    .blur(radius: model.recorder.isRecording ? 4 : 0)
                if model.recorder.isRecording {
                    VStack(spacing: 6) {
                        Text("Press your new shortcut").font(Paper.serif(24, .medium))
                        Text("Use ⌃, ⌥ or ⌘ with a key · esc to cancel").font(.system(size: 13))
                            .foregroundStyle(Paper.inkSecondary)
                    }
                    .phaseAnimator([1.0, 0.55]) { $0.opacity($1) } animation: { _ in .easeInOut(duration: 0.9) }
                }
            }
            .frame(height: 120)
            .animation(.spring(duration: 0.35), value: model.recorder.isRecording)
            .entrance(0.15)

            ShortcutStatus(conflicts: model.conflicts)
                .padding(.top, 16)
                .animation(.spring(duration: 0.3), value: model.conflicts)
                .entrance(0.2)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(SetupModel.suggestions, id: \.self) { combo in
                        let selected = combo == model.prefs.hotKey
                        let free = model.conflicts(for: combo).isEmpty
                        Button { withAnimation(.spring(duration: 0.4, bounce: 0.25)) { model.setShortcut(combo) } } label: {
                            HStack(spacing: 7) {
                                Image(systemName: free ? "checkmark" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(selected ? Paper.onTint : (free ? Paper.success : Paper.warning))
                                Text(combo.label).font(.system(size: 13, weight: selected ? .semibold : .medium))
                                    .foregroundStyle(selected ? Paper.onTint : Paper.inkPrimary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .glassEffect(selected ? .regular.tint(Paper.tint).interactive() : .regular.tint(Paper.glassTint).interactive(),
                                         in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(free ? "Free on this Mac" : model.conflicts(for: combo).joined(separator: "; "))
                    }
                    Button { model.recorder.toggle() } label: {
                        Label(model.recorder.isRecording ? "Cancel" : "Record…", systemImage: "record.circle")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .glassEffect(.regular.tint(Paper.glassTint).interactive(), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 26)
            .entrance(0.3)

            Spacer(minLength: 0)
            Group {
                if model.shortcutTested {
                    Label("It works!", systemImage: "checkmark.seal.fill")
                        .font(Paper.serif(20, .medium))
                        .foregroundStyle(Paper.success)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard").symbolEffect(.pulse)
                        Text("Try it now: press \(model.prefs.hotKey.label)")
                    }
                    .font(Paper.serifItalic(16))
                    .foregroundStyle(Paper.inkSecondary)
                    .transition(.opacity)
                }
            }
            .frame(height: 30)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Folders

struct FoldersStep: View {
    @Bindable var model: SetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeader(eyebrow: "Step 3 of 4", title: "Choose what it understands",
                       subtitle: "Concordance reads names and contents to learn what each file is about. The index never leaves this Mac.")
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Array(model.folderChoices.enumerated()), id: \.element) { offset, folder in
                        FolderTile(folder: folder, selected: model.isSelected(folder)) { model.toggle(folder) }
                            .entrance(0.15 + Double(offset) * 0.05)
                    }
                    Button { model.addFolder() } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 24, weight: .light))
                            Text("Add Folder").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Paper.inkSecondary)
                        .frame(width: 148, height: 148)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Paper.inkTertiary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .padding(8))
                        .glassEffect(.regular.tint(Paper.glassTint).interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .entrance(0.4)
                }
                .padding(4)
            }
            .scrollIndicators(.never)
            .scrollClipDisabled()

            HStack(spacing: 14) {
                OptionCard(symbol: "photo.on.rectangle.angled", title: "Understand images",
                           detail: "Screenshots and photos, through the vision encoder (≈300 MB memory)",
                           isOn: $model.prefs.indexImages)
                OptionCard(symbol: "doc.on.clipboard", title: "Clipboard history",
                           detail: "Remembers text you copy. Passwords are never recorded.",
                           isOn: $model.prefs.clipboardHistory)
            }
            .entrance(0.35)

            Label("macOS asks once for access to Desktop, Documents and Downloads.", systemImage: "hand.raised.fill")
                .font(.system(size: 12))
                .foregroundStyle(Paper.inkTertiary)
        }
    }
}

struct FolderTile: View {
    let folder: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let path = (folder as NSString).expandingTildeInPath
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Button(action: action) {
            VStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 62, height: 62)
                    .saturation(selected ? 1 : 0.3)
                Text((folder as NSString).lastPathComponent).font(Paper.serif(15, .medium))
                    .foregroundStyle(Paper.inkPrimary)
                Text(folder).font(Paper.mono(10)).foregroundStyle(Paper.inkTertiary).lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 148, height: 148)
            .overlay(alignment: .topTrailing) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Paper.tint : Paper.edge)
                    .padding(10)
                    .contentTransition(.symbolEffect(.replace))
            }
            .glassEffect(.regular.tint(selected ? Paper.selectionGlass : Paper.glassTint).interactive(), in: shape)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(selected ? 1 : 0.78)
    }
}

struct OptionCard: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(Paper.inkSecondary).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Paper.inkPrimary)
                Text(detail).font(.system(size: 12)).foregroundStyle(Paper.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().tint(Paper.tint)
        }
        .frame(maxWidth: .infinity)
        .glassPane(radius: 18, padding: 16)
    }
}

// MARK: - Indexing

struct IndexingStep: View {
    let model: SetupModel
    var engine: SearchEngine { model.engine }

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            VStack(spacing: 22) {
                ProgressRing(progress: progress, spinning: waiting, complete: !waiting && !engine.isIndexing) {
                    VStack(spacing: 2) {
                        if waiting {
                            Image(systemName: "cpu").font(.system(size: 26)).foregroundStyle(Paper.inkSecondary)
                                .symbolEffect(.pulse)
                            Text("warming up").font(Paper.serifItalic(13)).foregroundStyle(Paper.inkTertiary)
                        } else if engine.isIndexing {
                            Text("\(engine.indexingTotal - engine.pendingCount)")
                                .font(Paper.mono(40, .medium))
                                .monospacedDigit()
                            Text("of \(engine.indexingTotal)").font(Paper.mono(12)).foregroundStyle(Paper.inkTertiary)
                        } else {
                            Image(systemName: "checkmark").font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(Paper.success)
                                .transition(.scale.combined(with: .opacity))
                            Text("\(engine.indexedCount) items").font(Paper.mono(12)).foregroundStyle(Paper.inkTertiary)
                        }
                    }
                    .animation(.spring(duration: 0.4), value: engine.isIndexing)
                }
                .frame(width: 210, height: 210)
                .entrance(0.1)
                BreakdownGrid(breakdown: engine.breakdown).frame(width: 280).entrance(0.25)
            }

            VStack(alignment: .leading, spacing: 18) {
                StepHeader(eyebrow: "Step 4 of 4", title: title, subtitle: subtitle)
                LiveFeed(items: engine.recentlyIndexed, idle: !waiting && !engine.isIndexing).entrance(0.2)
                TryIt(model: model).entrance(0.3)
            }
        }
    }

    private var waiting: Bool { engine.modelStatus != .ready }

    private var progress: Double {
        if waiting { return 0.18 }
        guard engine.isIndexing, engine.indexingTotal > 0 else { return 1 }
        return 1 - Double(engine.pendingCount) / Double(engine.indexingTotal)
    }

    private var title: String {
        if waiting { return "Almost ready" }
        return engine.isIndexing ? "Reading your Mac" : "Understood."
    }

    private var subtitle: String {
        if waiting { return "The Neural Engine is still being prepared. Indexing starts the moment it's done, and name search already works." }
        if engine.isIndexing { return "Every app, setting, document and screenshot becomes a point in one space of meaning." }
        return "\(engine.indexedCount) items are now searchable by what they mean. Try a few questions."
    }
}

struct ProgressRing<Center: View>: View {
    let progress: Double
    let spinning: Bool
    var complete = false
    @ViewBuilder let center: () -> Center

    var body: some View {
        TimelineView(.animation(paused: !spinning)) { context in
            let rotation = spinning ? context.date.timeIntervalSinceReferenceDate * 220 : 0
            ZStack {
                Circle().fill(.clear).glassEffect(.regular.tint(Paper.glassTint), in: Circle())
                Circle().stroke(Paper.inkTertiary.opacity(0.18), lineWidth: 10).padding(16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(complete ? Paper.success : Paper.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90 + rotation))
                    .shadow(color: (complete ? Paper.success : Paper.tint).opacity(0.6), radius: 10)
                    .padding(16)
                    .animation(.spring(duration: 0.6), value: progress)
                center()
            }
        }
    }
}

struct BreakdownGrid: View {
    let breakdown: [ItemKind: Int]
    private let kinds: [(ItemKind, String, String)] = [
        (.application, "apps", "square.grid.2x2"), (.settings, "settings", "gearshape"),
        (.command, "commands", "command"), (.file, "files", "doc"),
        (.image, "images", "photo"), (.folder, "folders", "folder"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(kinds, id: \.1) { kind, label, symbol in
                HStack(spacing: 7) {
                    Image(systemName: symbol).font(.system(size: 11)).frame(width: 14).foregroundStyle(Paper.inkTertiary)
                    Text("\(breakdown[kind] ?? 0)").font(Paper.mono(12.5, .medium)).foregroundStyle(Paper.inkPrimary)
                        .contentTransition(.numericText())
                    Text(label).font(.system(size: 12.5)).foregroundStyle(Paper.inkSecondary)
                        .lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .glassCapsule()
            }
        }
        .animation(.spring(duration: 0.4), value: breakdown)
    }
}

struct LiveFeed: View {
    let items: [SearchItem]
    var idle = false

    var body: some View {
        HStack(spacing: 12) {
            if items.isEmpty {
                Label(idle ? "Everything was already indexed. Nothing new to read." : "Waiting for the first items…",
                      systemImage: idle ? "checkmark.circle" : "hourglass")
                    .font(Paper.serifItalic(14)).foregroundStyle(Paper.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(items.prefix(7)) { item in
                VStack(spacing: 6) {
                    ItemIcon(item: item, side: 40)
                    Text(item.title).font(.system(size: 10)).foregroundStyle(Paper.inkSecondary).lineLimit(1)
                }
                .frame(width: 62)
                .transition(.asymmetric(insertion: .scale(scale: 0.5).combined(with: .opacity), removal: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 64)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: items.map(\.id))
        .glassPane(radius: 18, padding: 14)
    }
}

struct TryIt: View {
    let model: SetupModel
    @FocusState private var focused: Bool
    private let examples = ["turn off the sound", "write an email", "a photo of a person", "free up disk space"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass").foregroundStyle(Paper.inkTertiary)
                TextField("Ask anything…", text: Binding(get: { model.tryQuery }, set: { model.setTryQuery($0) }))
                    .textFieldStyle(.plain)
                    .font(Paper.serif(17))
                    .foregroundStyle(Paper.inkPrimary)
                    .focused($focused)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(.regular.tint(Paper.glassTintStrong).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if model.tryQuery.isEmpty {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button(example) { model.setTryQuery(example) }.buttonStyle(.glass).tint(Paper.glassTintStrong)
                    }
                }
            } else {
                VStack(spacing: 2) {
                    ForEach(model.tryResults) { result in
                        ResultRow(result: result, isSelected: false)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .frame(height: 230, alignment: .top)
        .onAppear { focused = true }
    }
}

// MARK: - Done

struct DoneStep: View {
    let model: SetupModel
    @State private var celebrate = false

    var body: some View {
        ZStack {
            ConfettiBurst(trigger: celebrate)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 78))
                    .foregroundStyle(Paper.success)
                    .shadow(color: Paper.success.opacity(0.35), radius: 20)
                    .symbolEffect(.bounce, value: celebrate)
                    .entrance(0)
                Text("You're all set")
                    .font(Paper.serif(50, .medium))
                    .tracking(-0.6)
                    .padding(.top, 18)
                    .entrance(0.1)
                HStack(spacing: 14) {
                    Text("Press").font(Paper.serifItalic(19)).foregroundStyle(Paper.inkSecondary)
                    KeyCapRow(combo: model.prefs.hotKey, size: 42)
                    Text("anywhere to search.").font(Paper.serifItalic(19)).foregroundStyle(Paper.inkSecondary)
                }
                .padding(.top, 22)
                .entrance(0.2)
                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    Label("Open Concordance at login", systemImage: "power").font(.system(size: 14, weight: .medium))
                }
                .toggleStyle(.switch)
                .tint(Paper.tint)
                .frame(width: 330)
                .glassPane(radius: 18, padding: 14)
                .padding(.top, 34)
                .entrance(0.3)
                Spacer(minLength: 0)
                Button { model.finish() } label: {
                    Text("Start Searching").frame(width: 180)
                }
                .primaryGlassButton(large: true)
                .keyboardShortcut(.defaultAction)
                .entrance(0.4)
                Text("Settings and this setup live in the menu bar icon.")
                    .font(.system(size: 12)).foregroundStyle(Paper.inkTertiary).padding(.top, 14)
                    .entrance(0.5)
                if Everpaper.installedURL != nil {
                    Label("Everpaper is installed — your private daybook of work and meetings.",
                          systemImage: "bookmark.fill")
                        .font(.system(size: 12)).foregroundStyle(Paper.inkTertiary).padding(.top, 4)
                        .entrance(0.55)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Paper.tint)
                        Text("Want more like this? Everpaper keeps a private daybook of your work and meetings — ")
                            .font(.system(size: 12)).foregroundStyle(Paper.inkTertiary)
                        Link("everpaper.app", destination: Everpaper.website)
                            .font(.system(size: 12))
                    }
                    .padding(.top, 4)
                    .entrance(0.55)
                }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { celebrate = true } }
    }
}

/// A one-shot burst of paper confetti in Everpaper's rubric and muted hues.
struct ConfettiBurst: View {
    let trigger: Bool
    @State private var start: Date?
    private let pieces: [(angle: Double, speed: Double, spin: Double, color: Int, size: Double)] = (0..<90).map { _ in
        (Double.random(in: -Double.pi...0), Double.random(in: 260...620), Double.random(in: -8...8),
         Int.random(in: 0...7), Double.random(in: 5...10))
    }
    private let colors = [Paper.tint] + Paper.muted

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { context in
            Canvas { g, size in
                guard let start else { return }
                let t = context.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.3)
                for p in pieces {
                    let x = origin.x + cos(p.angle) * p.speed * t
                    let y = origin.y + sin(p.angle) * p.speed * t + 420 * t * t
                    var piece = g
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(p.spin * t))
                    piece.opacity = max(0, 1 - t / 3.2)
                    piece.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                               with: .color(colors[p.color % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, fired in if fired { start = Date() } }
    }
}
