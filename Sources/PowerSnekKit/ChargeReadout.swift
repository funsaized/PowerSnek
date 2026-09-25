import Foundation

/// The battery state read once, at the moment of the celebration.
public struct ChargeSnapshot: Equatable, Sendable {
    public let percent: Int
    public let isCharging: Bool
    public let isFullyCharged: Bool
    /// nil while macOS is still estimating (typical right after plug-in).
    public let minutesToFull: Int?

    public init(percent: Int, isCharging: Bool, isFullyCharged: Bool, minutesToFull: Int?) {
        self.percent = percent
        self.isCharging = isCharging
        self.isFullyCharged = isFullyCharged
        self.minutesToFull = minutesToFull
    }

    /// Builds a snapshot from raw IOKit power-source values.
    public init?(currentCapacity: Int?, maxCapacity: Int?, isCharging: Bool?,
                 isCharged: Bool?, timeToFullMinutes: Int?) {
        guard let current = currentCapacity, let full = maxCapacity, full > 0 else { return nil }
        let percent = Int((Double(current) / Double(full) * 100).rounded())
        self.init(percent: min(100, max(0, percent)),
                  isCharging: isCharging ?? false,
                  isFullyCharged: isCharged ?? false,
                  minutesToFull: timeToFullMinutes.flatMap { $0 > 0 ? $0 : nil })
    }
}

/// The short status shown under the notch after the comet lands.
public enum ChargeReadout {
    public static let fadeIn = 0.25
    public static let hold = 1.3
    public static let fadeOut = 0.45
    public static var duration: Double { fadeIn + hold + fadeOut }
    /// Seconds after the comet lands before the readout appears.
    public static let delayAfterLanding = 0.12

    public static func text(for s: ChargeSnapshot) -> String {
        if s.isFullyCharged || s.percent >= 100 { return "Fully charged" }
        if s.isCharging, let minutes = s.minutesToFull {
            return "\(s.percent)% · full in \(format(minutes: minutes))"
        }
        // Plugged in but not charging: optimized charging or a charge limit.
        if !s.isCharging { return "\(s.percent)% · On power" }
        return "\(s.percent)% · Charging"
    }

    /// "45m", "1h", "2h 5m".
    public static func format(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    public static func opacity(at t: Double) -> Double {
        Envelope.trapezoid(t, fadeIn: fadeIn, hold: hold, fadeOut: fadeOut)
    }
}
