import AppKit
import ConcordanceCore
import QuickLookThumbnailing
import SwiftUI

@MainActor
enum Icons {
    private static let cache = NSCache<NSString, NSImage>()
    private static let settingsAppPath = "/System/Applications/System Settings.app"

    static func fileIcon(for item: SearchItem) -> NSImage? {
        let path: String
        switch item.kind {
        case .settings: path = settingsAppPath
        default:
            guard item.kind.isFileBacked, let url = item.url else { return nil }
            path = url.path
        }
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }

    static func thumbnail(for url: URL, side: CGFloat) async -> NSImage? {
        let key = "\(url.path)#\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side),
                                                   scale: NSScreen.main?.backingScaleFactor ?? 2,
                                                   representationTypes: .thumbnail)
        guard let image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// File icon, live thumbnail for images, or an SF Symbol tile.
struct ItemIcon: View {
    let item: SearchItem
    var side: CGFloat = 26
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side).clipShape(RoundedRectangle(cornerRadius: side * 0.18))
            } else if let icon = Icons.fileIcon(for: item) {
                Image(nsImage: icon).resizable().frame(width: side, height: side)
            } else {
                Image(systemName: item.symbol ?? "questionmark")
                    .font(.system(size: side * 0.46, weight: .semibold))
                    .foregroundStyle(Paper.panelRaised)
                    .frame(width: side, height: side)
                    .background(tint, in: RoundedRectangle(cornerRadius: side * 0.24))
            }
        }
        .task(id: item.id) {
            guard item.kind == .image, let url = item.url else { thumbnail = nil; return }
            thumbnail = await Icons.thumbnail(for: url, side: side)
        }
    }

    private var tint: Color {
        // Everpaper's muted hues; the rubric stays reserved for actions and meaning.
        switch item.kind {
        case .command: Paper.slate
        case .clipboard: Paper.ochre
        case .calculator: Paper.teal
        case .web: Paper.plum
        default: Paper.inkTertiary
        }
    }
}
