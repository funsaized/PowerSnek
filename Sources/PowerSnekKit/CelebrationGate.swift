import Foundation

/// Decides *when* a charger connection is celebrated. A plug-in that arrives
/// while nobody can see the screen (displays asleep, lid just opening, lock
/// screen, another user's session) is remembered briefly and played once the
/// user is back, instead of animating into the dark or over the lock screen.
public struct CelebrationGate: Sendable {
    /// How long a deferred celebration stays relevant. Plugging in with the
    /// lid closed and unlocking a few seconds later should still celebrate;
    /// unlocking an hour later should not.
    public static let deferWindow: TimeInterval = 30

    public enum Decision: Equatable, Sendable {
        case fireNow
        case deferred
    }

    public private(set) var pendingSince: Date?

    public init() {}

    public mutating func chargerConnected(at now: Date, presentable: Bool) -> Decision {
        if presentable {
            pendingSince = nil
            return .fireNow
        }
        pendingSince = now
        return .deferred
    }

    /// The user can see the screen again (wake, unlock, session switch).
    /// Returns true exactly once for a still-relevant deferred celebration.
    public mutating func becamePresentable(at now: Date, stillOnAC: Bool) -> Bool {
        guard let since = pendingSince else { return false }
        pendingSince = nil
        return stillOnAC && now.timeIntervalSince(since) <= Self.deferWindow
    }
}
