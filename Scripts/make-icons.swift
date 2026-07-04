#!/usr/bin/env swift
import AppKit

// Tiler app icon generator (task 2.2): ORIGINAL pinch-over-window artwork
// (pose owner-picked from the hand-gesture catalog; SF Symbols themselves are
// not licensed for app icons, so this is hand-drawn art, not the symbol).
//
// Usage:
//   swift Scripts/make-icons.swift --preview <out.png>   contact sheet, 3 bg variants
//   swift Scripts/make-icons.swift --icns <out.icns> [variant]   full iconset (default 1)

struct BG {
    let name: String
    let top: NSColor
    let bottom: NSColor
}

let variants: [BG] = [
    BG(name: "1 violet",
       top: NSColor(calibratedRed: 0.42, green: 0.38, blue: 0.85, alpha: 1),
       bottom: NSColor(calibratedRed: 0.27, green: 0.22, blue: 0.62, alpha: 1)),
    BG(name: "2 teal",
       top: NSColor(calibratedRed: 0.12, green: 0.62, blue: 0.47, alpha: 1),
       bottom: NSColor(calibratedRed: 0.03, green: 0.38, blue: 0.30, alpha: 1)),
    BG(name: "3 graphite",
       top: NSColor(calibratedRed: 0.35, green: 0.36, blue: 0.40, alpha: 1),
       bottom: NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1)),
]

/// Draws the icon into a size×size context. All geometry in 1024-canvas units.
func drawIcon(size: CGFloat, bg: BG) {
    let s = size / 1024.0
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // macOS icon grid: 824pt squircle centered in 1024 with transparent margins.
    let tile = r(100, 100, 824, 824)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: bg.top, ending: bg.bottom)?.draw(in: squircle, angle: -90)

    squircle.addClip()

    // Window being pinched: lower-left, slightly lifted (rotated 4°).
    let windowLayer = NSAffineTransform()
    windowLayer.translateX(by: 430 * s, yBy: 400 * s)
    windowLayer.rotate(byDegrees: 4)
    windowLayer.translateX(by: -430 * s, yBy: -400 * s)
    windowLayer.concat()

    let win = NSBezierPath(roundedRect: r(220, 240, 420, 320), xRadius: 44 * s, yRadius: 44 * s)
    NSColor.white.setFill()
    win.fill()
    // Header bar: same hue as bg, light.
    let header = NSBezierPath(roundedRect: r(220, 484, 420, 76), xRadius: 38 * s, yRadius: 38 * s)
    bg.top.blended(withFraction: 0.55, of: .white)?.setFill()
    header.fill()
    // Two content lines.
    bg.top.blended(withFraction: 0.82, of: .white)?.setFill()
    NSBezierPath(roundedRect: r(272, 396, 240, 34), xRadius: 17 * s, yRadius: 17 * s).fill()
    NSBezierPath(roundedRect: r(272, 320, 172, 34), xRadius: 17 * s, yRadius: 17 * s).fill()

    windowLayer.invert()
    windowLayer.concat()

    // Pinch hand from the top-right corner, its "mouth" around the window's
    // top-right corner (~640, 585). Index above, thumb below, fist behind.
    NSColor.white.setFill()

    func capsule(from a: CGPoint, to b: CGPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = width * s
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: a.x * s, y: a.y * s))
        path.line(to: NSPoint(x: b.x * s, y: b.y * s))
        NSColor.white.setStroke()
        path.stroke()
    }

    // Fist / back of the hand: bleeds off the top-right squircle edge.
    NSBezierPath(ovalIn: r(720, 610, 340, 380)).fill()
    // Curled middle/ring fingers hinted as bumps on the fist's lower-left edge.
    NSBezierPath(ovalIn: r(730, 585, 130, 130)).fill()
    NSBezierPath(ovalIn: r(800, 555, 120, 120)).fill()

    // Index finger reaching down-left to the corner.
    capsule(from: CGPoint(x: 850, y: 810), to: CGPoint(x: 655, y: 628), width: 112)
    // Thumb reaching left, below the index — the V mouth opens between the tips.
    capsule(from: CGPoint(x: 880, y: 570), to: CGPoint(x: 668, y: 536), width: 100)
}

func render(size: CGFloat, bg: BG) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    drawIcon(size: size, bg: bg)
    image.unlockFocus()
    return image
}

func png(_ image: NSImage) -> Data {
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make-icons.swift --preview <out.png> | --icns <out.icns> [variant]")
    exit(2)
}

switch args[1] {
case "--preview":
    let cell: CGFloat = 300
    let sheet = NSImage(size: NSSize(width: cell * CGFloat(variants.count), height: cell + 40))
    sheet.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: sheet.size).fill()
    for (i, bg) in variants.enumerated() {
        let img = render(size: 256, bg: bg)
        img.draw(in: NSRect(x: CGFloat(i) * cell + 22, y: 52, width: 256, height: 256))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.black,
        ]
        NSAttributedString(string: bg.name, attributes: attrs)
            .draw(at: NSPoint(x: CGFloat(i) * cell + 120, y: 16))
    }
    sheet.unlockFocus()
    try! png(sheet).write(to: URL(fileURLWithPath: args[2]))
    print("preview -> \(args[2])")

case "--icns":
    let variantIndex = args.count > 3 ? (Int(args[3]) ?? 1) - 1 : 0
    let bg = variants[max(0, min(variants.count - 1, variantIndex))]
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("tiler-\(UUID().uuidString).iconset")
    try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                               (256, 1), (256, 2), (512, 1), (512, 2)]
    for (pt, scale) in sizes {
        let px = CGFloat(pt * scale)
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try! png(render(size: px, bg: bg)).write(to: tmp.appendingPathComponent(name))
    }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", tmp.path, "-o", args[2]]
    try! task.run()
    task.waitUntilExit()
    try? FileManager.default.removeItem(at: tmp)
    guard task.terminationStatus == 0 else {
        print("iconutil failed")
        exit(1)
    }
    print("icns -> \(args[2]) (variant \(bg.name))")

default:
    print("unknown mode \(args[1])")
    exit(2)
}
