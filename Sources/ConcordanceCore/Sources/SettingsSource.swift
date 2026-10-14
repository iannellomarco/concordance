import Foundation

/// System Settings panes, opened with x-apple.systempreferences:<pane id>.
public enum SettingsSource {
    static let panes: [(title: String, id: String, about: String)] = [
        ("Wi-Fi", "com.apple.wifi-settings-extension", "wireless network, internet connection, hotspot"),
        ("Bluetooth", "com.apple.BluetoothSettings", "pair headphones, keyboard, mouse and other devices"),
        ("Network", "com.apple.Network-Settings.extension", "ethernet, DNS, proxies, firewall, IP address"),
        ("VPN", "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension", "virtual private network"),
        ("Battery", "com.apple.Battery-Settings.extension", "power, energy, low power mode, charging"),
        ("General", "com.apple.systempreferences.GeneralSettings", "about, software update, storage, sharing"),
        ("About This Mac", "com.apple.SystemProfiler.AboutExtension", "model, chip, memory, serial number, macOS version"),
        ("Software Update", "com.apple.Software-Update-Settings.extension", "update macOS, install upgrades"),
        ("Storage", "com.apple.settings.Storage", "disk space, free up space"),
        ("Accessibility", "com.apple.Accessibility-Settings.extension", "VoiceOver, zoom, display contrast, pointer"),
        ("Appearance", "com.apple.Appearance-Settings.extension", "dark mode, light mode, accent color, theme"),
        ("Control Center", "com.apple.ControlCenter-Settings.extension", "menu bar items and modules"),
        ("Desktop & Dock", "com.apple.Desktop-Settings.extension", "dock size, stage manager, hot corners, Mission Control, widgets"),
        ("Displays", "com.apple.Displays-Settings.extension", "monitor resolution, brightness, Night Shift, external screen"),
        ("Wallpaper", "com.apple.Wallpaper-Settings.extension", "desktop background picture"),
        ("Notifications", "com.apple.Notifications-Settings.extension", "alerts, banners, badges"),
        ("Sound", "com.apple.Sound-Settings.extension", "volume, output, input, microphone, speakers, alert sound"),
        ("Focus", "com.apple.Focus-Settings.extension", "do not disturb, silence notifications"),
        ("Screen Time", "com.apple.Screen-Time-Settings.extension", "app usage, limits, parental controls"),
        ("Lock Screen", "com.apple.Lock-Screen-Settings.extension", "screen saver delay, require password, display off"),
        ("Privacy & Security", "com.apple.settings.PrivacySecurity.extension", "permissions, location, camera, microphone, full disk access, FileVault"),
        ("Touch ID & Password", "com.apple.Touch-ID-Settings.extension", "fingerprint, login password"),
        ("Users & Groups", "com.apple.Users-Groups-Settings.extension", "accounts, guest user"),
        ("Internet Accounts", "com.apple.Internet-Accounts-Settings.extension", "mail, contacts and calendar accounts"),
        ("Apple Account", "com.apple.systempreferences.AppleIDSettings", "iCloud, Apple ID, subscriptions"),
        ("Family", "com.apple.Family-Settings.extension", "family sharing"),
        ("Game Center", "com.apple.Game-Center-Settings.extension", "games, friends"),
        ("Wallet & Apple Pay", "com.apple.WalletSettingsExtension", "cards, payments"),
        ("Keyboard", "com.apple.Keyboard-Settings.extension", "key repeat, shortcuts, input sources, dictation"),
        ("Mouse", "com.apple.Mouse-Settings.extension", "tracking speed, scrolling direction"),
        ("Trackpad", "com.apple.Trackpad-Settings.extension", "gestures, tap to click, scroll"),
        ("Printers & Scanners", "com.apple.Print-Scan-Settings.extension", "add a printer"),
        ("Sharing", "com.apple.Sharing-Settings.extension", "file sharing, screen sharing, AirPlay receiver, computer name"),
        ("Time Machine", "com.apple.Time-Machine-Settings.extension", "backups, restore"),
        ("Date & Time", "com.apple.Date-Time-Settings.extension", "clock, time zone"),
        ("Language & Region", "com.apple.Localization-Settings.extension", "language, region, date format, translation"),
        ("Login Items & Extensions", "com.apple.LoginItems-Settings.extension", "apps that open at login, background items"),
        ("Spotlight", "com.apple.Spotlight-Settings.extension", "search results, privacy"),
        ("Siri", "com.apple.Siri-Settings.extension", "Apple Intelligence, voice assistant"),
        ("Startup Disk", "com.apple.Startup-Disk-Settings.extension", "boot volume"),
        ("Transfer or Reset", "com.apple.Transfer-Reset-Settings.extension", "erase all content and settings, migrate"),
    ]

    public static func items() -> [SearchItem] {
        panes.map { pane in
            SearchItem(id: "settings:\(pane.id)", kind: .settings, title: pane.title, subtitle: "System Settings",
                       keywords: pane.about.components(separatedBy: ", "),
                       url: URL(string: "x-apple.systempreferences:\(pane.id)"),
                       text: "title: \(pane.title) settings | text: System Settings pane \(pane.title): \(pane.about).")
        }
    }
}
