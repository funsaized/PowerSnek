import CoreGraphics
import Foundation

/// Pure math for the Comet 2.0 animation, ported from the reference
/// implementation (see docs/superpowers/specs/2026-07-05-comet-animation-2.0-design.md).
/// Width-like constants are in reference units calibrated to a 1600-wide
/// screen; multiply by `scale(forScreenWidth:)` before rendering.
public enum CometMath {

    public static let referenceScreenWidth: CGFloat = 1600
    public static let referenceNotchSize = CGSize(width: 173, height: 34)

    public static let trailSegmentCount = 24
    public static let trailMaxFraction: Double = 0.15
    public static let collapseFraction: Double = 0.3
    public static let finaleDuration: Double = 0.9
    /// Lap count the speed slider is calibrated against ("2 laps take
    /// `lapDuration` seconds").
    public static let calibrationLaps: Double = 2

    public static let trailBaseWidth: CGFloat = 20
    public static let trailTaperWidth: CGFloat = 17.5
    public static let trailHaloWidthRatio: CGFloat = 2.4
    public static let trailHaloAlphaRatio: CGFloat = 0.55
    public static let headCoreWidth: CGFloat = 17
    public static let headGlowWidth: CGFloat = 36
    public static let headDashFraction: Double = 0.0012
    public static let rimHaloWidth: CGFloat = 24
    public static let rimCoreWidth: CGFloat = 7.5

    public static let trailHaloBlur: CGFloat = 9
    public static let headGlowBlur: CGFloat = 7
    public static let rimHaloBlur: CGFloat = 8
    // Bloom blurs tightened from the reference (10/26/14) for a crisper,
    // punchier landing per user feedback during visual verification.
    public static let flashBlur: CGFloat = 3
    public static let breathABlur: CGFloat = 10

    public static func scale(forScreenWidth width: CGFloat) -> CGFloat {
        width / referenceScreenWidth
    }

    public static func clamp01(_ u: Double) -> Double { min(max(u, 0), 1) }

    /// Travel easing: smootherstep blended with 8 % linear — slow launch,
    /// fast mid-sweep, decelerating arrival that never fully stalls.
    public static func easedProgress(_ u: Double) -> Double {
        let x = clamp01(u)
        return 0.92 * (x * x * x * (x * (x * 6 - 15) + 10)) + 0.08 * x
    }

    public static func easeOutQuad(_ u: Double) -> Double {
        let x = clamp01(u)
        return 1 - (1 - x) * (1 - x)
    }

    /// Head width multiplier while traveling (2.2 Hz, ±7 %).
    public static func throb(at t: Double) -> Double {
        1 + 0.07 * sin(t * 2 * .pi * 2.2)
    }

    /// Visible trail length (fraction of the perimeter) at eased progress
    /// `e` of `total`: grows from launch, collapses into the head over the
    /// last `collapseFraction` of the approach.
    public static func trailLength(progress e: Double, total: Double) -> Double {
        min(trailMaxFraction, e) * min(1, max(0, total - e) / collapseFraction)
    }

    /// Total sweep duration: scales with distance so the speed stays
    /// constant across lap counts, calibrated so the default 2-lap sweep
    /// takes `lapDuration` seconds.
    public static func travelDuration(lapDuration: Double, laps: Int, landingFraction: Double) -> Double {
        let distance = Double(max(1, laps)) + landingFraction
        return lapDuration * distance / (calibrationLaps + landingFraction)
    }
}

/// Envelope values for the landing finale at phase `u` (0…1 over
/// `CometMath.finaleDuration`). Radii are in reference units.
public struct FinaleState: Equatable {
    public let flashRadius: CGFloat
    public let flashOpacity: CGFloat
    /// Dash half-length drawn outward from the rim path's midpoint (0…0.5).
    public let rimFraction: CGFloat
    /// Shared late-phase fade factor (1 until u = 0.72, then → 0).
    public let fade: CGFloat
    /// Breathing-glow envelope (one sin pulse, 0…1…0).
    public let breath: CGFloat
    public let glintRadius: CGFloat
    public let glintOpacity: CGFloat

    public static func at(_ u: Double) -> FinaleState {
        let n = CometMath.clamp01(u / 0.16)
        let fade = u < 0.72 ? 1.0 : max(0, 1 - (u - 0.72) / 0.28)
        return FinaleState(
            flashRadius: CGFloat(12 + 80 * CometMath.easeOutQuad(n)),
            flashOpacity: CGFloat(0.95 * (1 - n)),
            rimFraction: CGFloat(CometMath.easeOutQuad(u / 0.32) * 0.5),
            fade: CGFloat(fade),
            // Faster-attack pulse (pow < 1 steepens the rise) and a larger
            // hard-white core than the reference (9), per user feedback.
            breath: CGFloat(pow(sin(.pi * CometMath.clamp01((u - 0.1) / 0.62)), 0.75)),
            glintRadius: CGFloat(max(2, 14 * (1 - u))),
            // The glint dies into the flash (gone by 25 % of the finale)
            // instead of lingering through the pulse as a center dot
            // (reference used 1 − Tm(u); changed per user feedback).
            glintOpacity: CGFloat(1 - CometMath.easeOutQuad(u / 0.25)))
    }
}
