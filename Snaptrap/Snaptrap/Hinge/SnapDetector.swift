/// Turns a stream of hinge angles into bites.
///
/// A bite is folding from wide open (past `armAngle`) down to `snapAngle` or
/// all the way shut. After a bite the trap has to open wide again before it
/// can bite again, just like a real flytrap needs to reopen.
struct SnapDetector {
    /// Open at least this far to get the trap ready.
    static let armAngle = 145.0
    /// Fold to this angle or tighter to snap.
    static let snapAngle = 105.0

    private(set) var isArmed = false

    /// Feeds the next reading. Returns `true` when it completes a bite.
    mutating func update(_ reading: HingeReading) -> Bool {
        if reading.isArmedPosture {
            isArmed = true
            return false
        }
        if isArmed && (reading.degrees <= Self.snapAngle || reading.isClosed) {
            isArmed = false
            return true
        }
        return false
    }
}
