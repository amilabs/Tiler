import SwiftUI

/// Static "where the window lands" mini-diagram for the cheat sheet: a screen
/// outline with the target region drawn as a little window (title bar), plus a
/// directional chevron that ties the swipe/arrow to the result. No animation
/// (renders in release screenshots; costs no idle CPU).
struct SnapGlyph: View {
    enum Kind {
        case leftHalf, rightHalf, maximize, leftThird, rightThird, centerThird
        case leftHalfNext, rightHalfNext
        case restore, lock
    }

    let kind: Kind
    var size = CGSize(width: 62, height: 36)

    var body: some View {
        Canvas { ctx, canvas in
            let accent = GraphicsContext.Shading.color(.accentColor)
            let paneBody = GraphicsContext.Shading.color(.accentColor.opacity(0.20))
            let stroke = GraphicsContext.Shading.color(.secondary.opacity(0.55))
            let onAccent = GraphicsContext.Shading.color(Color(white: 1, opacity: 0.95))

            let full = CGRect(x: 1.5, y: 1.5, width: canvas.width - 3, height: canvas.height - 3)

            switch kind {
            case .lock:
                drawLock(ctx, in: full, accent: accent)
                return
            case .leftHalfNext, .rightHalfNext:
                drawDualScreen(ctx, in: full, right: kind == .rightHalfNext,
                               stroke: stroke, paneBody: paneBody, accent: accent)
                return
            default:
                break
            }

            // Single screen.
            drawScreen(ctx, full, stroke: stroke)
            let inset = full.insetBy(dx: 3, dy: 3)

            switch kind {
            case .leftHalf:
                let pane = leftFraction(inset, 0.5)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                chevron(ctx, at: emptyCenter(inset, paneOnLeft: true), dir: .left, shading: accent)
            case .rightHalf:
                let pane = rightFraction(inset, 0.5)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                chevron(ctx, at: emptyCenter(inset, paneOnLeft: false), dir: .right, shading: accent)
            case .leftThird:
                let pane = leftFraction(inset, 1.0 / 3.0)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                chevron(ctx, at: CGPoint(x: inset.minX + inset.width * 0.62, y: inset.midY),
                        dir: .left, shading: accent)
            case .rightThird:
                let pane = rightFraction(inset, 1.0 / 3.0)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                chevron(ctx, at: CGPoint(x: inset.minX + inset.width * 0.38, y: inset.midY),
                        dir: .right, shading: accent)
            case .centerThird:
                let pane = CGRect(x: inset.minX + inset.width / 3, y: inset.minY,
                                  width: inset.width / 3, height: inset.height)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                chevron(ctx, at: CGPoint(x: pane.midX, y: pane.midY + 1), dir: .up, shading: onAccent)
            case .maximize:
                drawPane(ctx, inset, body: paneBody, accent: accent)
                chevron(ctx, at: CGPoint(x: inset.midX, y: inset.midY + 1), dir: .up, shading: onAccent)
            case .restore:
                let pane = CGRect(x: inset.midX - inset.width * 0.22, y: inset.midY - inset.height * 0.28,
                                  width: inset.width * 0.44, height: inset.height * 0.56)
                drawPane(ctx, pane, body: paneBody, accent: accent)
                restoreArrow(ctx, around: pane, shading: accent)
            default:
                break
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    // MARK: - Pieces

    private func drawScreen(_ ctx: GraphicsContext, _ rect: CGRect, stroke: GraphicsContext.Shading) {
        ctx.stroke(Path(roundedRect: rect, cornerRadius: 4.5), with: stroke, lineWidth: 1.4)
    }

    private func drawPane(_ ctx: GraphicsContext, _ rect: CGRect,
                          body: GraphicsContext.Shading, accent: GraphicsContext.Shading) {
        let path = Path(roundedRect: rect, cornerRadius: 2.5)
        ctx.fill(path, with: body)
        ctx.stroke(path, with: accent, lineWidth: 1)
        let barH = max(3, rect.height * 0.17)
        let bar = Path(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: barH),
                       cornerRadius: 2.5)
        ctx.fill(bar, with: accent)
    }

    private func drawDualScreen(_ ctx: GraphicsContext, in rect: CGRect, right: Bool,
                                stroke: GraphicsContext.Shading, paneBody: GraphicsContext.Shading,
                                accent: GraphicsContext.Shading) {
        let gap: CGFloat = 8
        let w = (rect.width - gap) / 2
        let a = CGRect(x: rect.minX, y: rect.minY + 2, width: w, height: rect.height - 4)
        let b = CGRect(x: rect.minX + w + gap, y: rect.minY + 2, width: w, height: rect.height - 4)
        drawScreen(ctx, a, stroke: stroke)
        drawScreen(ctx, b, stroke: stroke)
        let inset = b.insetBy(dx: 2.5, dy: 2.5)
        let pane = right ? rightFraction(inset, 0.5) : leftFraction(inset, 0.5)
        drawPane(ctx, pane, body: paneBody, accent: accent)
        chevron(ctx, at: CGPoint(x: rect.midX, y: rect.midY), dir: .right, shading: accent)
    }

    private func drawLock(_ ctx: GraphicsContext, in rect: CGRect, accent: GraphicsContext.Shading) {
        let bodyW = rect.height * 0.66
        let bodyH = rect.height * 0.5
        let body = CGRect(x: rect.midX - bodyW / 2, y: rect.midY - bodyH * 0.15,
                          width: bodyW, height: bodyH)
        ctx.fill(Path(roundedRect: body, cornerRadius: 3), with: accent)
        var shackle = Path()
        let r = bodyW * 0.34
        shackle.addArc(center: CGPoint(x: body.midX, y: body.minY),
                       radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        ctx.stroke(shackle, with: accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private enum Dir { case left, right, up }

    private func chevron(_ ctx: GraphicsContext, at c: CGPoint, dir: Dir,
                         shading: GraphicsContext.Shading) {
        let s: CGFloat = 3.4
        var p = Path()
        switch dir {
        case .left:
            p.move(to: CGPoint(x: c.x + s, y: c.y - s))
            p.addLine(to: CGPoint(x: c.x - s, y: c.y))
            p.addLine(to: CGPoint(x: c.x + s, y: c.y + s))
        case .right:
            p.move(to: CGPoint(x: c.x - s, y: c.y - s))
            p.addLine(to: CGPoint(x: c.x + s, y: c.y))
            p.addLine(to: CGPoint(x: c.x - s, y: c.y + s))
        case .up:
            p.move(to: CGPoint(x: c.x - s, y: c.y + s))
            p.addLine(to: CGPoint(x: c.x, y: c.y - s))
            p.addLine(to: CGPoint(x: c.x + s, y: c.y + s))
        }
        ctx.stroke(p, with: shading, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func restoreArrow(_ ctx: GraphicsContext, around pane: CGRect,
                              shading: GraphicsContext.Shading) {
        let c = CGPoint(x: pane.midX, y: pane.midY)
        let r = max(pane.width, pane.height) * 0.62
        var arc = Path()
        arc.addArc(center: c, radius: r, startAngle: .degrees(35), endAngle: .degrees(300), clockwise: false)
        ctx.stroke(arc, with: shading, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        // Arrowhead at the arc start (~35°).
        let a = CGFloat(35 * Double.pi / 180)
        let tip = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        var head = Path()
        head.move(to: CGPoint(x: tip.x - 3.4, y: tip.y - 1))
        head.addLine(to: tip)
        head.addLine(to: CGPoint(x: tip.x + 0.5, y: tip.y + 3.6))
        ctx.stroke(head, with: shading, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Region helpers

    private func leftFraction(_ r: CGRect, _ f: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: r.minY, width: r.width * f - 1, height: r.height)
    }
    private func rightFraction(_ r: CGRect, _ f: CGFloat) -> CGRect {
        CGRect(x: r.maxX - r.width * f + 1, y: r.minY, width: r.width * f - 1, height: r.height)
    }
    private func emptyCenter(_ r: CGRect, paneOnLeft: Bool) -> CGPoint {
        CGPoint(x: paneOnLeft ? r.minX + r.width * 0.75 : r.minX + r.width * 0.25, y: r.midY)
    }
}
