#!/usr/bin/env swift
import AppKit

// Tiler icon generator (task 2.2). Owner decision 2026-07-04: use the
// hand.pinch.fill glyph (catalog pick #6) on the violet tile as the app icon.
// NB: SF Symbols in app icons are outside Apple's symbol license for
// distributed apps — accepted by the owner for this private, non-distributed
// build (revisit before any public release).
//
// Usage:
//   swift Scripts/make-icons.swift --icns <out.icns>
//   swift Scripts/make-icons.swift --preview <out.png>

let bgColor = NSColor(calibratedRed: 0.33, green: 0.29, blue: 0.72, alpha: 1)
let symbolName = "hand.pinch.fill"

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = image.copy() as! NSImage
    copy.lockFocus()
    color.set()
    NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    return copy
}

/// Renders the icon at size×size px (1024-grid: 824pt squircle, centered glyph).
func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 1024.0
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    bgColor.setFill()
    squircle.fill()

    let config = NSImage.SymbolConfiguration(pointSize: 460 * s, weight: .medium)
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = tinted(symbol, .white)
        let maxSide = 560 * s
        let scale = min(maxSide / white.size.width, maxSide / white.size.height)
        let w = white.size.width * scale
        let h = white.size.height * scale
        white.draw(in: NSRect(x: tile.midX - w / 2, y: tile.midY - h / 2, width: w, height: h))
    }
    image.unlockFocus()
    return image
}

func png(_ image: NSImage) -> Data {
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make-icons.swift --icns <out.icns> | --preview <out.png>")
    exit(2)
}

switch args[1] {
case "--preview":
    try! png(render(size: 512)).write(to: URL(fileURLWithPath: args[2]))
    print("preview -> \(args[2])")

case "--icns":
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("tiler-\(UUID().uuidString).iconset")
    try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                               (256, 1), (256, 2), (512, 1), (512, 2)]
    for (pt, scale) in sizes {
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        try! png(render(size: CGFloat(pt * scale))).write(to: tmp.appendingPathComponent(name))
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
    print("icns -> \(args[2])")

default:
    print("unknown mode \(args[1])")
    exit(2)
}
