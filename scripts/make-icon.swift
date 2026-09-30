// Draws the app icon and writes every macOS size into the AppIcon asset catalog.
// Run from the repository root:  swift scripts/make-icon.swift
import AppKit

let output = URL(fileURLWithPath: "Sources/Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let green = color(0x39ff88)
let yellow = color(0xffc247)
let cyan = color(0x3ff0ff)

/// Rectangle with the top-right and bottom-left corners cut at 45° (the panel's shape). y grows upwards.
func cutCorners(_ r: CGRect, _ cut: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX, y: r.maxY))
    p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
    p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
    p.addLine(to: CGPoint(x: r.minX + cut, y: r.minY))
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
    p.closeSubpath()
    return p
}

/// The 1024 × 1024 master, following the macOS icon grid: an 824 pt rounded body with a soft drop shadow.
func drawIcon(in ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.45))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()
    ctx.restoreGState()

    // Background: dark green glow fading to black, with CRT scanlines.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(colorsSpace: nil, colors: [color(0x0c3d20), color(0x04170b), color(0x010603)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawRadialGradient(background, startCenter: CGPoint(x: 512, y: 600), startRadius: 0, endCenter: CGPoint(x: 512, y: 600), endRadius: 620, options: .drawsAfterEndLocation)
    ctx.setFillColor(color(0x39ff88, 0.05))
    var y = body.minY
    while y < body.maxY {
        ctx.fill(CGRect(x: body.minX, y: y, width: body.width, height: 3))
        y += 9
    }
    ctx.restoreGState()

    // Hairline rim
    ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 3, dy: 3), cornerWidth: 182, cornerHeight: 182, transform: nil))
    ctx.setStrokeColor(color(0x39ff88, 0.28))
    ctx.setLineWidth(4)
    ctx.strokePath()

    // Glyph: cut-corner frame with three rising bars, in neon green with a glow.
    let frame = CGRect(x: 262, y: 262, width: 500, height: 500)
    let cut: CGFloat = 92
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 46, color: color(0x39ff88, 0.75))
    ctx.addPath(cutCorners(frame, cut))
    ctx.setStrokeColor(green)
    ctx.setLineWidth(30)
    ctx.setLineJoin(.miter)
    ctx.strokePath()

    let bars: [(x: CGFloat, height: CGFloat)] = [(352, 150), (462, 262), (572, 206)]
    for bar in bars {
        let rect = CGRect(x: bar.x, y: 352, width: 70, height: bar.height)
        let gradient = CGGradient(colorsSpace: nil, colors: [color(0xb6ffd2), green] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addRect(rect)
        ctx.fillPath()
        ctx.addRect(rect)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Yellow and cyan highlights on the two cut corners, as on the panel.
    for (start, end, tint) in [
        (CGPoint(x: frame.maxX - cut, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY - cut), yellow),
        (CGPoint(x: frame.minX, y: frame.minY + cut), CGPoint(x: frame.minX + cut, y: frame.minY), cyan),
    ] {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 30, color: tint)
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.setStrokeColor(tint)
        ctx.setLineWidth(22)
        ctx.setLineCap(.square)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

// macOS slots: 16, 32, 128, 256, 512 pt at 1x and 2x.
var images: [[String: String]] = []
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(pixels: points * scale).write(to: output.appending(path: name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: output.appending(path: "Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": ["author": "xcode", "version": 1]], options: .prettyPrinted)
    .write(to: output.deletingLastPathComponent().appending(path: "Contents.json"))
print("Wrote \(images.count) icon sizes to \(output.path)")
