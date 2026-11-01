import SwiftUI

/// The whole game: bugs, score, the round clock and the trap's appetite.
///
/// Everything runs on game time (`time`), advanced by `tick(_:)` from the
/// root view's loop. The hinge only talks to the game through `snap()`,
/// `didClose()`, `didOpen()` and `closure`.
@Observable
final class GameModel {
    enum Phase { case ready, playing, over }

    static let roundLength = 60.0
    static let maxHearts = 3
    /// How long the open-up animation lasts.
    static let bloomDuration = 1.5

    // MARK: State

    private(set) var phase = Phase.ready
    private(set) var bugs: [Bug] = []
    private(set) var texts: [FloatingText] = []
    private(set) var particles: [Particle] = []

    private(set) var score = 0
    private(set) var hearts = GameModel.maxHearts
    private(set) var timeLeft = GameModel.roundLength
    private(set) var best: Int
    private(set) var isNewBest = false
    private(set) var lifetimeEaten: Int
    /// Eaten since the trap last opened. Shown digesting on the cover display.
    private(set) var belly: [BugKind] = []
    /// Eaten this round, for the results page.
    private(set) var roundEaten: [BugKind] = []

    /// Game time in seconds. Always ticks, even when paused, so animations keep going.
    private(set) var time = 0.0
    private(set) var snapTime = -10.0
    private(set) var bloomTime = 0.0
    private(set) var overTime = -10.0
    private(set) var isClosed = false

    // Haptic triggers.
    private(set) var snapCount = 0
    private(set) var catchCount = 0
    private(set) var stingCount = 0

    /// How far the hinge has folded toward a snap, 0...1. Bugs get nervous.
    var closure = 0.0

    var layout = TrapLayout.zero

    var stage: Stage { Stage(eaten: lifetimeEaten) }

    /// 0...1 through the opening animation.
    var bloom: Double { ((time - bloomTime) / Self.bloomDuration).clamped(to: 0...1) }

    /// 0...1 through the snap flash, or nil when it's over.
    var snapFlash: Double? {
        let t = (time - snapTime) / 0.38
        return t < 1 ? t : nil
    }

    private var nextID = 0
    private var nextSpawn = 0.8
    private var elapsed = 0.0
    private var needsBloomBurst = true
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        best = defaults.integer(forKey: "best")
        lifetimeEaten = defaults.integer(forKey: "lifetimeEaten")
    }

    // MARK: Hinge events

    /// The trap snapped shut. Eats what's sitting on the leaves.
    func snap() {
        snapTime = time
        snapCount += 1

        switch phase {
        case .ready:
            scatterAll()
            start()
            return
        case .over:
            guard time - overTime > 1.0 else { return }
            scatterAll()
            start()
            return
        case .playing:
            break
        }

        var caught: [Bug] = []
        var stung = false
        for index in bugs.indices {
            let bug = bugs[index]
            switch bug.state {
            case .landed where bug.kind == .bee:
                stung = true
                say("Ouch! 🐝", at: bug.position, color: Theme.danger, size: 30)
                escape(&bugs[index], panic: 1.8)
            case .landed:
                caught.append(bug)
                bugs[index].state = .caught(from: bug.position)
                bugs[index].stateTime = time
            case .flying:
                escape(&bugs[index], panic: 1.6)
            case .caught, .escaping:
                break
            }
        }

        if stung {
            hearts -= 1
            stingCount += 1
        }

        if caught.isEmpty {
            if !stung, let center = layoutCenter {
                say("Whiff!", at: center, color: .white.opacity(0.8), size: 24)
            }
        } else {
            eat(caught)
        }

        if hearts <= 0 { endRound() }
    }

    func didClose() {
        isClosed = true
    }

    func didOpen() {
        isClosed = false
        belly.removeAll()
        bloomTime = time
        needsBloomBurst = true
    }

    func start() {
        phase = .playing
        score = 0
        hearts = Self.maxHearts
        timeLeft = Self.roundLength
        elapsed = 0
        nextSpawn = time + 0.6
        isNewBest = false
        roundEaten.removeAll()
        say("Hunt!", at: layoutCenter ?? .zero, color: Theme.catchable, size: 40)
    }

    // MARK: Loop

    func tick(_ dt: Double) {
        time += dt
        guard !layout.isEmpty else { return }

        if needsBloomBurst {
            needsBloomBurst = false
            bloomBurst()
        }

        particles.removeAll { time - $0.birth > $0.life }
        for i in particles.indices where particles[i].birth <= time {
            let p = particles[i]
            particles[i].position = p.position + p.velocity * dt
            particles[i].velocity = p.velocity * max(0, 1 - p.drag * dt)
        }
        texts.removeAll { time - $0.birth > FloatingText.life }

        // Closed: the trap is on the cover display, so the swamp holds still.
        guard !isClosed else { return }

        if phase == .playing {
            elapsed += dt
            timeLeft -= dt
            if timeLeft <= 0 {
                timeLeft = 0
                endRound()
            }
        }

        spawnIfNeeded()
        moveBugs(dt)
    }

    // MARK: Private

    private var layoutCenter: CGPoint? {
        layout.isEmpty ? nil : CGPoint(x: layout.foldX, y: layout.size.height * 0.42)
    }

    private func eat(_ caught: [Bug]) {
        let multiplier = caught.count
        let points = caught.reduce(0) { $0 + $1.kind.points } * multiplier
        score += points
        catchCount += 1

        let kinds = caught.map(\.kind)
        belly.append(contentsOf: kinds)
        roundEaten.append(contentsOf: kinds)
        lifetimeEaten += caught.count
        defaults.set(lifetimeEaten, forKey: "lifetimeEaten")

        let average = CGPoint(
            x: caught.map(\.position.x).reduce(0, +) / CGFloat(caught.count),
            y: caught.map(\.position.y).reduce(0, +) / CGFloat(caught.count)
        )
        say("+\(points)", at: average, color: Theme.pollen, size: 34)
        if multiplier > 1 {
            say("×\(multiplier) COMBO!", at: average + CGVector(dx: 0, dy: -44), color: Theme.catchable, size: 26)
        }
        if caught.contains(where: { $0.kind == .goldfly }) {
            timeLeft += 5
            say("+5s ⏱", at: average + CGVector(dx: 0, dy: 40), color: Theme.gold, size: 24)
        }

        // Crunch: crumbs spray out of the fold where each bug went in.
        for bug in caught {
            let origin = layout.foldPoint(near: bug.position)
            for _ in 0..<14 {
                let angle = Double.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 80...320)
                particles.append(Particle(
                    position: origin,
                    velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                    color: [Theme.pollen, Theme.catchable, .white, Theme.blush].randomElement()!,
                    radius: .random(in: 1.5...4),
                    birth: time,
                    life: .random(in: 0.4...0.9),
                    drag: 3
                ))
            }
        }
    }

    private func endRound() {
        guard phase == .playing else { return }
        phase = .over
        overTime = time
        if score > best {
            best = score
            isNewBest = true
            defaults.set(best, forKey: "best")
        }
        scatterAll()
    }

    private func scatterAll() {
        for i in bugs.indices where bugs[i].state == .flying || bugs[i].state == .landed {
            escape(&bugs[i], panic: 1.5)
        }
    }

    private func escape(_ bug: inout Bug, panic: CGFloat) {
        bug.state = .escaping
        bug.stateTime = time
        // Flee away from the fold, the way it came.
        let away = CGVector(dx: bug.position.x < layout.foldX ? -1 : 1, dy: .random(in: -0.7...0.7)).normalized
        bug.target = bug.position + away * 2000
        bug.velocity = away * bug.kind.speed * panic
    }

    private func say(_ text: String, at position: CGPoint, color: Color, size: CGFloat = 28) {
        nextID += 1
        texts.append(FloatingText(id: nextID, text: text, position: position, color: color, birth: time, size: size))
    }

    private func bloomBurst() {
        // Pollen puffs out of the fold as the leaves unfurl.
        for _ in 0..<60 {
            let y = CGFloat.random(in: 0...layout.size.height)
            let dir: CGFloat = Bool.random() ? 1 : -1
            particles.append(Particle(
                position: CGPoint(x: layout.foldX, y: y),
                velocity: CGVector(dx: dir * .random(in: 60...420), dy: .random(in: -80...80)),
                color: [Theme.pollen, Theme.catchable, .white].randomElement()!,
                radius: .random(in: 1.5...3.5),
                birth: time + .random(in: 0...0.3),
                life: .random(in: 1.0...2.2),
                drag: 1.4
            ))
        }
        say("*yaaawn*", at: CGPoint(x: layout.foldX, y: layout.size.height * 0.2), color: .white.opacity(0.85), size: 22)
    }

    private func spawnIfNeeded() {
        let maxBugs = phase == .playing ? min(4 + Int(elapsed / 12), 8) : 3
        let active = bugs.filter { $0.state == .flying || $0.state == .landed }.count
        guard time >= nextSpawn, active < maxBugs, phase != .over else { return }

        let interval = phase == .playing ? max(0.55, 1.35 - elapsed * 0.012) : 2.0
        nextSpawn = time + interval * .random(in: 0.7...1.3)

        let kind: BugKind
        if phase == .ready {
            kind = .fly
        } else {
            let roll = Double.random(in: 0...1)
            let beeChance = 0.16 + elapsed * 0.003
            if roll < 0.05 { kind = .goldfly }
            else if roll < 0.17 { kind = .butterfly }
            else if roll < 0.17 + beeChance { kind = .bee }
            else { kind = .fly }
        }

        nextID += 1
        let start = layout.randomOffscreenPoint()
        bugs.append(Bug(
            id: nextID,
            kind: kind,
            position: start,
            target: layout.randomWanderPoint(),
            stateTime: time,
            nextDecision: time + .random(in: 0.6...1.6),
            landingsLeft: kind == .goldfly ? 1 : Int.random(in: 1...3)
        ))
    }

    private func moveBugs(_ dt: Double) {
        let foldX = layout.foldX
        for i in bugs.indices {
            var bug = bugs[i]
            switch bug.state {
            case .flying:
                if time >= bug.nextDecision && !bug.wantsToLand {
                    bug.wantsToLand = true
                    bug.target = layout.randomLandingSpot()
                }
                let toTarget = bug.target - bug.position
                let distance = toTarget.length
                if distance < 10 {
                    if bug.wantsToLand {
                        bug.state = .landed
                        bug.stateTime = time
                        bug.velocity = CGVector(dx: 0, dy: 0)
                        bug.position = bug.target
                        bug.nextDecision = time + .random(in: bug.kind.restDuration)
                    } else {
                        bug.target = layout.randomWanderPoint()
                    }
                } else {
                    // Slow down to land, wiggle sideways like a real fly.
                    let speed = bug.kind.speed * (bug.wantsToLand ? min(1, distance / 90 + 0.35) : 1)
                    let wiggle = toTarget.normalized.perpendicular * CGFloat(sin(time * 9 + bug.seed)) * 0.9
                    let desired = (toTarget.normalized + wiggle).normalized * speed
                    let steer = min(1, 4 * dt)
                    bug.velocity = bug.velocity + (desired + bug.velocity * -1) * steer
                    bug.position = bug.position + bug.velocity * dt
                }

            case .landed:
                if time >= bug.nextDecision {
                    bug.landingsLeft -= 1
                    bug.wantsToLand = false
                    bug.stateTime = time
                    if bug.landingsLeft <= 0 {
                        escape(&bug, panic: 1)
                    } else {
                        bug.state = .flying
                        bug.target = layout.randomWanderPoint()
                        bug.nextDecision = time + .random(in: 0.8...2.0)
                    }
                }

            case .caught(let from):
                let t = Ease.inCubic((time - bug.stateTime) / 0.45)
                bug.position = from.lerp(to: CGPoint(x: foldX, y: from.y), t)

            case .escaping:
                bug.position = bug.position + bug.velocity * dt
            }
            bugs[i] = bug
        }

        bugs.removeAll { bug in
            switch bug.state {
            case .caught: time - bug.stateTime > 0.6
            case .escaping: layout.isFarOffscreen(bug.position)
            default: false
            }
        }
    }
}
