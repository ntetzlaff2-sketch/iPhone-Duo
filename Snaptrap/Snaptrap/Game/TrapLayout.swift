import SwiftUI

/// Where the two lobes of the trap sit, in "trap space".
///
/// Trap space always has the fold running top to bottom: `width` goes across
/// the fold and `height` runs along it. When the fold runs sideways on screen
/// (the device held like a laptop), the renderer rotates trap space a quarter
/// turn, so the game logic never has to care.
struct TrapLayout: Equatable {
    var size: CGSize
    /// The middle of the fold, measured across it.
    var foldX: CGFloat
    /// Half the width of the physical fold region. Nothing lands in it.
    var foldGap: CGFloat
    /// The fold runs horizontally on screen.
    var isRotated: Bool
    /// The size of the screen, before rotation.
    var screenSize: CGSize

    static let zero = TrapLayout(screenSize: .zero, fold: nil)

    init(screenSize: CGSize, fold: CGRect?) {
        self.screenSize = screenSize
        if let fold, fold.width > fold.height {
            isRotated = true
            size = CGSize(width: screenSize.height, height: screenSize.width)
            foldX = fold.midY
            foldGap = fold.height / 2
        } else {
            isRotated = false
            size = screenSize
            foldX = fold?.midX ?? screenSize.width / 2
            foldGap = (fold?.width ?? 0) / 2
        }
    }

    var isEmpty: Bool { size.width < 1 || size.height < 1 }

    var leftLobe: CGRect {
        CGRect(x: 0, y: 0, width: max(foldX - foldGap, 0), height: size.height)
    }

    var rightLobe: CGRect {
        CGRect(x: foldX + foldGap, y: 0, width: max(size.width - foldX - foldGap, 0), height: size.height)
    }

    /// The point on the fold level with `point`. Caught bugs get pulled here.
    func foldPoint(near point: CGPoint) -> CGPoint {
        CGPoint(x: foldX, y: point.y)
    }

    /// A random spot on one of the leaves, away from the fold and the rim.
    func randomLandingSpot() -> CGPoint {
        for _ in 0..<24 {
            let left = Bool.random()
            let lobe = left ? leftLobe : rightLobe
            guard lobe.width > 60 else { continue }
            let across = CGFloat.random(in: 0.18...0.78) // 0 at the fold, 1 at the rim
            let along = CGFloat.random(in: -0.62...0.62) // 0 in the middle of the fold
            // Keep inside the oval of the leaf.
            guard across * across + along * along < 0.62 else { continue }
            let x = left ? lobe.maxX - across * lobe.width : lobe.minX + across * lobe.width
            let y = lobe.midY + along * lobe.height / 2
            return CGPoint(x: x, y: y)
        }
        return CGPoint(x: leftLobe.midX, y: size.height / 2)
    }

    /// A random point just off screen, where bugs come from and go to.
    func randomOffscreenPoint() -> CGPoint {
        let margin: CGFloat = 50
        switch Int.random(in: 0..<4) {
        case 0: return CGPoint(x: .random(in: 0...size.width), y: -margin)
        case 1: return CGPoint(x: .random(in: 0...size.width), y: size.height + margin)
        case 2: return CGPoint(x: -margin, y: .random(in: 0...size.height))
        default: return CGPoint(x: size.width + margin, y: .random(in: 0...size.height))
        }
    }

    /// A random point to buzz toward while flying around.
    func randomWanderPoint() -> CGPoint {
        CGPoint(x: .random(in: size.width * 0.08...size.width * 0.92),
                y: .random(in: size.height * 0.1...size.height * 0.9))
    }

    func isFarOffscreen(_ p: CGPoint) -> Bool {
        p.x < -120 || p.y < -120 || p.x > size.width + 120 || p.y > size.height + 120
    }
}
