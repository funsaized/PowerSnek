public enum PowerState: Equatable {
    case ac
    case battery
    case unknown

    /// Fire the celebration only on the unplugged -> plugged transition.
    public static func shouldFire(previous: PowerState, current: PowerState) -> Bool {
        previous == .battery && current == .ac
    }
}
