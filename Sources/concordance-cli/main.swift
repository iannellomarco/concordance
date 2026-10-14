import ConcordanceCore
import Foundation

// concordance-cli index [--no-images]     build or update the shared index (same file the app uses)
// concordance-cli query <text> [--lexical] print the ranked results
// concordance-cli stats                   catalog and index sizes

@MainActor
func runCLI() async {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        print("usage: concordance-cli index [--no-images] | query <text> [--lexical] | stats")
        exit(2)
    }
    args.removeFirst()
    if let i = args.firstIndex(of: "--zfloor"), i + 1 < args.count, let z = Double(args[i + 1]) {
        SearchEngine.zFloor = z
        args.removeSubrange(i...(i + 1))
    }
    if let i = args.firstIndex(of: "--zspan"), i + 1 < args.count, let z = Double(args[i + 1]) {
        SearchEngine.zSpan = z
        args.removeSubrange(i...(i + 1))
    }
    if let i = args.firstIndex(of: "--no-hub") {
        SearchEngine.hubCorrection = false
        args.remove(at: i)
    }
    if command == "install" {
        // concordance-cli install <dest> [--small]: the setup assistant's downloader; --small fetches only the
        // JSON/metadata files (a quick end-to-end check of listing, download, checksum and install).
        guard let dest = args.first(where: { !$0.hasPrefix("--") }) else { print("usage: install <dest> [--small]"); exit(2) }
        let installer = ModelInstaller(destination: URL(fileURLWithPath: dest))
        let small = args.contains("--small")
        let progress = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                print("  \(installer.phase) \(installer.receivedBytes)/\(installer.totalBytes) \(installer.currentFile)")
            }
        }
        await installer.install(includeVision: true, only: small ? { $0.hasSuffix(".json") && !$0.contains("tokenizer.json") } : nil)
        progress.cancel()
        print("result: \(installer.phase), \(installer.totalBytes) bytes")
        exit(installer.phase == .installed ? 0 : 1)
    }
    var prefs = Preferences()
    if args.contains("--no-images") { prefs.indexImages = false }
    prefs.clipboardHistory = false
    let engine = SearchEngine(preferences: prefs)

    let started = Date()
    await engine.refreshCatalog()
    print("catalog: \(engine.catalogCount) items, index: \(engine.indexedCount) vectors")

    switch command {
    case "stats":
        break
    case "index":
        print("loading EmbeddingGemma 2 (the first load by a new executable takes a few minutes)…")
        await engine.loadModel()
        print("model: \(engine.modelStatus) after \(Int(-started.timeIntervalSinceNow)) s")
        guard engine.modelStatus == .ready else { exit(1) }
        engine.startIndexing()
        let progress = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                print("  pending \(engine.pendingCount), indexed \(engine.indexedCount)")
            }
        }
        await engine.waitForIndexing()
        progress.cancel()
        print("indexed \(engine.indexedCount) vectors in \(Int(-started.timeIntervalSinceNow)) s")
    case "query":
        let lexicalOnly = args.contains("--lexical")
        let text = args.filter { !$0.hasPrefix("--") }.joined(separator: " ")
        if !lexicalOnly { await engine.loadModel() }
        _ = await engine.search("warm up", semantic: !lexicalOnly)   // one-time probe bank, as the app does at start
        let t0 = Date()
        let results = await engine.search(text, semantic: !lexicalOnly, limit: 15)
        let ms = Int(-t0.timeIntervalSinceNow * 1000)
        print("“\(text)” → \(results.count) results in \(ms) ms")
        for r in results {
            let marker = r.semantic ? "≈" : " "
            print(String(format: "%5.2f %@ %-12@ %@  —  %@", r.score, marker, r.item.kind.label, r.item.title,
                         r.item.subtitle))
        }
    case "cosines":
        await engine.loadModel()
        let text = args.joined(separator: " ")
        for (item, cosine, z) in await engine.semanticScores(text).prefix(12) {
            print(String(format: "  z %5.2f  cos %.3f  %-12@ %@", z, cosine, item.kind.label, item.title))
        }
    default:
        print("unknown command \(command)")
        exit(2)
    }
    await engine.shutdown()
}

await runCLI()
