import CoreGraphics

/// A tuned celebration style. The color, laps, and speed are presets the
/// user can override in Advanced settings; the remaining visual tuning is
/// fixed per style so every style stays good-looking.
public struct CelebrationProfile: Identifiable, Equatable, Sendable {
    /// How the comet lands.
    public enum Finale: String, Sendable {
        /// Flash, notch-rim glow, breathing pulse, glint (the original).
        case burst
        /// A gentler, longer glow with a dimmer flash.
        case soft
        /// Only the notch rim lights up and fades.
        case minimal
        /// `burst`, plus a forked tongue flicking out of the notch.
        case snek

        public var flashGain: CGFloat {
            switch self {
            case .burst, .snek: return 1
            case .soft: return 0.45
            case .minimal: return 0
            }
        }

        public var breathGain: CGFloat {
            switch self {
            case .burst, .snek: return 1
            case .soft: return 1.15
            case .minimal: return 0
            }
        }

        public var glintGain: CGFloat {
            switch self {
            case .burst, .snek: return 1
            case .soft: return 0.5
            case .minimal: return 0
            }
        }

        public var showsTongue: Bool { self == .snek }
    }

    public let id: String
    public let name: String
    public let tagline: String
    public let colorHex: String
    public let laps: Int
    /// Seconds for the calibration sweep (see `CometMath.travelDuration`).
    public let lapDuration: Double
    /// Multiplies trail and head stroke widths.
    public let strokeScale: CGFloat
    /// Multiplies halo opacity and blur radii.
    public let glowScale: CGFloat
    /// Longest visible trail, as a fraction of the perimeter.
    public let trailFraction: Double
    /// Hue drift from the head to the tail tip (0 = one color).
    public let tailHueShift: CGFloat
    public let finale: Finale
    public let finaleDuration: Double

    public static let electric = CelebrationProfile(
        id: "electric", name: "Electric", tagline: "The original two-lap jolt.",
        colorHex: "#34FF6A", laps: 2, lapDuration: 3.1,
        strokeScale: 1, glowScale: 1, trailFraction: CometMath.trailMaxFraction,
        tailHueShift: 0, finale: .burst, finaleDuration: CometMath.finaleDuration)

    public static let aurora = CelebrationProfile(
        id: "aurora", name: "Aurora", tagline: "One slow, glowing lap.",
        colorHex: "#3CE6D2", laps: 1, lapDuration: 5.0,
        strokeScale: 0.8, glowScale: 1.5, trailFraction: 0.26,
        tailHueShift: 0.14, finale: .soft, finaleDuration: 1.4)

    public static let hyperbolt = CelebrationProfile(
        id: "hyperbolt", name: "Hyperbolt", tagline: "One fast lap, sharp impact.",
        colorHex: "#F5FF3B", laps: 1, lapDuration: 2.0,
        strokeScale: 0.85, glowScale: 0.9, trailFraction: 0.1,
        tailHueShift: -0.05, finale: .burst, finaleDuration: 0.6)

    public static let minimal = CelebrationProfile(
        id: "minimal", name: "Minimal", tagline: "A thin, quiet trace.",
        colorHex: "#E8ECFF", laps: 1, lapDuration: 3.6,
        strokeScale: 0.45, glowScale: 0.35, trailFraction: 0.12,
        tailHueShift: 0, finale: .minimal, finaleDuration: 0.6)

    public static let snek = CelebrationProfile(
        id: "snek", name: "Snek", tagline: "Two laps, then a tongue flick.",
        colorHex: "#C3FB1C", laps: 2, lapDuration: 3.4,
        strokeScale: 1.05, glowScale: 1, trailFraction: 0.18,
        tailHueShift: -0.04, finale: .snek, finaleDuration: 1.3)

    public static let all: [CelebrationProfile] = [electric, snek, aurora, hyperbolt, minimal]
    public static let defaultID = electric.id

    /// The style with `id`, or the default style for unknown IDs.
    public static func named(_ id: String) -> CelebrationProfile {
        all.first { $0.id == id } ?? electric
    }

    /// Landing fraction of a typical notched MacBook outline (bottom-left
    /// start, clockwise: left edge plus half the top of a ~1512x982 screen).
    public static let nominalLandingFraction = 0.35

    /// Travel plus finale, in seconds, for the given (possibly customized)
    /// laps and speed.
    public func totalDuration(laps: Int, lapDuration: Double,
                              landingFraction: Double = nominalLandingFraction) -> Double {
        CometMath.travelDuration(lapDuration: lapDuration, laps: laps, landingFraction: landingFraction)
            + finaleDuration
    }

    /// Whether the user-adjustable values still equal this style's presets.
    public func matches(colorHex: String, laps: Int, lapDuration: Double) -> Bool {
        colorHex.uppercased() == self.colorHex.uppercased()
            && laps == self.laps
            && abs(lapDuration - self.lapDuration) < 0.01
    }
}
