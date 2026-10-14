// Renders the Concordance app icon: Everpaper's cream paper tile, paper grain and folded corner, with the bookmark
// ribbon turned into a magnifying glass whose handle keeps the ribbon's V-notch, and a rubric sparkle in the lens.
//
//   swift scripts/render-icon.swift <out.png> [size]
import AppKit

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "AppIcon.png"
let size = args.count > 2 ? CGFloat(Double(args[2]) ?? 1024) : 1024
let s = size / 1024   // all coordinates below are on a 1024 grid (y up)

let ribbon = NSColor(srgbRed: 0.851, green: 0.302, blue: 0.188, alpha: 1)        // Everpaper's bookmark red-orange
let ribbonDeep = NSColor(srgbRed: 0.690, green: 0.220, blue: 0.140, alpha: 1)
let paperTop = NSColor(srgbRed: 0.961, green: 0.945, blue: 0.914, alpha: 1)
let paperBottom = NSColor(srgbRed: 0.910, green: 0.886, blue: 0.839, alpha: 1)

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: an 824-point tile centred on the 1024 canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let corner: CGFloat = 186
    let fold: CGFloat = 132
    func tilePath() -> CGPath {
        // Rounded tile with the top-right corner cut for the fold.
        let p = CGMutablePath()
        p.move(to: CGPoint(x: tile.minX + corner, y: tile.minY))
        p.addLine(to: CGPoint(x: tile.maxX - corner, y: tile.minY))
        p.addQuadCurve(to: CGPoint(x: tile.maxX, y: tile.minY + corner), control: CGPoint(x: tile.maxX, y: tile.minY))
        p.addLine(to: CGPoint(x: tile.maxX, y: tile.maxY - fold))
        p.addLine(to: CGPoint(x: tile.maxX - fold, y: tile.maxY))
        p.addLine(to: CGPoint(x: tile.minX + corner, y: tile.maxY))
        p.addQuadCurve(to: CGPoint(x: tile.minX, y: tile.maxY - corner), control: CGPoint(x: tile.minX, y: tile.maxY))
        p.addLine(to: CGPoint(x: tile.minX, y: tile.minY + corner))
        p.addQuadCurve(to: CGPoint(x: tile.minX + corner, y: tile.minY), control: CGPoint(x: tile.minX, y: tile.minY))
        p.closeSubpath()
        return p
    }

    // Drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    ctx.addPath(tilePath())
    ctx.setFillColor(paperBottom.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Paper: vertical gradient plus grain.
    ctx.saveGState()
    ctx.addPath(tilePath())
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [paperTop.cgColor, paperBottom.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<26000 {
        let x = CGFloat.random(in: tile.minX...tile.maxX, using: &rng)
        let y = CGFloat.random(in: tile.minY...tile.maxY, using: &rng)
        let dark = Bool.random(using: &rng)
        ctx.setFillColor((dark ? NSColor.black : NSColor.white).withAlphaComponent(CGFloat.random(in: 0.015...0.05, using: &rng)).cgColor)
        ctx.fill(CGRect(x: x, y: y, width: 1.6, height: 1.6))
    }
    ctx.restoreGState()

    // Folded corner: the flap, lighter, casting a soft shadow onto the page.
    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: tile.maxX - fold, y: tile.maxY))
    flap.addLine(to: CGPoint(x: tile.maxX - fold, y: tile.maxY - fold + 30))
    flap.addQuadCurve(to: CGPoint(x: tile.maxX - fold + 30, y: tile.maxY - fold),
                      control: CGPoint(x: tile.maxX - fold, y: tile.maxY - fold))
    flap.addLine(to: CGPoint(x: tile.maxX, y: tile.maxY - fold))
    flap.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -6, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    ctx.addPath(flap)
    ctx.setFillColor(NSColor(srgbRed: 0.975, green: 0.965, blue: 0.94, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // The magnifier. The lens ring is the ribbon bent into a circle; the handle is the ribbon's tail.
    let lensCenter = CGPoint(x: 460, y: 560)
    let lensRadius: CGFloat = 196
    let band: CGFloat = 66

    // Handle with V-notch, along the 45° down-right axis.
    let angle = -CGFloat.pi / 4
    let dir = CGPoint(x: cos(angle), y: sin(angle))
    let normal = CGPoint(x: -dir.y, y: dir.x)
    let start = CGPoint(x: lensCenter.x + dir.x * (lensRadius - 6), y: lensCenter.y + dir.y * (lensRadius - 6))
    let length: CGFloat = 250
    let end = CGPoint(x: start.x + dir.x * length, y: start.y + dir.y * length)
    let notch: CGFloat = 44
    let half = band / 2 + 4
    func pt(_ base: CGPoint, _ along: CGFloat, _ across: CGFloat) -> CGPoint {
        CGPoint(x: base.x + dir.x * along + normal.x * across, y: base.y + dir.y * along + normal.y * across)
    }
    let handle = CGMutablePath()
    handle.move(to: pt(start, 0, half))
    handle.addLine(to: pt(end, 0, half))
    handle.addLine(to: pt(end, -notch, 0))
    handle.addLine(to: pt(end, 0, -half))
    handle.addLine(to: pt(start, 0, -half))
    handle.closeSubpath()

    // Lens glass: a faint cool tint and a highlight, so the lens reads as glass on paper.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius,
                              width: lensRadius * 2, height: lensRadius * 2))
    ctx.clip()
    let glass = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [NSColor.white.withAlphaComponent(0.75).cgColor,
                                    NSColor(srgbRed: 0.93, green: 0.90, blue: 0.86, alpha: 0.35).cgColor] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(glass, startCenter: CGPoint(x: lensCenter.x - 70, y: lensCenter.y + 80), startRadius: 0,
                           endCenter: lensCenter, endRadius: lensRadius, options: [])
    ctx.restoreGState()

    // Ring and handle, with a gentle bevel shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: ribbonDeep.withAlphaComponent(0.45).cgColor)
    ctx.addPath(handle)
    ctx.setFillColor(ribbon.cgColor)
    ctx.fillPath()
    ctx.setLineWidth(band)
    ctx.setStrokeColor(ribbon.cgColor)
    ctx.strokeEllipse(in: CGRect(x: lensCenter.x - lensRadius + band / 2, y: lensCenter.y - lensRadius + band / 2,
                                 width: lensRadius * 2 - band, height: lensRadius * 2 - band))
    ctx.restoreGState()

    // A soft highlight along the top of the ring.
    ctx.saveGState()
    ctx.setLineWidth(10)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.addArc(center: lensCenter, radius: lensRadius - 18, startAngle: .pi * 0.62, endAngle: .pi * 0.92, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // The sparkle: a four-point star, "found by meaning".
    let star = CGMutablePath()
    let r: CGFloat = 74, k: CGFloat = 0.22
    let c = CGPoint(x: lensCenter.x - 8, y: lensCenter.y + 6)
    for i in 0..<4 {
        let a = CGFloat(i) * .pi / 2 + .pi / 2
        let tip = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        let next = CGPoint(x: c.x + cos(a + .pi / 2) * r, y: c.y + sin(a + .pi / 2) * r)
        if i == 0 { star.move(to: tip) }
        star.addQuadCurve(to: next, control: CGPoint(x: c.x + cos(a + .pi / 4) * r * k, y: c.y + sin(a + .pi / 4) * r * k))
    }
    star.closeSubpath()
    ctx.addPath(star)
    ctx.setFillColor(ribbon.cgColor)
    ctx.fillPath()
    return true
}

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed") }
try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) at \(Int(size)) px")
