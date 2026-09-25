import Foundation

public enum Envelope {
    /// 0 → 1 over `fadeIn` (ease-out), holds at 1 for `hold`, then 1 → 0
    /// over `fadeOut` (ease-in). 0 outside that span.
    public static func trapezoid(_ t: Double, fadeIn: Double, hold: Double, fadeOut: Double) -> Double {
        guard t > 0 else { return 0 }
        if t < fadeIn { return CometMath.easeOutQuad(t / max(fadeIn, 1e-6)) }
        if t <= fadeIn + hold { return 1 }
        let u = (t - fadeIn - hold) / max(fadeOut, 1e-6)
        guard u < 1 else { return 0 }
        return 1 - u * u
    }
}

/// The Reduce Motion variant of the celebration: no travel or pulsing, just
/// the whole outline (and notch rim) glowing in and out once.
public enum ReducedMotionGlow {
    public static let fadeIn = 0.3
    public static let hold = 0.6
    public static let fadeOut = 0.7
    public static var duration: Double { fadeIn + hold + fadeOut }

    public static func opacity(at t: Double) -> Double {
        Envelope.trapezoid(t, fadeIn: fadeIn, hold: hold, fadeOut: fadeOut)
    }
}
