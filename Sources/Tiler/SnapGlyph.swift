import AppKit
import SwiftUI

/// Static "where the window lands" mini-diagram for the cheat sheet: a screen
/// outline with the target region as a little window (title bar + traffic-light
/// dots). Tiling positions have no arrow — the filled window shows placement.
/// Restore is a bold counter-clockwise revert arrow encircling a centered window;
/// next-display shows the target screen in front with the source tucked behind as a
/// dim dashed outline; ⌃A is a padlock. Rendered via CoreGraphics into a
/// resolution-independent NSImage (exactly the owner-approved artwork; renders in
/// release screenshots; no idle CPU).
struct SnapGlyph: View {
    enum Kind {
        case leftHalf, rightHalf, maximize, leftThird, rightThird, centerThird
        case leftHalfNext, rightHalfNext
        case restore, lock
    }

    let kind: Kind
    var size = CGSize(width: 66, height: 40)

    var body: some View {
        Image(nsImage: SnapGlyphRenderer.image(kind, size: size))
            .accessibilityHidden(true)
    }
}

enum SnapGlyphRenderer {
    static func image(_ kind: SnapGlyph.Kind, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { _ in
            draw(kind, in: CGRect(origin: .zero, size: size))
            return true
        }
    }

    // Fixed colors = the owner-approved artwork, and immune to the appearance the
    // offscreen drawing handler happens to run under (dynamic system colors were
    // resolving windowBackgroundColor to black in --render-shots).
    private static let accent = NSColor(srgbRed: 0.192, green: 0.514, blue: 0.859, alpha: 1)
    private static let bodyC = NSColor(srgbRed: 0.812, green: 0.886, blue: 0.973, alpha: 1)
    private static let grayC = NSColor(srgbRed: 0.541, green: 0.541, blue: 0.525, alpha: 1)
    private static let panelC = NSColor.white

    private static func rr(_ r: NSRect, _ rad: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad)
    }

    /// All geometry is authored against an 84-wide reference cell (the approved
    /// mock) and scaled to the requested size.
    private static func draw(_ kind: SnapGlyph.Kind, in b: CGRect) {
        let f = b.width / 84.0
        let full = b.insetBy(dx: 1.5 * f, dy: 1.5 * f)

        switch kind {
        case .lock: drawLock(full, f); return
        case .leftHalfNext, .rightHalfNext: drawNext(full, right: kind == .rightHalfNext, f); return
        default: break
        }

        screen(full, f)
        switch kind {
        case .leftHalf: pane(leftFrac(full, 0.5, f), f)
        case .rightHalf: pane(rightFrac(full, 0.5, f), f)
        case .maximize: pane(inset(full, f), f)
        case .leftThird: pane(leftFrac(full, 1.0 / 3, f), f)
        case .rightThird: pane(rightFrac(full, 1.0 / 3, f), f)
        case .centerThird: pane(centerFrac(full, f), f)
        case .restore: drawRestore(full, f)
        default: break
        }
    }

    // MARK: pieces (y-up, AppKit)

    private static func screen(_ r: NSRect, _ f: CGFloat) {
        grayC.setStroke(); let p = rr(r, 6 * f); p.lineWidth = 2 * f; p.stroke()
    }

    private static func pane(_ r: NSRect, _ f: CGFloat, dots: Bool = true) {
        let p = rr(r, 3.5 * f); bodyC.setFill(); p.fill()
        accent.setStroke(); p.lineWidth = 1.4 * f; p.stroke()
        let barH = max(5 * f, r.height * 0.17)
        rr(NSRect(x: r.minX, y: r.maxY - barH, width: r.width, height: barH), 3.5 * f).fill()
        accent.setFill(); rr(NSRect(x: r.minX, y: r.maxY - barH, width: r.width, height: barH), 3.5 * f).fill()
        if dots && r.width > 14 * f {
            NSColor.white.withAlphaComponent(0.92).setFill()
            for i in 0..<2 {
                NSBezierPath(ovalIn: NSRect(x: r.minX + 4 * f + CGFloat(i) * 4.5 * f - 1.4 * f,
                                            y: r.maxY - barH / 2 - 1.4 * f, width: 2.8 * f, height: 2.8 * f)).fill()
            }
        }
    }

    private static func inset(_ r: NSRect, _ f: CGFloat) -> NSRect { r.insetBy(dx: 4 * f, dy: 4 * f) }
    private static func leftFrac(_ r: NSRect, _ fr: CGFloat, _ f: CGFloat) -> NSRect {
        let i = inset(r, f); return NSRect(x: i.minX, y: i.minY, width: i.width * fr - 1 * f, height: i.height)
    }
    private static func rightFrac(_ r: NSRect, _ fr: CGFloat, _ f: CGFloat) -> NSRect {
        let i = inset(r, f); return NSRect(x: i.maxX - i.width * fr + 1 * f, y: i.minY, width: i.width * fr - 1 * f, height: i.height)
    }
    private static func centerFrac(_ r: NSRect, _ f: CGFloat) -> NSRect {
        let i = inset(r, f); return NSRect(x: i.minX + i.width / 3, y: i.minY, width: i.width / 3, height: i.height)
    }

    private static func drawRestore(_ r: NSRect, _ f: CGFloat) {
        // Centered window + bold counter-clockwise revert ring encircling it.
        let c = NSPoint(x: r.midX, y: r.midY)
        pane(NSRect(x: c.x - 11 * f, y: c.y - 7.5 * f, width: 22 * f, height: 15 * f), f, dots: false)
        arc(c, 18 * f, 4 * f)
    }

    private static func arc(_ c: NSPoint, _ rad: CGFloat, _ lw: CGFloat) {
        let gc: CGFloat = 118, gd: CGFloat = 74
        let s = gc + gd / 2, e = gc - gd / 2 + 360
        let a = NSBezierPath()
        a.appendArc(withCenter: c, radius: rad, startAngle: s, endAngle: e, clockwise: false)
        accent.setStroke(); a.lineWidth = lw; a.lineCapStyle = .round; a.stroke()
        let ang = CGFloat(e * .pi / 180)
        let ep = NSPoint(x: c.x + rad * cos(ang), y: c.y + rad * sin(ang))
        let t = NSPoint(x: -sin(ang), y: cos(ang)), p = NSPoint(x: cos(ang), y: sin(ang))
        let hw = lw * 1.8, hl = lw * 2.1
        let tip = NSPoint(x: ep.x + t.x * hl, y: ep.y + t.y * hl)
        let h = NSBezierPath(); h.move(to: tip)
        h.line(to: NSPoint(x: ep.x - t.x + p.x * hw, y: ep.y - t.y + p.y * hw))
        h.line(to: NSPoint(x: ep.x - t.x - p.x * hw, y: ep.y - t.y - p.y * hw))
        h.close(); accent.setFill(); h.fill()
    }

    private static func drawLock(_ r: NSRect, _ f: CGFloat) {
        let bw = r.height * 0.5, bh = r.height * 0.42
        let b = NSRect(x: r.midX - bw / 2, y: r.midY - bh / 2 - 1 * f, width: bw, height: bh)
        accent.setFill(); rr(b, 3.5 * f).fill()
        let sh = NSBezierPath()
        sh.appendArc(withCenter: NSPoint(x: b.midX, y: b.maxY), radius: bw * 0.32, startAngle: 0, endAngle: 180, clockwise: false)
        accent.setStroke(); sh.lineWidth = 3.2 * f; sh.lineCapStyle = .round; sh.stroke()
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(ovalIn: NSRect(x: b.midX - 1.6 * f, y: b.midY - 2.3 * f, width: 3.2 * f, height: 3.2 * f)).fill()
    }

    private static func drawNext(_ r: NSRect, right: Bool, _ f: CGFloat) {
        let sw = 50 * f, sh = 32 * f
        let src = NSRect(x: r.minX, y: r.maxY - sh, width: sw, height: sh)
        grayC.setStroke(); let sp = rr(src, 4 * f); sp.lineWidth = 1.8 * f; sp.stroke()
        let ghost = rr(src.insetBy(dx: 6 * f, dy: 5 * f), 2 * f)
        ghost.lineWidth = 1.3 * f; ghost.setLineDash([3 * f, 2.2 * f], count: 2, phase: 0); ghost.stroke()
        let tgt = NSRect(x: r.minX + 18 * f, y: r.minY, width: sw, height: sh)
        panelC.setFill(); rr(tgt, 4 * f).fill()
        screen(tgt, f)
        let ti = tgt.insetBy(dx: 3 * f, dy: 3 * f)
        let half = NSRect(x: right ? ti.maxX - ti.width / 2 + 0.5 * f : ti.minX,
                          y: ti.minY, width: ti.width / 2 - 0.5 * f, height: ti.height)
        pane(half, f, dots: true)
    }
}
