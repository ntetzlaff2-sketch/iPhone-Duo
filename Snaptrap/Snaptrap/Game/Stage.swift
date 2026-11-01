import SwiftUI

/// The trap grows up as it eats. Saved across launches.
enum Stage: Int, CaseIterable {
    case sprout, nibbler, snapper, chomper, legend

    static let thresholds = [0, 15, 40, 90, 180]

    init(eaten: Int) {
        let index = Self.thresholds.lastIndex { eaten >= $0 } ?? 0
        self = Stage(rawValue: index) ?? .sprout
    }

    var name: String {
        switch self {
        case .sprout: "Sprout"
        case .nibbler: "Nibbler"
        case .snapper: "Snapper"
        case .chomper: "Chomper"
        case .legend: "Swamp Legend"
        }
    }

    var emoji: String {
        switch self {
        case .sprout: "🌱"
        case .nibbler: "🌿"
        case .snapper: "🪴"
        case .chomper: "🦖"
        case .legend: "👑"
        }
    }

    /// Bigger traps grow more teeth.
    var toothCount: Int { 13 + rawValue * 2 }

    /// Bugs needed for the next stage, or `nil` at the top.
    var nextThreshold: Int? {
        rawValue + 1 < Self.thresholds.count ? Self.thresholds[rawValue + 1] : nil
    }

    /// 0...1 through the current stage.
    func progress(eaten: Int) -> Double {
        guard let next = nextThreshold else { return 1 }
        let start = Self.thresholds[rawValue]
        return (Double(eaten - start) / Double(next - start)).clamped(to: 0...1)
    }
}
