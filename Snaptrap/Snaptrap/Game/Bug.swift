import SwiftUI

enum BugKind: CaseIterable {
    case fly, butterfly, goldfly, bee

    var emoji: String {
        switch self {
        case .fly, .goldfly: "🪰"
        case .butterfly: "🦋"
        case .bee: "🐝"
        }
    }

    var points: Int {
        switch self {
        case .fly: 10
        case .butterfly: 25
        case .goldfly: 50
        case .bee: 0
        }
    }

    var size: CGFloat {
        switch self {
        case .fly: 30
        case .butterfly: 38
        case .goldfly: 32
        case .bee: 34
        }
    }

    var speed: CGFloat {
        switch self {
        case .fly: 170
        case .butterfly: 95
        case .goldfly: 240
        case .bee: 125
        }
    }

    /// How long it sits on a leaf, in seconds. Golden flies don't sit around.
    var restDuration: ClosedRange<Double> {
        switch self {
        case .fly: 1.3...2.3
        case .butterfly: 1.8...2.8
        case .goldfly: 0.75...1.1
        case .bee: 1.6...2.6
        }
    }
}

enum BugState: Equatable {
    case flying
    case landed
    case caught(from: CGPoint)
    case escaping
}

struct Bug: Identifiable {
    let id: Int
    let kind: BugKind
    var position: CGPoint
    var velocity = CGVector(dx: 0, dy: 0)
    var target: CGPoint
    var wantsToLand = false
    var state = BugState.flying
    /// When the bug entered its current state, in game time.
    var stateTime: Double
    /// When it next changes its mind (lands, takes off, …).
    var nextDecision: Double
    var landingsLeft: Int
    let seed = Double.random(in: 0...1000)

    var isCatchable: Bool { state == .landed && kind != .bee }
}

/// A "+30" or "Ouch!" that pops up and drifts away.
struct FloatingText: Identifiable {
    let id: Int
    let text: String
    let position: CGPoint
    let color: Color
    let birth: Double
    var size: CGFloat = 28
    static let life = 1.15
}

/// Pollen, crumbs and sparkles.
struct Particle {
    var position: CGPoint
    var velocity: CGVector
    let color: Color
    let radius: CGFloat
    let birth: Double
    let life: Double
    var drag: CGFloat = 1.6
}
