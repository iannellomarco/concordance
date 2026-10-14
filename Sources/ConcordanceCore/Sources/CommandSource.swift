import Foundation

/// Built-in commands. `ActionRunner` performs them by id.
public enum CommandSource {
    static let commands: [(id: String, title: String, symbol: String, about: String)] = [
        ("lock", "Lock Screen", "lock.fill", "lock the Mac, require the password, step away"),
        ("sleep", "Sleep", "moon.zzz.fill", "put the computer to sleep"),
        ("display-sleep", "Sleep Displays", "display", "turn the screens off"),
        ("screensaver", "Start Screen Saver", "sparkles.tv", "screen saver"),
        ("restart", "Restart…", "restart", "reboot the computer"),
        ("shutdown", "Shut Down…", "power", "turn off the computer, power off"),
        ("logout", "Log Out…", "rectangle.portrait.and.arrow.right", "sign out of the user account"),
        ("empty-trash", "Empty Trash", "trash.slash", "delete the files in the trash bin permanently, free space"),
        ("open-trash", "Open Trash", "trash", "show deleted files"),
        ("dark-mode", "Toggle Dark Mode", "circle.lefthalf.filled", "switch between dark and light appearance, night theme"),
        ("mute", "Toggle Mute", "speaker.slash.fill", "silence or unmute the sound volume"),
        ("eject", "Eject All Disks", "eject.fill", "unmount external drives and USB sticks"),
        ("screenshot", "Capture Screenshot to Clipboard", "camera.viewfinder", "select an area of the screen and copy it"),
        ("clear-clipboard", "Clear Clipboard History", "clipboard", "forget copied text"),
        ("reindex", "Rebuild Concordance Index", "arrow.clockwise", "re-embed apps, files and images"),
        ("settings", "Concordance Settings", "gearshape", "preferences, hotkey, indexed folders"),
        ("quit", "Quit Concordance", "xmark.circle", "close the launcher"),
    ]

    public static func items() -> [SearchItem] {
        commands.map { c in
            SearchItem(id: "cmd:\(c.id)", kind: .command, title: c.title, subtitle: "Command",
                       keywords: c.about.components(separatedBy: ", "), symbol: c.symbol,
                       text: "title: \(c.title) | text: Command: \(c.title). \(c.about).")
        }
    }
}
