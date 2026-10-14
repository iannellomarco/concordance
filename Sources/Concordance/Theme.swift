import AppKit
import CoreText
import SwiftUI

/// Everpaper's palette and type, "The Daybook" (hindsight-public, Sources/HSDesign/Tokens.swift), values copied
/// verbatim: paper carries warmth, ink carries hierarchy, and one rationed rubric red marks acts of meaning — here,
/// primary actions, the selection edge and results that matched by meaning. Every color is a light/dark pair that
/// AppKit resolves per appearance.
enum Paper {
    // MARK: Ink

    static let inkPrimary = pair(light: 0x211C15, dark: 0xEFE6D8)
    static let inkSecondary = pair(light: 0x5F574A, dark: 0xB4A896)
    static let inkTertiary = pair(light: 0x6F6859, dark: 0x928779)

    // MARK: Rubric (the one accent)

    static let tint = pair(light: 0x963D2B, dark: 0xE0704F)
    static let tintSoft = pair(light: 0x963D2B, dark: 0xE0704F, alpha: 0.14)
    /// Label on a `tint` fill: cream on brick (light), warm near-black on coral (dark).
    static let onTint = pair(light: 0xFBF4EA, dark: 0x191309)

    // MARK: Paper surfaces and rules

    static let canvas = pair(light: 0xF6F2E9, dark: 0x16110D)
    static let panel = pair(light: 0xFBF8F1, dark: 0x1E1813)
    static let panelRaised = pair(light: 0xFFFFFF, dark: 0x241D16)
    static let well = pair(light: 0xEFE9DC, dark: 0x110D0A)
    static let edge = pair(light: 0xD3CAB5, dark: 0x453A2C)
    static let hairline = pair(light: 0xE3DCCB, dark: 0x2A2219)
    static let selectionFill = pair(light: 0xECE3D1, dark: 0x261F17)

    // MARK: Status

    static let success = pair(light: 0x3E6B45, dark: 0x8CB893)
    static let warning = pair(light: 0x7E5A15, dark: 0xD9A441)

    // MARK: Muted hues (Everpaper's speaker palette), for icon tiles and ornament

    static let teal = pair(light: 0x2E6E6A, dark: 0x6FB7B0)
    static let ochre = pair(light: 0x8A6D1F, dark: 0xCBA85A)
    static let plum = pair(light: 0x6B3F6E, dark: 0xB58CC0)
    static let olive = pair(light: 0x4A6B2E, dark: 0x9FC07A)
    static let slate = pair(light: 0x3C5A82, dark: 0x8AAAD6)
    static let rose = pair(light: 0x8E4A5E, dark: 0xC78FA0)
    static let clay = pair(light: 0x8A5A3E, dark: 0xC79C7E)
    static let muted: [Color] = [teal, ochre, plum, olive, slate, rose, clay]

    // MARK: Shape, elevation, motion

    static let radiusRow: CGFloat = 4
    static let radius: CGFloat = 6
    static let radiusCard: CGFloat = 10
    static let radiusFloat: CGFloat = 14
    static var hairlineWidth: CGFloat { 1 / (NSScreen.main?.backingScaleFactor ?? 2) }

    static let motionSwap = Animation.easeInOut(duration: 0.18)
    static let motionSettle = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.24)
    static let motionInk = Animation.easeOut(duration: 0.35)
    static let motionDevelop = Animation.easeOut(duration: 0.45)

    // MARK: Type: serif is what is remembered, mono what the machine captured, SF the controls

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Fonts.serifAvailable ? .custom("Newsreader", size: size).weight(weight)
            : .system(size: size, weight: weight, design: .serif)
    }

    static func serifItalic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        serif(size, weight).italic()
    }

    /// Counts, timers, stamps.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Fonts.monoAvailable ? .custom("iA Writer Mono S", size: size).weight(weight)
            : .system(size: size, weight: weight, design: .monospaced)
    }

    /// Eyebrows and group heads: render uppercase with +1.2 tracking.
    static let section = Font.system(size: 11, weight: .semibold)

    /// The bundled faces (Resources/Fonts, SIL OFL), registered for this process at launch.
    enum Fonts {
        static func register() {
            guard let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
                  let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            else { return }
            for file in files where file.pathExtension == "ttf" {
                CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
            }
        }

        static var serifAvailable: Bool { families.contains("Newsreader") }
        static var monoAvailable: Bool { families.contains("iA Writer Mono S") }
        private static var families: Set<String> { Set(NSFontManager.shared.availableFontFamilies) }
    }

    private static func pair(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
        })
    }
}

// MARK: - Warm glass

extension Paper {
    /// Everpaper's paper tones as glass tints: thin enough to refract what is behind, warm enough to read as paper.
    static let glassTint = pair(light: 0xFBF8F1, dark: 0x1E1813, alpha: 0.32)
    static let glassTintStrong = pair(light: 0xFBF8F1, dark: 0x1E1813, alpha: 0.55)
    static let selectionGlass = pair(light: 0x963D2B, dark: 0xE0704F, alpha: 0.26)

    /// The same tint as an AppKit color, for `NSGlassEffectView`.
    static func nsGlassTint(alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return dark ? NSColor(srgbRed: 0x1E / 255, green: 0x18 / 255, blue: 0x13 / 255, alpha: alpha)
                : NSColor(srgbRed: 0xFB / 255, green: 0xF8 / 255, blue: 0xF1 / 255, alpha: alpha)
        }
    }
}

extension View {
    /// A pane of warm Liquid Glass.
    func glassPane(radius: CGFloat = 22, padding: CGFloat = 20, tint: Color = Paper.glassTint,
                   interactive: Bool = false) -> some View {
        self.padding(padding)
            .glassEffect(.regular.tint(tint).interactive(interactive),
                         in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// A small glass capsule (chips, facts, key hints).
    func glassCapsule(tint: Color? = nil) -> some View {
        self.glassEffect(.regular.tint(tint ?? Paper.glassTint), in: Capsule())
    }

    /// Eyebrow / group head.
    func eyebrow() -> some View {
        self.font(Paper.section).textCase(.uppercase).tracking(1.2).foregroundStyle(Paper.inkTertiary)
    }

    /// The one primary action: rubric-tinted prominent glass.
    func primaryGlassButton(large: Bool = false) -> some View {
        self.buttonStyle(.glassProminent).tint(Paper.tint).controlSize(large ? .extraLarge : .large)
    }

    /// Everything else: clear glass.
    func secondaryGlassButton() -> some View {
        self.buttonStyle(.glass).tint(Paper.glassTintStrong).controlSize(.large)
    }
}
