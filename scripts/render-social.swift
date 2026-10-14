// Renders docs/social-preview.png: warm paper, drifting light, the Concordance mark and wordmark.
//   swift scripts/render-social.swift docs/social-preview.png
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "social-preview.png"
let W: CGFloat = 2560, H: CGFloat = 1280   // 2× for sharpness

let ribbon = NSColor(srgbRed: 0.851, green: 0.302, blue: 0.188, alpha: 1)
let ochre = NSColor(srgbRed: 0.796, green: 0.659, blue: 0.353, alpha: 1)
let rose = NSColor(srgbRed: 0.780, green: 0.561, blue: 0.627, alpha: 1)
let clay = NSColor(srgbRed: 0.780, green: 0.612, blue: 0.494, alpha: 1)
let paperTop = NSColor(srgbRed: 0.965, green: 0.949, blue: 0.918, alpha: 1)
let paperBottom = NSColor(srgbRed: 0.906, green: 0.882, blue: 0.835, alpha: 1)
let ink = NSColor(srgbRed: 0.129, green: 0.110, blue: 0.082, alpha: 1)
let inkSecondary = NSColor(srgbRed: 0.373, green: 0.341, blue: 0.290, alpha: 1)

let image = NSImage(size: NSSize(width: W, height: H), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Paper
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [paperTop.cgColor, paperBottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

    // Out-of-focus light (drawn big, then one blur pass)
    let orbs: [(NSColor, CGFloat, CGFloat, CGFloat)] = [
        (ribbon, 900, W * 0.82, H * 0.20), (ochre, 780, W * 0.90, H * 0.88),
        (rose, 640, W * 0.06, H * 0.90), (clay, 700, W * 0.12, H * 0.10),
    ]
    for (color, r, x, y) in orbs {
        ctx.setFillColor(color.withAlphaComponent(0.5).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    // A single approximation of a heavy blur: many shrinking translucent passes.
    for scale in stride(from: CGFloat(0.55), through: 1.0, by: 0.045) {
        for (color, r, x, y) in orbs {
            let rr = r * scale
            ctx.setFillColor(color.withAlphaComponent(0.028).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2))
        }
    }

    // Grain
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<60000 {
        let x = CGFloat.random(in: 0...W, using: &rng), y = CGFloat.random(in: 0...H, using: &rng)
        ctx.setFillColor((Bool.random(using: &rng) ? NSColor.black : NSColor.white)
            .withAlphaComponent(CGFloat.random(in: 0.01...0.035, using: &rng)).cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
    }

    // The app icon (rendered by render-icon.swift at 1024) at the left
    if let icon = NSImage(contentsOfFile: "Resources/Icon/AppIcon-1024.png") {
        let side: CGFloat = 760
        let rect = CGRect(x: W * 0.055, y: (H - side) / 2 - 20, width: side, height: side)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 60, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        icon.draw(in: rect)
        ctx.restoreGState()
    }

    // Wordmark and tagline, in the app's serif (registered by the app's Font enum — register here directly)
    let fontsURL = URL(fileURLWithPath: "Resources/Fonts")
    if let files = try? FileManager.default.contentsOfDirectory(at: fontsURL, includingPropertiesForKeys: nil) {
        for f in files where f.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
    }
    NSColor.black.set()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left

    let word = NSAttributedString(string: "Concordance", attributes: [
        .font: NSFont(name: "Newsreader", size: 190) ?? NSFont.systemFont(ofSize: 190, weight: .medium),
        .foregroundColor: ink, .paragraphStyle: paragraph,
        .kern: -4,
    ])
    let tag = NSAttributedString(string: "Find anything on your Mac by what it means.", attributes: [
        .font: NSFont(name: "Newsreader", size: 84) ?? NSFont.systemFont(ofSize: 84),
        .foregroundColor: inkSecondary, .paragraphStyle: paragraph,
    ])
    let rubric = NSAttributedString(string: "everpaper.app  ·  EmbeddingGemma 2 on the Neural Engine", attributes: [
        .font: NSFont(name: "iA Writer Mono S", size: 52) ?? NSFont.monospacedSystemFont(ofSize: 52, weight: .regular),
        .foregroundColor: ribbon, .paragraphStyle: paragraph,
    ])
    let textX = W * 0.39, textW = W * 0.56
    word.draw(in: CGRect(x: textX, y: H * 0.55, width: textW, height: 260))
    // Rubric rule between wordmark and tagline
    ctx.setFillColor(ribbon.cgColor)
    ctx.fill(CGRect(x: textX + 8, y: H * 0.52, width: 180, height: 8))
    tag.draw(in: CGRect(x: textX, y: H * 0.36, width: textW, height: 140))
    rubric.draw(in: CGRect(x: textX, y: H * 0.22, width: textW, height: 110))
    return true
}

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed") }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
