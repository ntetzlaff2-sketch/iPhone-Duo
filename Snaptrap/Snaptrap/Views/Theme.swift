import SwiftUI

/// The swampy palette shared by the open trap and the cover screen.
enum Theme {
    static let bgInner = Color(red: 0.09, green: 0.20, blue: 0.13)
    static let bgOuter = Color(red: 0.02, green: 0.06, blue: 0.04)

    static let rim = Color(red: 0.20, green: 0.42, blue: 0.13)
    static let leaf = Color(red: 0.45, green: 0.74, blue: 0.24)
    static let blush = Color(red: 0.86, green: 0.30, blue: 0.24)
    static let crimson = Color(red: 0.62, green: 0.06, blue: 0.16)
    static let tooth = Color(red: 0.83, green: 0.92, blue: 0.55)
    static let toothTip = Color(red: 0.98, green: 1.0, blue: 0.85)
    static let pollen = Color(red: 1.0, green: 0.90, blue: 0.45)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.20)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.30)
    static let catchable = Color(red: 0.70, green: 1.0, blue: 0.55)

    static func background(center: CGPoint, radius: CGFloat) -> GraphicsContext.Shading {
        .radialGradient(Gradient(colors: [bgInner, bgOuter]), center: center, startRadius: 0, endRadius: radius)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Easing curves used by the fold animations. All take and return 0...1 (back can overshoot).
enum Ease {
    static func outCubic(_ t: Double) -> Double {
        let t = t.clamped(to: 0...1)
        return 1 - pow(1 - t, 3)
    }

    static func inCubic(_ t: Double) -> Double {
        let t = t.clamped(to: 0...1)
        return t * t * t
    }

    static func inOut(_ t: Double) -> Double {
        let t = t.clamped(to: 0...1)
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Overshoots a little past 1 before settling, like a leaf springing open.
    static func outBack(_ t: Double, overshoot: Double = 1.9) -> Double {
        let t = t.clamped(to: 0...1)
        let c3 = overshoot + 1
        return 1 + c3 * pow(t - 1, 3) + overshoot * pow(t - 1, 2)
    }
}

extension CGPoint {
    static func + (a: CGPoint, b: CGVector) -> CGPoint { CGPoint(x: a.x + b.dx, y: a.y + b.dy) }
    static func - (a: CGPoint, b: CGPoint) -> CGVector { CGVector(dx: a.x - b.x, dy: a.y - b.y) }

    func lerp(to other: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }
}

extension CGVector {
    static func * (v: CGVector, s: CGFloat) -> CGVector { CGVector(dx: v.dx * s, dy: v.dy * s) }
    static func + (a: CGVector, b: CGVector) -> CGVector { CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy) }

    var length: CGFloat { (dx * dx + dy * dy).squareRoot() }

    var normalized: CGVector {
        let l = length
        return l > 0.0001 ? CGVector(dx: dx / l, dy: dy / l) : CGVector(dx: 0, dy: 0)
    }

    /// Rotated a quarter turn.
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }
}
