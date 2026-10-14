import AppKit

@main
@MainActor
enum ConcordanceApp {
    static let delegate = AppDelegate()

    static func main() {
        Paper.Fonts.register()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)   // menu-bar app: no Dock icon
        app.delegate = delegate
        app.run()
    }
}
