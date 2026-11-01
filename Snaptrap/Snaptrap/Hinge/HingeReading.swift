import SwiftUI

/// One reading of the fold, from the real hinge or from the virtual one.
///
/// 180° is flat open, 0° is shut. The trap only cares about two things:
/// how far it has folded toward a snap (`closure`), and whether it is shut,
/// which moves the app to the cover display.
struct HingeReading: Equatable {
    var degrees: Double
    var isClosed: Bool
    var isVirtual: Bool

    /// 0 when flat, 1 once folded to the snap angle or tighter.
    var closure: Double {
        ((180 - degrees) / (180 - SnapDetector.snapAngle)).clamped(to: 0...1)
    }

    /// Ready to snap: open wide enough that folding counts as a bite.
    var isArmedPosture: Bool { degrees >= SnapDetector.armAngle && !isClosed }
}

extension DeviceHinge {
    /// The real hinge, as a reading.
    var reading: HingeReading {
        HingeReading(degrees: angle.degrees, isClosed: status == .closed, isVirtual: false)
    }
}
