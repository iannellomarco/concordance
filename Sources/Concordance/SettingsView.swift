import AppKit
import ConcordanceCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let engine: SearchEngine
    let isHotKeyRegistered: () -> Bool
    @State private var draft = Preferences.load()
    @State private var recorder = ShortcutRecorder()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Launcher") {
                LabeledContent("Shortcut") {
                    HStack(spacing: 10) {
                        if recorder.isRecording {
                            Text("Press a shortcut… (esc cancels)").foregroundStyle(.secondary)
                        } else {
                            KeyCapRow(combo: draft.hotKey, size: 24)
                        }
                        Button(recorder.isRecording ? "Cancel" : "Record…") {
                            recorder.onRecord = { draft.hotKey = $0 }
                            recorder.toggle()
                        }
                    }
                }
                let conflicts = HotKeyConflicts.check(draft.hotKey)
                    + (isHotKeyRegistered() ? [] : ["another app has already registered it"])
                ShortcutStatus(conflicts: conflicts)
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }

            Section("Index") {
                ForEach(draft.folders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder)
                        Spacer()
                        Button(role: .destructive) { draft.folders.removeAll { $0 == folder } } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…", action: addFolder)
                Toggle("Understand images and screenshots (EmbeddingGemma 2 vision, +300 MB memory)",
                       isOn: $draft.indexImages)
                Toggle("Clipboard history", isOn: $draft.clipboardHistory)
                Stepper("Up to \(draft.maxFiles) files", value: $draft.maxFiles, in: 500...50_000, step: 500)
                Stepper("Up to \(draft.maxImages) images", value: $draft.maxImages, in: 0...20_000, step: 250)
            }

            Section("About") {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Paper.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Want more like this?")
                        Text("Everpaper keeps a private daybook of your work and meetings — the app this launcher's model and look come from. everpaper.app")
                            .font(.system(size: 11)).foregroundStyle(Paper.inkTertiary)
                    }
                    Spacer()
                    Link("Visit", destination: Everpaper.website)
                }
            }

            Section("EmbeddingGemma 2") {
                LabeledContent("Status", value: statusText)
                LabeledContent("Catalog", value: "\(engine.catalogCount) items")
                LabeledContent("Embedded", value: "\(engine.indexedCount) items"
                    + (engine.pendingCount > 0 ? ", \(engine.pendingCount) pending" : ""))
                Button("Rebuild Index") { engine.rebuildIndex() }
            }
        }
        .formStyle(.grouped)
        .tint(Paper.tint)
        .frame(width: 520, height: 600)
        .onChange(of: draft) { _, new in
            engine.update(preferences: new)   // saves
            NotificationCenter.default.post(name: .concordancePreferencesChanged, object: nil)
        }
    }

    private var statusText: String {
        switch engine.modelStatus {
        case .ready: "Ready on the Neural Engine"
        case .loading: "Preparing…"
        case .missing: "Model files not found"
        case .failed(let message): "Failed: \(message)"
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for url in panel.urls {
            let path = url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
            if !draft.folders.contains(path) { draft.folders.append(path) }
        }
    }
}

extension Notification.Name {
    static let concordancePreferencesChanged = Notification.Name("ConcordancePreferencesChanged")
}
