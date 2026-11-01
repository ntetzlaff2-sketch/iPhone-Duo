import SwiftUI

/// Draws one frame of the open trap into a `Canvas`.
///
/// Everything is drawn in trap space (see `TrapLayout`): the left lobe, the
/// fold, the right lobe. Three things animate the leaves:
/// - `game.bloom` unfurls them from the fold after the device opens.
/// - `closure` (live from the hinge) bristles the teeth and flushes the leaves red.
/// - `game.snapFlash` slams two rows of teeth into the fold on a bite.
struct TrapRenderer {
    let game: GameModel
    let layout: TrapLayout
    let closure: Double

    private var time: Double { game.time }
    private var size: CGSize { layout.size }
    private var toothLength: CGFloat { min(size.width / 2, size.height) * 0.075 }

    func draw(in context: inout GraphicsContext) {
        guard !layout.isEmpty else { return }
        if layout.isRotated {
            context.translateBy(x: layout.screenSize.width, y: 0)
            context.rotate(by: .degrees(90))
        }
        let bloom = game.bloom
        drawBackground(&context)
        drawLobe(&context, left: true, bloom: bloom)
        drawLobe(&context, left: false, bloom: bloom)
        drawThroat(&context)
        drawBugs(&context)
        drawParticles(&context)
        drawSnapFlash(&context)
        drawTexts(&context)
    }

    // MARK: Swamp

    private func drawBackground(_ ctx: inout GraphicsContext) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: Theme.background(
            center: CGPoint(x: layout.foldX, y: size.height / 2),
            radius: max(size.width, size.height) * 0.75
        ))

        // Motes of pollen drifting through the air.
        for i in 0..<30 {
            let fi = Double(i)
            let driftX = time * (6 + fi.truncatingRemainder(dividingBy: 5) * 3)
            let driftY = time * (4 + (fi * 7).truncatingRemainder(dividingBy: 6) * 2)
            var x = (fi * 0.618 * size.width + driftX).truncatingRemainder(dividingBy: size.width)
            var y = (fi * 0.377 * size.height - driftY).truncatingRemainder(dividingBy: size.height)
            if x < 0 { x += size.width }
            if y < 0 { y += size.height }
            let alpha = 0.12 + 0.12 * sin(time * 1.3 + fi)
            let r = 1.2 + fi.truncatingRemainder(dividingBy: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(Theme.pollen.opacity(alpha)))
        }
    }

    // MARK: Leaves

    private func lobeCurve(left: Bool) -> LobeCurve {
        let r = left ? layout.leftLobe : layout.rightLobe
        let w = r.width
        let h = r.height
        let m = toothLength * 1.7
        // Built for the left lobe (fold on its right edge), then mirrored for the right one.
        var points = [
            CGPoint(x: r.maxX, y: r.minY + h * 0.05),
            CGPoint(x: r.maxX - w * 0.32, y: r.minY - h * 0.01),
            CGPoint(x: r.minX + m, y: r.minY + h * 0.17),
            CGPoint(x: r.minX + m, y: r.midY),
            CGPoint(x: r.minX + m, y: r.maxY - h * 0.17),
            CGPoint(x: r.maxX - w * 0.32, y: r.maxY + h * 0.01),
            CGPoint(x: r.maxX, y: r.maxY - h * 0.05),
        ]
        if !left {
            points = points.map { CGPoint(x: r.minX + r.maxX - $0.x, y: $0.y) }
        }
        return LobeCurve(points: points, rect: r, left: left)
    }

    private func drawLobe(_ context: inout GraphicsContext, left: Bool, bloom: Double) {
        let curve = lobeCurve(left: left)
        let r = curve.rect
        guard r.width > 20 else { return }

        var ctx = context
        // Unfurl out of the fold, overshooting a little like a leaf springing open.
        let foldEdge = left ? r.maxX : r.minX
        let scaleX = max(Ease.outBack(bloom / 0.62, overshoot: 1.4), 0.001)
        let scaleY = 0.72 + 0.28 * Ease.outCubic(bloom / 0.5)
        ctx.translateBy(x: foldEdge, y: r.midY)
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: -foldEdge, y: -r.midY)

        // Teeth first, so the leaf covers their roots.
        drawTeeth(&ctx, curve: curve, bloom: bloom)

        let path = curve.path
        let outer = CGPoint(x: left ? r.minX : r.maxX, y: r.midY)
        let inner = CGPoint(x: foldEdge, y: r.midY)
        // The red throat creeps outward as the trap folds.
        let blush = 0.74 - 0.36 * closure
        ctx.fill(path, with: .linearGradient(Gradient(stops: [
            .init(color: Theme.rim, location: 0),
            .init(color: Theme.leaf, location: 0.12),
            .init(color: Theme.leaf, location: max(blush - 0.2, 0.13)),
            .init(color: Theme.blush, location: blush),
            .init(color: Theme.crimson, location: 1),
        ]), startPoint: outer, endPoint: inner))

        // Veins fanning out from the midrib.
        var veins = Path()
        for k in 0..<7 {
            let s = 0.12 + 0.76 * Double(k) / 6
            let (rimPoint, _) = curve.sample(s)
            let start = CGPoint(x: foldEdge, y: r.midY + (rimPoint.y - r.midY) * 0.55)
            let control = CGPoint(x: (foldEdge + rimPoint.x) / 2, y: r.midY + (rimPoint.y - r.midY) * 0.95)
            veins.move(to: start)
            veins.addQuadCurve(to: start.lerp(to: rimPoint, 0.88), control: control)
        }
        ctx.stroke(veins, with: .color(Theme.crimson.opacity(0.28)), lineWidth: 1.5)

        // A soft gloss, like a wet leaf.
        let glossCenter = CGPoint(x: outer.x + (inner.x - outer.x) * 0.35, y: r.minY + r.height * 0.3)
        let glossRadius = min(r.width, r.height) * 0.35
        ctx.fill(Path(ellipseIn: CGRect(x: glossCenter.x - glossRadius, y: glossCenter.y - glossRadius,
                                        width: glossRadius * 2, height: glossRadius * 2)),
                 with: .radialGradient(Gradient(colors: [.white.opacity(0.13), .clear]),
                                       center: glossCenter, startRadius: 0, endRadius: glossRadius))

        ctx.stroke(path, with: .color(Theme.rim), lineWidth: 3)
        drawTriggerHairs(&ctx, lobe: r, left: left, bloom: bloom)
    }

    private func drawTeeth(_ ctx: inout GraphicsContext, curve: LobeCurve, bloom: Double) {
        let count = game.stage.toothCount
        let base = toothLength
        for i in 0..<count {
            let fi = Double(i)
            let s = 0.05 + 0.9 * fi / Double(count - 1)
            let (p, tangent) = curve.sample(s)
            let normal = curve.outwardNormal(at: p, tangent: tangent)

            // The middle teeth pop out first, then the rest ripple toward the ends.
            let delay = 0.3 + abs(s - 0.5) * 0.9
            let grow = Ease.outBack((bloom - delay) / 0.28, overshoot: 2.2)
            guard grow > 0.01 else { continue }

            let jitter = 0.85 + 0.15 * sin(fi * 1.7)
            let shiver = closure > 0.2 ? sin(time * 30 + fi) * 0.05 * closure : 0
            let wiggle = sin(time * 2.6 + fi * 0.9) * 0.06 + shiver
            let length = base * jitter * (1 + 0.55 * closure) * grow
            // Teeth curl toward the middle of the leaf as the trap folds, like fingers closing.
            let towardMiddle = (curve.rect.midY - p.y) / (curve.rect.height / 2)
            let curl = CGVector(dx: 0, dy: towardMiddle * (0.15 + 0.75 * closure))
            let dir = (normal + curl + tangent.normalized * wiggle).normalized
            let side = dir.perpendicular
            let width = base * 0.17
            let tip = p + dir * length

            var tooth = Path()
            tooth.move(to: p + side * width)
            tooth.addQuadCurve(to: tip, control: p + dir * (length * 0.55) + side * (width * 0.35))
            tooth.addQuadCurve(to: p + side * -width, control: p + dir * (length * 0.55) + side * (-width * 0.35))
            tooth.closeSubpath()
            ctx.fill(tooth, with: .linearGradient(Gradient(colors: [Theme.tooth, Theme.toothTip]),
                                                  startPoint: p, endPoint: tip))
        }
    }

    /// The little hairs that tell a real flytrap something has landed.
    private func drawTriggerHairs(_ ctx: inout GraphicsContext, lobe r: CGRect, left: Bool, bloom: Double) {
        let appear = Ease.outCubic((bloom - 0.7) / 0.3)
        guard appear > 0 else { return }
        let landed = game.bugs.filter { $0.state == .landed }
        for along in [-0.28, 0.0, 0.28] {
            let x = left ? r.maxX - r.width * 0.33 : r.minX + r.width * 0.33
            let base = CGPoint(x: x, y: r.midY + along * r.height / 2)
            let disturbed = landed.contains { ($0.position - base).length < 80 }
            let twitch = disturbed ? sin(time * 40 + along * 10) * 0.45 : sin(time * 1.5 + along * 4) * 0.1
            let hairLength = 16 * appear
            let tip = base + CGVector(dx: sin(twitch) * hairLength, dy: -cos(twitch) * hairLength)
            var hair = Path()
            hair.move(to: base)
            hair.addLine(to: tip)
            ctx.stroke(hair, with: .color(Theme.toothTip.opacity(0.75)), lineWidth: 1.6)
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 2.5, y: tip.y - 2.5, width: 5, height: 5)),
                     with: .color(disturbed ? Theme.pollen : Theme.toothTip.opacity(0.9)))
        }
    }

    private func drawThroat(_ ctx: inout GraphicsContext) {
        let half = layout.foldGap + 18 + 50 * closure
        let rect = CGRect(x: layout.foldX - half, y: 0, width: half * 2, height: size.height)
        let dark = Color.black.opacity(0.3 + 0.4 * closure)
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [.clear, dark, .clear]),
                                                   startPoint: CGPoint(x: rect.minX, y: 0),
                                                   endPoint: CGPoint(x: rect.maxX, y: 0)))
    }

    // MARK: Bugs

    private func drawBugs(_ ctx: inout GraphicsContext) {
        for bug in game.bugs {
            var p = bug.position
            var scale: CGFloat = 1
            var rotation = Angle.zero

            switch bug.state {
            case .flying, .escaping:
                p = p + up(CGFloat(sin(time * 14 + bug.seed)) * 3)
                rotation = .radians(Double(bug.velocity.dx / 500).clamped(to: -0.35...0.35))
            case .landed:
                drawLandedMarker(&ctx, bug: bug)
            case .caught:
                let t = (time - bug.stateTime) / 0.45
                scale = max(0, 1 - Ease.inCubic(t))
                rotation = .radians(t * 8)
            }

            if bug.kind == .goldfly {
                let r = bug.kind.size * 1.1 * scale
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Theme.gold.opacity(0.75), .clear]),
                                               center: p, startRadius: 0, endRadius: r))
            }

            drawUpright(ctx, Text(bug.kind.emoji).font(.system(size: bug.kind.size)),
                        at: p, scale: scale, rotation: rotation)

            // Uh-oh: the leaves are closing in.
            if bug.state == .landed && closure > 0.3 {
                drawUpright(ctx, Text("❗️").font(.system(size: 16)),
                            at: p + up(24) + across(16), scale: 0.6 + closure * 0.6)
            }
        }
    }

    private func drawLandedMarker(_ ctx: inout GraphicsContext, bug: Bug) {
        let p = bug.position
        let s = bug.kind.size
        let age = time - bug.stateTime
        let pulse = 0.5 + 0.5 * sin(time * 6 + bug.seed)
        let color = bug.kind == .bee ? Theme.danger : Theme.catchable

        // Shadow on the leaf.
        let shadow = CGRect(x: p.x - s * 0.45, y: p.y + s * 0.2, width: s * 0.9, height: s * 0.3)
        ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(0.3)))

        // A ring splashes out on touchdown, then a timer arc shows when it'll fly off.
        let land = Ease.outCubic(age / 0.25)
        let r = s * (0.78 + 0.08 * pulse) * (0.4 + 0.6 * land)
        let ring = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        ctx.stroke(Path(ellipseIn: ring), with: .color(color.opacity(0.25 + 0.3 * pulse)), lineWidth: 2)

        let total = max(bug.nextDecision - bug.stateTime, 0.01)
        let remaining = ((bug.nextDecision - time) / total).clamped(to: 0...1)
        var arc = Path()
        arc.addArc(center: p, radius: r + 4, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * remaining), clockwise: false)
        ctx.stroke(arc, with: .color(color.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    // MARK: Effects

    private func drawParticles(_ ctx: inout GraphicsContext) {
        for particle in game.particles {
            let age = time - particle.birth
            guard age >= 0 else { continue }
            let k = age / particle.life
            let r = particle.radius * (1 - 0.4 * k)
            let rect = CGRect(x: particle.position.x - r, y: particle.position.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(particle.color.opacity(1 - k)))
        }
    }

    private func drawSnapFlash(_ ctx: inout GraphicsContext) {
        guard let t = game.snapFlash else { return }
        let fade = 1 - t
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.32 * fade * fade)))

        // Two rows of teeth slam in from the rims and interlock in the fold.
        let k = Ease.outCubic(t / 0.45)
        let step: CGFloat = 34
        let amplitude: CGFloat = 16
        for left in [true, false] {
            let x = left ? layout.foldX * k : size.width - (size.width - layout.foldX) * k
            var jaw = Path()
            var y: CGFloat = left ? 0 : -step / 2
            jaw.move(to: CGPoint(x: x, y: y))
            var out = true
            while y < size.height + step {
                y += step / 2
                let dx = out ? (left ? amplitude : -amplitude) : 0
                jaw.addLine(to: CGPoint(x: x + dx, y: y))
                out.toggle()
            }
            var glow = ctx
            glow.addFilter(.blur(radius: 8))
            glow.stroke(jaw, with: .color(Theme.toothTip.opacity(0.9 * fade)), lineWidth: 10)
            ctx.stroke(jaw, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 3 + 3 * fade, lineJoin: .round))
        }
    }

    private func drawTexts(_ ctx: inout GraphicsContext) {
        for text in game.texts {
            let age = time - text.birth
            let k = age / FloatingText.life
            let pop = Ease.outBack(age / 0.18, overshoot: 2.5)
            let alpha = k < 0.6 ? 1 : 1 - (k - 0.6) / 0.4
            let p = text.position + up(60 * Ease.outCubic(k))
            let label = Text(text.text)
                .font(.system(size: text.size, weight: .black, design: .rounded))
                .foregroundStyle(text.color)
            var shadowed = ctx
            shadowed.addFilter(.shadow(color: .black.opacity(0.7), radius: 0, x: 2, y: 2))
            drawUpright(shadowed, label, at: p, scale: pop, opacity: alpha)
        }
    }

    // MARK: Helpers

    /// Draws text the right way up even when trap space is rotated.
    private func drawUpright(_ context: GraphicsContext, _ text: Text, at point: CGPoint,
                             scale: CGFloat = 1, rotation: Angle = .zero, opacity: Double = 1) {
        guard scale > 0.01 else { return }
        var ctx = context
        ctx.translateBy(x: point.x, y: point.y)
        if layout.isRotated { ctx.rotate(by: .degrees(-90)) }
        ctx.rotate(by: rotation)
        ctx.scaleBy(x: scale, y: scale)
        ctx.opacity = opacity
        ctx.draw(text, at: .zero)
    }

    /// A vector pointing up on screen, by `distance`, in trap space.
    private func up(_ distance: CGFloat) -> CGVector {
        layout.isRotated ? CGVector(dx: -distance, dy: 0) : CGVector(dx: 0, dy: -distance)
    }

    /// A vector pointing right on screen, by `distance`, in trap space.
    private func across(_ distance: CGFloat) -> CGVector {
        layout.isRotated ? CGVector(dx: 0, dy: -distance) : CGVector(dx: distance, dy: 0)
    }
}

/// The rim of one leaf: two cubic Béziers from the top of the fold, out to the rim and back.
private struct LobeCurve {
    let points: [CGPoint]
    let rect: CGRect
    let left: Bool

    private var foldMiddle: CGPoint { CGPoint(x: left ? rect.maxX : rect.minX, y: rect.midY) }

    var path: Path {
        var path = Path()
        path.move(to: points[0])
        path.addCurve(to: points[3], control1: points[1], control2: points[2])
        path.addCurve(to: points[6], control1: points[4], control2: points[5])
        path.closeSubpath()
        return path
    }

    /// The point and tangent at `s` (0...1) along the rim.
    func sample(_ s: Double) -> (CGPoint, CGVector) {
        let segment = s < 0.5 ? 0 : 3
        let t = CGFloat(s < 0.5 ? s * 2 : (s - 0.5) * 2)
        let a = points[segment], b = points[segment + 1], c = points[segment + 2], d = points[segment + 3]
        let mt = 1 - t
        let w0 = mt * mt * mt, w1 = 3 * mt * mt * t, w2 = 3 * mt * t * t, w3 = t * t * t
        let point = CGPoint(x: w0 * a.x + w1 * b.x + w2 * c.x + w3 * d.x,
                            y: w0 * a.y + w1 * b.y + w2 * c.y + w3 * d.y)
        let d0 = 3 * mt * mt, d1 = 6 * mt * t, d2 = 3 * t * t
        let tangent = CGVector(dx: d0 * (b.x - a.x) + d1 * (c.x - b.x) + d2 * (d.x - c.x),
                               dy: d0 * (b.y - a.y) + d1 * (c.y - b.y) + d2 * (d.y - c.y))
        return (point, tangent)
    }

    /// The normal at a rim point, pointing out of the leaf.
    func outwardNormal(at point: CGPoint, tangent: CGVector) -> CGVector {
        let n = tangent.normalized.perpendicular
        let out = point - foldMiddle
        return n.dx * out.dx + n.dy * out.dy < 0 ? n * -1 : n
    }
}
