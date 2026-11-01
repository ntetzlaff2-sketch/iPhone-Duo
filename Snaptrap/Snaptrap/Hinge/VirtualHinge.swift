import SwiftUI

/// A stand-in hinge for devices without one (and for Xcode Previews).
///
/// It produces the same `HingeReading`s as the real hinge, so the game can't
/// tell the difference. `snap()` plays a quick fold-and-reopen.
@Observable
final class VirtualHinge {
    var degrees = 180.0
    private(set) var isClosed = false

    @ObservationIgnored private var animation: Task<Void, Never>?

    var reading: HingeReading {
        HingeReading(degrees: isClosed ? 0 : degrees, isClosed: isClosed, isVirtual: true)
    }

    /// Folds to well past the snap angle and springs back open.
    func snap() {
        animation?.cancel()
        isClosed = false
        animation = Task {
            await animate(from: 180, to: 72, duration: 0.11)
            try? await Task.sleep(for: .milliseconds(120))
            await animate(from: 72, to: 180, duration: 0.42)
        }
    }

    func close() {
        animation?.cancel()
        animation = Task {
            await animate(from: degrees, to: 60, duration: 0.25)
            guard !Task.isCancelled else { return }
            isClosed = true
        }
    }

    func open() {
        animation?.cancel()
        isClosed = false
        degrees = 30
        animation = Task {
            await animate(from: 30, to: 180, duration: 0.6)
        }
    }

    private func animate(from start: Double, to end: Double, duration: Double) async {
        let clock = ContinuousClock()
        let begin = clock.now
        while !Task.isCancelled {
            let t = min((clock.now - begin) / .seconds(duration), 1)
            degrees = start + (end - start) * Ease.inOut(t)
            if t >= 1 { return }
            try? await Task.sleep(for: .milliseconds(8))
        }
    }
}
