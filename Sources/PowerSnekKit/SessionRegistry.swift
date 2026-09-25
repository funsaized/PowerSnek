/// Active per-display animation sessions, keyed by a validated display ID.
/// One dictionary replaces the old parallel window list + "animating" set,
/// which could drift apart.
public struct SessionRegistry<Key: Hashable, Session> {
    public private(set) var sessions: [Key: Session] = [:]

    public init() {}

    public func isActive(_ key: Key) -> Bool { sessions[key] != nil }

    /// Registers a session; returns false (and keeps the existing one) when
    /// the key is already animating, which is the per-display debounce.
    @discardableResult
    public mutating func begin(_ key: Key, _ session: Session) -> Bool {
        guard sessions[key] == nil else { return false }
        sessions[key] = session
        return true
    }

    @discardableResult
    public mutating func end(_ key: Key) -> Session? {
        sessions.removeValue(forKey: key)
    }

    /// Keys whose sessions should be torn down because their display is
    /// gone or changed. `shouldRemove` sees each live session.
    public func keys(where shouldRemove: (Key, Session) -> Bool) -> [Key] {
        sessions.filter { shouldRemove($0.key, $0.value) }.map(\.key)
    }
}
