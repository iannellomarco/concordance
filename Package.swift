// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Concordance",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Concordance", targets: ["Concordance"]),
        .executable(name: "concordance-cli", targets: ["concordance-cli"]),
    ],
    dependencies: [
        // EverPaper/embeddinggemma-2-coreai, fetched by scripts/fetch-model.sh (the package identity is its folder name).
        .package(path: "Vendor/EmbeddingGemma-2-CoreAI/swift"),
    ],
    targets: [
        // Catalog sources, vector index, hybrid lexical + semantic ranking, actions. Shared by the app and the CLI.
        .target(
            name: "ConcordanceCore",
            dependencies: [.product(name: "EmbeddingGemma2CoreAI", package: "swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The menu-bar launcher app (panel, hotkey, settings).
        .executableTarget(
            name: "Concordance",
            dependencies: ["ConcordanceCore"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        // Terminal front end to the same index: `concordance-cli index`, `concordance-cli query "..."`.
        .executableTarget(
            name: "concordance-cli",
            dependencies: ["ConcordanceCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
