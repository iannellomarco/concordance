import AppKit
import ConcordanceCore
import Observation
import ServiceManagement
import SwiftUI

@MainActor @Observable
final class SetupModel {
    enum Step: Int, CaseIterable {
        case welcome, model, shortcut, folders, indexing, done

        /// The light that drifts behind each step: the rubric, ochre while the files are read, green when done.
        var glow: Color {
            switch self {
            case .indexing: Paper.ochre
            case .done: Paper.success
            default: Paper.tint
            }
        }
    }

    private(set) var step: Step = .welcome
    /// Direction of the last step change, read by the step transition.
    private(set) var forward = true
    var prefs: Preferences
    let engine: SearchEngine
    let installer = ModelInstaller()
    let recorder = ShortcutRecorder()
    private(set) var modelFound = Paths.modelBundle() != nil
    private(set) var conflicts: [String] = []
    private(set) var shortcutTested = false
    private(set) var keyPressed = false
    private(set) var folderChoices: [String]
    private(set) var tryResults: [SearchResult] = []
    private(set) var tryQuery = ""
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    @ObservationIgnored var onShortcutChange: (() -> Void)?
    @ObservationIgnored var isShortcutRegistered: () -> Bool = { true }
    @ObservationIgnored var onFinish: (() -> Void)?
    @ObservationIgnored private var tryTask: Task<Void, Never>?

    static let suggestions: [HotKeyCombo] = [.optionSpace, .shiftOptionSpace, .controlShiftSpace, .hyperSpace]

    init(engine: SearchEngine) {
        self.engine = engine
        let saved = Preferences.load()
        prefs = saved
        var choices: [String] = []
        for folder in ["~/Desktop", "~/Documents", "~/Downloads", "~/Pictures"] + saved.folders
            where !choices.contains(folder) { choices.append(folder) }
        folderChoices = choices
        recorder.onRecord = { [weak self] combo in self?.setShortcut(combo) }
        refreshConflicts()
    }

    /// Called when the window appears: start preparing the model right away, it is the slow part.
    func begin() {
        if modelFound { engine.prepareModel() }
    }

    // MARK: - Navigation

    var canGoBack: Bool { step != .welcome && step != .done }

    func next() {
        guard let target = Step(rawValue: step.rawValue + 1) else { finish(); return }
        if step == .folders { commitFolders() }
        go(to: target)
    }

    func back() {
        guard let target = Step(rawValue: step.rawValue - 1) else { return }
        go(to: target)
    }

    private func go(to target: Step) {
        recorder.stop()
        forward = target.rawValue > step.rawValue
        // Let the leaving view pick up the new direction before it animates out.
        DispatchQueue.main.async {
            withAnimation(.spring(duration: 0.6, bounce: 0.18)) { self.step = target }
            self.entered(target)
        }
    }

    private func entered(_ step: Step) {
        switch step {
        case .model:
            if !modelFound, installer.phase == .idle || installer.phase.isFailure { downloadModel() }
        case .shortcut:
            shortcutTested = false
            // If the default is taken (Everpaper, Raycast, a macOS shortcut…), start from a free one.
            if !conflicts.isEmpty, prefs.hotKey == .optionSpace,
               let free = Self.suggestions.first(where: { HotKeyConflicts.check($0).isEmpty }) {
                setShortcut(free)
            }
        default:
            break
        }
    }

    // MARK: - Model

    func downloadModel() {
        Task {
            await installer.install(includeVision: true)
            if installer.phase == .installed {
                modelFound = true
                engine.prepareModel()
            }
        }
    }

    // MARK: - Shortcut

    func setShortcut(_ combo: HotKeyCombo) {
        prefs.hotKey = combo
        var saved = Preferences.load()
        saved.hotKey = combo
        saved.save()
        onShortcutChange?()
        refreshConflicts()
        shortcutTested = false
    }

    func conflicts(for combo: HotKeyCombo) -> [String] { HotKeyConflicts.check(combo) }

    private func refreshConflicts() {
        var found = HotKeyConflicts.check(prefs.hotKey)
        if found.isEmpty, !isShortcutRegistered() { found.append("another app has already registered it") }
        conflicts = found
    }

    /// The global hotkey fired while the shortcut step is showing.
    func shortcutPressed() {
        keyPressed = true
        withAnimation(.spring(duration: 0.5, bounce: 0.5)) { shortcutTested = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { self.keyPressed = false }
    }

    // MARK: - Folders

    func isSelected(_ folder: String) -> Bool { prefs.folders.contains(folder) }

    func toggle(_ folder: String) {
        withAnimation(.spring(duration: 0.3)) {
            if let index = prefs.folders.firstIndex(of: folder) {
                prefs.folders.remove(at: index)
            } else {
                prefs.folders.append(folder)
            }
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for url in panel.urls {
            let path = url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
            if !folderChoices.contains(path) { folderChoices.append(path) }
            if !prefs.folders.contains(path) { prefs.folders.append(path) }
        }
    }

    /// Applies the choices and starts the catalog and indexing. Touching each folder first makes macOS ask for
    /// access now, while the user knows why, rather than later in the background.
    private func commitFolders() {
        for url in prefs.folderURLs {
            _ = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        }
        var saved = prefs
        saved.hotKey = Preferences.load().hotKey
        if engine.hasStarted {
            engine.update(preferences: saved)
        } else {
            engine.setInitialPreferences(saved)
            engine.start()
        }
    }

    // MARK: - Try it

    func setTryQuery(_ text: String) {
        tryQuery = text
        tryTask?.cancel()
        tryTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let results = await engine.search(text, limit: 5).filter { $0.item.kind != .web }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35)) { tryResults = Array(results.prefix(4)) }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Finish

    func finish() {
        Preferences.setupCompleted = true
        onFinish?()
    }
}

extension ModelInstaller.Phase {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }
}
