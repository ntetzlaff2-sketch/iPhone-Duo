import SwiftUI

/// Score, hearts, the round clock and the title/results cards.
///
/// Everything is laid out as two pages, one per leaf, so nothing sits on the fold.
struct TrapHUD: View {
    let game: GameModel
    let layout: TrapLayout
    let reading: HingeReading
    let isArmed: Bool

    var body: some View {
        TwoPages(layout: layout) {
            VStack(alignment: .leading, spacing: 0) {
                if game.phase != .ready { scoreBlock }
                Spacer(minLength: 12)
                Group {
                    switch game.phase {
                    case .ready: titleCard
                    case .over: resultsCard
                    case .playing: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 12)
                stageBadge
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        } trailing: {
            VStack(alignment: .trailing, spacing: 0) {
                if game.phase == .playing { clockBlock }
                Spacer(minLength: 12)
                Group {
                    switch game.phase {
                    case .ready: howToCard
                    case .over: againCard
                    case .playing: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 12)
                if !reading.isVirtual {
                    HingeMeter(reading: reading, isArmed: isArmed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .foregroundStyle(.white)
        .fontDesign(.rounded)
        .allowsHitTesting(false)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: game.phase)
    }

    // MARK: Pieces

    private var scoreBlock: some View {
        Text(game.score, format: .number)
            .font(.system(size: 56, weight: .black))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(game.score)))
            .animation(.snappy, value: game.score)
            .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 2)
    }

    private var clockBlock: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<GameModel.maxHearts, id: \.self) { index in
                    Image(systemName: index < game.hearts ? "heart.fill" : "heart")
                        .foregroundStyle(index < game.hearts ? Theme.danger : .white.opacity(0.4))
                        .symbolEffect(.bounce, value: game.hearts)
                }
            }
            .font(.title2)

            let seconds = Int(game.timeLeft.rounded(.up))
            Label("\(seconds)", systemImage: "timer")
                .font(.title3.weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: seconds)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(seconds <= 10 ? Theme.danger.opacity(0.85) : .black.opacity(0.45), in: .capsule)
        }
    }

    private var stageBadge: some View {
        let stage = game.stage
        return HStack(spacing: 8) {
            Text(stage.emoji)
            VStack(alignment: .leading, spacing: 4) {
                Text(stage.name).font(.caption.weight(.heavy))
                ProgressView(value: stage.progress(eaten: game.lifetimeEaten))
                    .tint(Theme.catchable)
                    .frame(width: 90)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4), in: .capsule)
    }

    private var titleCard: some View {
        VStack(spacing: 10) {
            Text("Snaptrap")
                .font(.system(size: 54, weight: .black))
                .shadow(color: Theme.crimson, radius: 0, x: 3, y: 3)
            Text("A hungry flytrap\nfor iPhone Duo")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .card()
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("🪰", "Bugs land on the leaves. Watch the ring tick down.")
            row("🫳", "Snap the phone shut to eat them. Several at once is a combo.")
            row("🐝", "Never eat a bee. A golden fly buys you time.")
            row("📕", "Close all the way to pause and digest.")
            Text(reading.isVirtual ? "Press Snap! to start" : "Open wide, then snap to start")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.catchable)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .card()
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var resultsCard: some View {
        VStack(spacing: 8) {
            Text(game.isNewBest ? "New best!" : "Time's up")
                .font(.title.weight(.black))
                .foregroundStyle(game.isNewBest ? Theme.gold : .white)
            Text(game.score, format: .number)
                .font(.system(size: 64, weight: .black))
                .monospacedDigit()
            Text("Best \(game.best)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .card()
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var againCard: some View {
        VStack(spacing: 12) {
            Text("Eaten this round")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))
            Text(game.roundEaten.isEmpty ? "Nothing… 🥲" : summary(game.roundEaten))
                .font(.title2)
                .multilineTextAlignment(.center)
            Text(reading.isVirtual ? "Snap! to play again" : "Snap to play again")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.catchable)
        }
        .card()
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func row(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(emoji).font(.title3)
            Text(text).font(.subheadline.weight(.medium))
        }
    }

    private func summary(_ kinds: [BugKind]) -> String {
        BugKind.allCases.compactMap { kind in
            let count = kinds.filter { $0 == kind }.count
            guard count > 0 else { return nil }
            return "\(kind == .goldfly ? "✨" : "")\(kind.emoji)×\(count)"
        }
        .joined(separator: "  ")
    }
}

/// Shows how far the hinge is from a bite: open past the green mark, fold past the red one.
struct HingeMeter: View {
    let reading: HingeReading
    let isArmed: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isArmed ? Theme.catchable : .white.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(isArmed ? "Ready to bite" : "Open wider")
                    .font(.caption.weight(.heavy))
                Text(reading.degrees.formatted(.number.precision(.fractionLength(0))) + "°")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            GeometryReader { proxy in
                let w = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.crimson, Theme.leaf], startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * (reading.degrees / 180).clamped(to: 0...1))
                    mark(at: SnapDetector.snapAngle, color: Theme.danger, width: w)
                    mark(at: SnapDetector.armAngle, color: Theme.catchable, width: w)
                }
            }
            .frame(width: 160, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.4), in: .rect(cornerRadius: 14))
        .animation(.snappy, value: isArmed)
    }

    private func mark(at degrees: Double, color: Color, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 14)
            .offset(x: width * degrees / 180 - 1)
    }
}

/// Lays out two views, one on each side of the fold.
struct TwoPages<Leading: View, Trailing: View>: View {
    let layout: TrapLayout
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if layout.isRotated {
            VStack(spacing: 0) {
                leading.frame(maxWidth: .infinity).frame(height: layout.leftLobe.width)
                Color.clear.frame(height: layout.foldGap * 2)
                trailing.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 0) {
                leading.frame(maxHeight: .infinity).frame(width: layout.leftLobe.width)
                Color.clear.frame(width: layout.foldGap * 2)
                trailing.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private extension View {
    func card() -> some View {
        padding(20)
            .frame(maxWidth: 360)
            .background(.black.opacity(0.5), in: .rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Theme.catchable.opacity(0.35), lineWidth: 1.5)
            }
    }
}
