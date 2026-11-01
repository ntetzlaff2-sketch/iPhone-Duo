import SwiftUI

/// The closed device, on the cover display.
///
/// When the phone folds shut, the two leaves come flying in from the sides and
/// slam together into a pod, squashing on impact. Then the trap chews whatever
/// it caught, or dozes off if its belly is empty.
struct CoverView: View {
    let game: GameModel
    /// Set when there's no real hinge, so you can still get back in.
    var onOpen: (() -> Void)?

    @State private var appeared = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(appeared)
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                header
                Canvas { context, size in
                    PodRenderer(t: t, mood: mood, stage: game.stage).draw(in: &context, size: size)
                }
                .frame(height: 330)
                .accessibilityLabel(mood == .chewing ? "The flytrap is chewing" : "The flytrap is asleep")
                bellyRow
                stats
                Spacer(minLength: 0)
                footer(t: t)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .fontDesign(.rounded)
        .background {
            RadialGradient(colors: [Theme.bgInner, Theme.bgOuter], center: .center, startRadius: 0, endRadius: 500)
                .ignoresSafeArea()
        }
        .onAppear { appeared = .now }
    }

    private var mood: PodRenderer.Mood {
        if !game.belly.isEmpty { return .chewing }
        return game.phase == .playing ? .waiting : .sleeping
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(game.phase == .playing ? "Snack break" : "\(game.stage.emoji) \(game.stage.name)")
                .font(.title2.weight(.black))
            Text(game.phase == .playing ? "The round is paused while I'm shut" : "Snaptrap")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var bellyRow: some View {
        if game.belly.isEmpty {
            Text(mood == .sleeping ? "Zzz… nothing in my belly" : "Still hungry…")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
        } else {
            VStack(spacing: 6) {
                Text("Digesting \(game.belly.count) bug\(game.belly.count == 1 ? "" : "s")")
                    .font(.headline)
                Text(game.belly.suffix(10).map(\.emoji).joined() + (game.belly.count > 10 ? " +\(game.belly.count - 10)" : ""))
                    .font(.title2)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("Score", game.score)
            stat("Best", game.best)
            stat("Eaten", game.lifetimeEaten)
        }
        .padding(.vertical, 12)
        .background(.black.opacity(0.35), in: .rect(cornerRadius: 18))
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.title2.weight(.black))
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func footer(t: Double) -> some View {
        if let onOpen {
            Button("Unfold", systemImage: "book", action: onOpen)
                .buttonStyle(.borderedProminent)
                .tint(Theme.leaf)
        } else {
            Label("Unfold to hunt", systemImage: "book")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.catchable)
                .opacity(0.55 + 0.45 * sin(t * 2.4))
        }
    }
}

/// Draws the closed pod: two leaves pressed together with their teeth interlocked.
struct PodRenderer {
    enum Mood { case sleeping, waiting, chewing }

    /// Seconds since the cover appeared.
    let t: Double
    let mood: Mood
    let stage: Stage

    func draw(in ctx: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.47)
        let halfWidth = min(size.width * 0.32, 110.0)
        let halfHeight = min(size.height * 0.32, 110.0)

        // The slam: a damped spring. Above 1 the halves are pressed into each other, so squash instead.
        let spring = 1 - exp(-7 * t) * cos(13 * t)
        let together = min(spring, 1)
        let squash = max(spring - 1, 0)
        let spread = (1 - together) * size.width * 0.6
        let tilt = (1 - together) * 32

        // Breathing or chewing once settled.
        let settled = Ease.outCubic((t - 0.5) / 0.4)
        var chewX = 1.0, chewY = 1.0, grind = 0.0
        switch mood {
        case .chewing:
            chewY = 1 + 0.045 * sin(t * 9) * settled
            chewX = 1 - 0.025 * sin(t * 9) * settled
            grind = 4 * sin(t * 9) * settled
        case .sleeping:
            chewY = 1 + 0.018 * sin(t * 1.6) * settled
        case .waiting:
            chewY = 1 + 0.012 * sin(t * 3) * settled
        }

        drawPot(&ctx, size: size, podBottom: center.y + halfHeight)

        var pod = ctx
        pod.translateBy(x: center.x, y: center.y + halfHeight)
        pod.scaleBy(x: (1 - 0.6 * squash) * chewX, y: (1 + 0.5 * squash) * chewY)
        pod.translateBy(x: -center.x, y: -(center.y + halfHeight))

        // Each half swings in like a jaw, hinged at its bottom.
        func halfContext(left: Bool) -> GraphicsContext {
            var half = pod
            let sign: CGFloat = left ? -1 : 1
            half.translateBy(x: sign * spread, y: left ? grind : -grind)
            half.translateBy(x: center.x, y: center.y + halfHeight)
            half.rotate(by: .degrees(left ? -tilt : tilt))
            half.translateBy(x: -center.x, y: -(center.y + halfHeight))
            return half
        }
        // Both leaves first, then both rows of teeth, so the teeth interlock on top.
        for left in [true, false] {
            var half = halfContext(left: left)
            drawHalf(&half, left: left, center: center, halfWidth: halfWidth, halfHeight: halfHeight)
        }
        for left in [true, false] {
            var half = halfContext(left: left)
            drawTeeth(&half, left: left, center: center, halfHeight: halfHeight)
        }

        drawFace(&pod, center: center, halfWidth: halfWidth, halfHeight: halfHeight, visible: together)
        drawBubbles(&ctx, center: center, top: center.y - halfHeight)
    }

    private func drawHalf(_ ctx: inout GraphicsContext, left: Bool, center c: CGPoint, halfWidth hw: CGFloat, halfHeight hh: CGFloat) {
        let s: CGFloat = left ? -1 : 1
        var body = Path()
        body.move(to: CGPoint(x: c.x, y: c.y - hh))
        body.addCurve(to: CGPoint(x: c.x + s * hw, y: c.y),
                      control1: CGPoint(x: c.x + s * hw * 0.6, y: c.y - hh),
                      control2: CGPoint(x: c.x + s * hw, y: c.y - hh * 0.55))
        body.addCurve(to: CGPoint(x: c.x, y: c.y + hh),
                      control1: CGPoint(x: c.x + s * hw, y: c.y + hh * 0.55),
                      control2: CGPoint(x: c.x + s * hw * 0.6, y: c.y + hh))
        body.closeSubpath()

        ctx.fill(body, with: .linearGradient(Gradient(stops: [
            .init(color: Theme.rim, location: 0),
            .init(color: Theme.leaf, location: 0.3),
            .init(color: Theme.leaf, location: 0.72),
            .init(color: Theme.blush, location: 1),
        ]), startPoint: CGPoint(x: c.x + s * hw, y: c.y), endPoint: c))
        ctx.stroke(body, with: .color(Theme.rim), lineWidth: 3)
    }

    private func drawTeeth(_ ctx: inout GraphicsContext, left: Bool, center c: CGPoint, halfHeight hh: CGFloat) {
        let s: CGFloat = left ? -1 : 1
        // Teeth poke across the seam. Each half takes every other slot, so they interlock.
        let slots = stage.toothCount
        let toothLength: CGFloat = 20
        for k in 0..<slots where (k % 2 == 0) == left {
            let y = c.y - hh * 0.82 + CGFloat(k) * (hh * 1.64 / CGFloat(slots - 1))
            let edge = seamInset(y: y, center: c, halfHeight: hh)
            var tooth = Path()
            tooth.move(to: CGPoint(x: c.x, y: y - 6))
            tooth.addQuadCurve(to: CGPoint(x: c.x - s * (toothLength - edge), y: y),
                               control: CGPoint(x: c.x - s * toothLength * 0.5, y: y - 4))
            tooth.addQuadCurve(to: CGPoint(x: c.x, y: y + 6),
                               control: CGPoint(x: c.x - s * toothLength * 0.5, y: y + 4))
            tooth.closeSubpath()
            ctx.fill(tooth, with: .color(Theme.tooth))
        }
    }

    /// Shorter teeth near the tips of the pod.
    private func seamInset(y: CGFloat, center c: CGPoint, halfHeight hh: CGFloat) -> CGFloat {
        let k = abs(y - c.y) / hh
        return 10 * k * k
    }

    private func drawFace(_ ctx: inout GraphicsContext, center c: CGPoint, halfWidth hw: CGFloat, halfHeight hh: CGFloat, visible: Double) {
        guard visible > 0.95 else { return }
        let eyeY = c.y - hh * 0.38
        // Blink every few seconds while waiting.
        let blink = mood == .waiting && t.truncatingRemainder(dividingBy: 3.2) > 3.05
        for s in [-1.0, 1.0] {
            let eye = CGPoint(x: c.x + s * hw * 0.42, y: eyeY)
            switch mood {
            case .waiting where !blink:
                ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 12, y: eye.y - 14, width: 24, height: 28)), with: .color(.white))
                let look = CGFloat(sin(t * 0.9)) * 5
                ctx.fill(Path(ellipseIn: CGRect(x: eye.x - 6 + look, y: eye.y - 4, width: 12, height: 14)), with: .color(.black))
            case .chewing:
                // Happy ^ ^ eyes.
                var arc = Path()
                arc.move(to: CGPoint(x: eye.x - 11, y: eye.y + 5))
                arc.addQuadCurve(to: CGPoint(x: eye.x + 11, y: eye.y + 5), control: CGPoint(x: eye.x, y: eye.y - 12))
                ctx.stroke(arc, with: .color(.black.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            default:
                // Sleepy closed lids.
                var arc = Path()
                arc.move(to: CGPoint(x: eye.x - 11, y: eye.y))
                arc.addQuadCurve(to: CGPoint(x: eye.x + 11, y: eye.y), control: CGPoint(x: eye.x, y: eye.y + 10))
                ctx.stroke(arc, with: .color(.black.opacity(0.8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }
        // Rosy cheeks.
        for s in [-1.0, 1.0] {
            let cheek = CGRect(x: c.x + s * hw * 0.55 - 12, y: eyeY + 22, width: 24, height: 12)
            ctx.fill(Path(ellipseIn: cheek), with: .color(Theme.blush.opacity(0.55)))
        }
    }

    private func drawPot(_ ctx: inout GraphicsContext, size: CGSize, podBottom: CGFloat) {
        let potTop = size.height * 0.88
        var stem = Path()
        stem.move(to: CGPoint(x: size.width / 2, y: podBottom - 10))
        stem.addQuadCurve(to: CGPoint(x: size.width / 2, y: potTop),
                          control: CGPoint(x: size.width / 2 + 14 * sin(t * 1.2), y: (podBottom + potTop) / 2))
        ctx.stroke(stem, with: .color(Theme.rim), style: StrokeStyle(lineWidth: 8, lineCap: .round))

        let potWidth: CGFloat = 120
        var pot = Path()
        pot.move(to: CGPoint(x: size.width / 2 - potWidth / 2, y: potTop))
        pot.addLine(to: CGPoint(x: size.width / 2 + potWidth / 2, y: potTop))
        pot.addLine(to: CGPoint(x: size.width / 2 + potWidth * 0.38, y: size.height))
        pot.addLine(to: CGPoint(x: size.width / 2 - potWidth * 0.38, y: size.height))
        pot.closeSubpath()
        ctx.fill(pot, with: .color(Color(red: 0.72, green: 0.38, blue: 0.24)))
        ctx.fill(Path(roundedRect: CGRect(x: size.width / 2 - potWidth / 2 - 6, y: potTop - 4, width: potWidth + 12, height: 14), cornerRadius: 4),
                 with: .color(Color(red: 0.82, green: 0.46, blue: 0.30)))
    }

    /// Burps while chewing, z's while asleep.
    private func drawBubbles(_ ctx: inout GraphicsContext, center c: CGPoint, top: CGFloat) {
        guard t > 0.8, mood != .waiting else { return }
        for i in 0..<3 {
            let period = 2.4
            let phase = (t + Double(i) * period / 3).truncatingRemainder(dividingBy: period) / period
            let x = c.x + 40 + CGFloat(i) * 12 + CGFloat(sin(phase * 6 + Double(i))) * 8
            let y = top - CGFloat(phase) * 55
            let alpha = phase < 0.8 ? 1 : (1 - phase) / 0.2
            let text = mood == .chewing ? (i == 0 ? "burp!" : "•") : "z"
            let fontSize = mood == .chewing ? 14 + CGFloat(i) * 2 : 16 + CGFloat(i) * 6
            ctx.opacity = alpha
            ctx.draw(Text(text).font(.system(size: fontSize, weight: .heavy, design: .rounded)).foregroundStyle(.white),
                     at: CGPoint(x: x, y: y))
        }
        ctx.opacity = 1
    }
}

#Preview("Asleep") {
    CoverView(game: GameModel())
}
