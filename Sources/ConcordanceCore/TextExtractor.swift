import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Builds the text EmbeddingGemma sees for a file: its name, where it lives and the start of its contents.
enum TextExtractor {
    static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "yaml", "yml", "toml", "ini", "xml", "html", "htm", "css",
        "log", "tex", "swift", "py", "js", "ts", "tsx", "jsx", "c", "h", "m", "mm", "cpp", "hpp", "rs", "go", "java",
        "kt", "rb", "php", "sh", "zsh", "sql", "r", "lua", "vue", "svelte", "org", "rst", "srt", "vtt",
    ]
    static let richTextExtensions: Set<String> = ["rtf", "rtfd", "doc", "docx", "odt"]

    /// Contents, at most `limit` characters with whitespace collapsed, or nil when the format has no text.
    static func contents(of url: URL, limit: Int = 1500) -> String? {
        let ext = url.pathExtension.lowercased()
        var text: String?
        if plainTextExtensions.contains(ext) {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
            defer { try? handle.close() }
            let data = (try? handle.read(upToCount: 64 * 1024)) ?? Data()
            text = String(decoding: data, as: UTF8.self)
        } else if ext == "pdf" {
            guard let document = PDFDocument(url: url) else { return nil }
            text = (0..<min(document.pageCount, 3)).compactMap { document.page(at: $0)?.string }.joined(separator: " ")
        } else if richTextExtensions.contains(ext) {
            text = (try? NSAttributedString(url: url, options: [:], documentAttributes: nil))?.string
        }
        guard let text else { return nil }
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.isEmpty ? nil : String(collapsed.prefix(limit))
    }

    /// EmbeddingGemma's document format, `title: … | text: …`.
    static func embeddingText(for item: SearchItem) -> (text: String, snippet: String?) {
        if let text = item.text { return (text, nil) }
        guard let url = item.url else { return ("title: \(item.title) | text: \(item.title)", nil) }
        let folder = url.deletingLastPathComponent().lastPathComponent
        let typeName = UTType(filenameExtension: url.pathExtension)?.localizedDescription ?? "file"
        let name = url.deletingPathExtension().lastPathComponent
        if let body = contents(of: url) {
            return ("title: \(name) | text: \(body)", String(body.prefix(400)))
        }
        return ("title: \(name) | text: \(typeName) named \(name) in the \(folder) folder.", nil)
    }
}
