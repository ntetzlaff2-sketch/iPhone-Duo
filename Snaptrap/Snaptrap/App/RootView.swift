import SwiftUI

/// Wires the hinge to the game and swaps between the open trap and the cover display.
///
/// - Folding past the snap angle is a bite (`SnapDetector`).
/// - Closing all the way shows `CoverView`: the leaves slam into a pod and chew.
/// - Opening again plays the bloom: the leaves unfurl out of the fold, teeth popping out in a ripple.
struct RootView: View {
    @State private var game = GameModel()
    @State private var virtualHinge = VirtualHinge()
    @State private var deviceReading: HingeReading?
    @State private var detector = SnapDetector()

    /// The real hinge when there is one, the virtual one otherwise.
    private var reading: HingeReading { deviceReading ?? virtualHinge.reading }

    /// Without a real hinge, the cover gets an Unfold button.
    private var virtualOpen: (() -> Void)? {
        guard deviceReading == nil else { return nil }
        let hinge = virtualHinge
        return { hinge.open() }
    }

    var body: some View {
        ZStack {
            if reading.isClosed {
                CoverView(game: game, onOpen: virtualOpen)
                    .transition(.opacity)
            } else {
                TrapView(
                    game: game,
                    reading: reading,
                    isArmed: detector.isArmed,
                    virtualHinge: deviceReading == nil ? virtualHinge : nil
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reading.isClosed)
        // 👇 The API: the hinge is the trap's jaw.
        .onHingeChange { _, newContext in
            deviceReading = newContext.hinge?.reading
        }
        .onChange(of: reading, initial: true) { oldReading, newReading in
            hingeMoved(from: oldReading, to: newReading)
        }
        .task {
            // The game loop. Game time keeps ticking even while paused, for the animations.
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = clock.now
                game.tick(min((now - last) / .seconds(1), 0.05))
                last = now
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: game.snapCount)
        .sensoryFeedback(.success, trigger: game.catchCount)
        .sensoryFeedback(.error, trigger: game.stingCount)
    }

    private func hingeMoved(from old: HingeReading, to new: HingeReading) {
        game.closure = new.closure
        if detector.update(new) {
            game.snap()
        }
        if old.isClosed != new.isClosed {
            if new.isClosed {
                game.didClose()
            } else {
                game.didOpen()
            }
        }
    }
}

#Preview {
    RootView()
}
