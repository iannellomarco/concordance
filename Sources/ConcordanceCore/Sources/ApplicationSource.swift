import Foundation

/// Installed applications: /Applications (one folder level deep), the system apps and ~/Applications.
public enum ApplicationSource {
    static let roots = [
        "/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
        "/System/Library/CoreServices/Applications", "~/Applications",
    ]

    public static func items() -> [SearchItem] {
        let fm = FileManager.default
        var seen = Set<String>()
        var result: [SearchItem] = []

        // Deduplicate by real location: /Applications/Safari.app is a symlink into the Safari cryptex.
        func add(_ url: URL) {
            guard seen.insert(url.resolvingSymlinksInPath().path).inserted, let item = item(for: url) else { return }
            result.append(item)
        }

        add(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        for root in roots {
            let rootURL = URL(fileURLWithPath: (root as NSString).expandingTildeInPath)
            // Not .skipsHiddenFiles: the Safari symlink carries the hidden flag.
            guard let children = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
            else { continue }
            for child in children where !child.lastPathComponent.hasPrefix(".") {
                if child.pathExtension == "app" {
                    add(child)
                } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                          root == "/Applications" || root == "~/Applications",
                          let nested = try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: nil,
                                                                   options: .skipsHiddenFiles) {
                    nested.filter { $0.pathExtension == "app" }.forEach(add)
                }
            }
        }
        return result
    }

    static func item(for url: URL) -> SearchItem? {
        let info = Bundle(url: url)?.infoDictionary ?? [:]
        let fileName = url.deletingPathExtension().lastPathComponent
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        let bundleName = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
        let bundleID = info["CFBundleIdentifier"] as? String ?? ""
        let category = (info["LSApplicationCategoryType"] as? String).map(humanCategory)

        var text = "title: \(name) | text: \(name) is a macOS application"
        if let category { text += " in the \(category) category" }
        text += "."
        if let hint = hints[bundleID] { text += " \(hint)" }

        let keywords = Array(Set([fileName, bundleName].compactMap { $0 }.filter { $0 != name }))
        return SearchItem(id: "app:\(url.path)", kind: .application, title: name,
                          subtitle: url.deletingLastPathComponent().path, keywords: keywords, url: url,
                          text: text)
    }

    static func humanCategory(_ uti: String) -> String {
        uti.replacingOccurrences(of: "public.app-category.", with: "").replacingOccurrences(of: "-", with: " ")
    }

    /// What the built-in apps are for, so that "write an email" or "edit a photo" finds them by meaning.
    static let hints: [String: String] = [
        "com.apple.Safari": "Web browser for websites and the internet.",
        "com.apple.mail": "Email client: read, write and send mail.",
        "com.apple.MobileSMS": "Messages: text chat, iMessage and SMS.",
        "com.apple.FaceTime": "Video and audio calls.",
        "com.apple.iCal": "Calendar: events, meetings and schedule.",
        "com.apple.reminders": "Reminders: to-do lists and tasks.",
        "com.apple.Notes": "Notes: write and keep notes.",
        "com.apple.AddressBook": "Contacts: people, phone numbers and addresses.",
        "com.apple.Photos": "Photos: photo library, edit pictures and albums.",
        "com.apple.Preview": "Preview: view PDFs and images, annotate and sign documents.",
        "com.apple.TextEdit": "TextEdit: plain and rich text editor.",
        "com.apple.Terminal": "Terminal: command line shell.",
        "com.apple.ActivityMonitor": "Activity Monitor: CPU, memory, processes, force quit.",
        "com.apple.systempreferences": "System Settings: configure the Mac.",
        "com.apple.finder": "Finder: browse files and folders.",
        "com.apple.Music": "Music: songs, playlists and Apple Music.",
        "com.apple.podcasts": "Podcasts: listen to shows.",
        "com.apple.TV": "TV: movies and shows.",
        "com.apple.Maps": "Maps: directions, places and navigation.",
        "com.apple.weather": "Weather forecast.",
        "com.apple.calculator": "Calculator: arithmetic and math.",
        "com.apple.clock": "Clock: alarms, timers, stopwatch and world clock.",
        "com.apple.AppStore": "App Store: download and update apps.",
        "com.apple.iWork.Pages": "Pages: word processor for documents.",
        "com.apple.iWork.Numbers": "Numbers: spreadsheets.",
        "com.apple.iWork.Keynote": "Keynote: presentations and slides.",
        "com.apple.dt.Xcode": "Xcode: IDE to build apps, write code.",
        "com.apple.Passwords": "Passwords: saved passwords and passkeys.",
        "com.apple.DiskUtility": "Disk Utility: format and repair disks.",
        "com.apple.ScreenSharing": "Screen Sharing: control another Mac remotely.",
        "com.apple.screenshot.launcher": "Screenshot: capture or record the screen.",
        "com.apple.QuickTimePlayerX": "QuickTime Player: play and record video.",
        "com.apple.Image_Capture": "Image Capture: import from cameras and scanners.",
        "com.apple.freeform": "Freeform: whiteboard and brainstorming board.",
        "com.apple.shortcuts": "Shortcuts: automations.",
        "com.apple.VoiceMemos": "Voice Memos: record audio.",
        "com.apple.Home": "Home: smart home accessories.",
        "com.apple.findmy": "Find My: locate devices and people.",
        "com.apple.journal": "Journal: diary entries.",
    ]
}
