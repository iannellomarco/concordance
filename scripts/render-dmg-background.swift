// Renders the DMG background: exactly the DMG window size (720x420), warm paper with drifting light,
// the wordmark top-left, and the two icon slots clear at mid-height (app left, Applications right).
//   swift scripts/render-dmg-background.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let W: CGFloat = 720, H: CGFloat = 420   // must match the Finder window bounds in build-release.sh

let ribbon = NSColor(srgbRed: 0.851, green: 0.302, blue: 0.188, alpha: 1)
let ochre = NSColor(srgbRed: 0.796, green: 0.659, blue: 0.353, alpha: 1)
let rose = NSColor(srgbRed: 0.780, green: 0.561, blue: 0.627, alpha: 1)
let clay = NSColor(srgbRed: 0.780, green: 0.612, blue: 0.494, alpha: 1)
let paperTop = NSColor(srgbRed: 0.965, green: 0.949, blue: 0.918, alpha: 1)
let paperBottom = NSColor(srgbRed: 0.902, green: 0.878, blue: 0.831, alpha: 1)
let ink = NSColor(srgbRed: 0.129, green: 0.110, blue: 0.082, alpha: 1)
let inkSecondary = NSColor(srgbRed: 0.373, green: 0.341, blue: 0.290, alpha: 1)

let image = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [paperTop.cgColor, paperBottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

    // Drifting light, softened with layered translucent rings (a single heavy blur isn't available here).
    let orbs: [(NSColor, CGFloat, CGFloat, CGFloat)] = [
        (ribbon, 420, W * 0.86, H * 0.2), (ochre, 380, W * 0.08, H * 0.85),
        (rose, 280, W * 0.02, H * 0.1), (clay, 320, W * 0.95, H * 0.9),
    ]
    for (color, r, x, y) in orbs {
        for scale in stride(from: CGFloat(0.5), through: 1.0, by: 0.05) {
            let rr = r * scale
            ctx.setFillColor(color.withAlphaComponent(0.022).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2))
        }
    }

    // Grain
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<10000 {
        let x = CGFloat.random(in: 0...W, using: &rng), y = CGFloat.random(in: 0...H, using: &rng)
        ctx.setFillColor((Bool.random(using: &rng) ? NSColor.black : NSColor.white)
            .withAlphaComponent(CGFloat.random(in: 0.01...0.03, using: &rng)).cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 1.5, height: 1.5))
    }

    // Wordmark, top-left, in the app's faces
    let fontsURL = URL(fileURLWithPath: "Resources/Fonts")
    if let files = try? FileManager.default.contentsOfDirectory(at: fontsURL, includingPropertiesForKeys: nil) {
        for f in files where f.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    NSAttributedString(string: "Concordance", attributes: [
        .font: NSFont(name: "Newsreader", size: 40) ?? NSFont.systemFont(ofSize: 40, weight: .medium),
        .foregroundColor: ink, .paragraphStyle: paragraph, .kern: -1,
    ]).draw(in: CGRect(x: 60, y: H - 96, width: 500, height: 60))
    NSAttributedString(string: "by everpaper.app", attributes: [
        .font: NSFont(name: "iA Writer Mono S", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        .foregroundColor: ribbon, .paragraphStyle: paragraph,
    ]).draw(in: CGRect(x: 62, y: H - 122, width: 400, height: 26))
    NSAttributedString(string: "Find anything on your Mac by what it means.", attributes: [
        .font: NSFont(name: "Newsreader", size: 16) ?? NSFont.systemFont(ofSize: 16),
        .foregroundColor: inkSecondary, .paragraphStyle: paragraph,
    ]).draw(in: CGRect(x: 60, y: 34, width: 560, height: 34))
    NSAttributedString(string: "drag to install", attributes: [
        .font: NSFont(name: "Newsreader", size: 14) ?? NSFont.systemFont(ofSize: 14),
        .foregroundColor: inkSecondary.withAlphaComponent(0.8), .paragraphStyle: paragraph,
    ]).draw(in: CGRect(x: 250, y: 8, width: 220, height: 30))
    return true
}

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed") }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(W))x\(Int(H)))")
