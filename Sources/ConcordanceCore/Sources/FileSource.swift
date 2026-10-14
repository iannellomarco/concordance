import Foundation
import UniformTypeIdentifiers

/// Files, folders and images under the user's chosen folders, newest first.
public struct FileSource: Sendable {
    public var roots: [URL]
    public var maxItems: Int
    public var maxDepth = 6

    static let skippedFolders: Set<String> = [
        "node_modules", ".git", "DerivedData", ".build", "Pods", "venv", ".venv", "__pycache__", ".Trash",
    ]

    public init(roots: [URL], maxItems: Int) {
        self.roots = roots
        self.maxItems = maxItems
    }

    public func items() -> [SearchItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey, .fileSizeKey,
                                      .contentTypeKey]
        var found: [SearchItem] = []
        // Bound the walk so a huge Documents folder cannot stall the catalog.
        let visitLimit = maxItems * 4

        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { continue }
            var visited = 0
            for case let url as URL in walker {
                visited += 1
                if visited > visitLimit { break }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                let isFolder = values.isDirectory == true && values.isPackage != true
                if isFolder {
                    if Self.skippedFolders.contains(url.lastPathComponent) || walker.level >= maxDepth {
                        walker.skipDescendants()
                    }
                    if walker.level <= 3, !Self.skippedFolders.contains(url.lastPathComponent) {
                        found.append(folderItem(url, modified: values.contentModificationDate))
                    }
                    continue
                }
                found.append(fileItem(url, values: values))
            }
        }
        found.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        return Array(found.prefix(maxItems))
    }

    private func folderItem(_ url: URL, modified: Date?) -> SearchItem {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return SearchItem(id: "file:\(url.path)", kind: .folder, title: url.lastPathComponent,
                          subtitle: Self.displayPath(url.deletingLastPathComponent()), url: url, date: modified,
                          text: "title: \(url.lastPathComponent) | text: Folder \(url.lastPathComponent) inside \(parent).")
    }

    private func fileItem(_ url: URL, values: URLResourceValues) -> SearchItem {
        let type = values.contentType ?? UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) == true && !(type?.conforms(to: .pdf) ?? false)
        let modified = values.contentModificationDate ?? .distantPast
        let signature = "\(Int(modified.timeIntervalSince1970))-\(values.fileSize ?? 0)"
        return SearchItem(id: "file:\(url.path)", kind: isImage ? .image : .file, title: url.lastPathComponent,
                          subtitle: Self.displayPath(url.deletingLastPathComponent()),
                          keywords: [url.deletingPathExtension().lastPathComponent], url: url, date: modified,
                          signature: signature)
    }

    static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}
