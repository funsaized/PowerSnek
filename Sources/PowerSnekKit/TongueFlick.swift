import CoreGraphics
import Foundation

/// The Snek finale: a forked tongue flicks down out of the landing point
/// twice ("blep blep"). Coordinates are view-local, y up, so the tongue
/// hangs toward negative y.
public enum TongueFlick {
    /// Seconds after landing when each flick starts, and each flick's length.
    public static let flickStarts: [Double] = [0.1, 0.46]
    public static let flickDuration = 0.28
    /// Reference-unit sizes (scaled by `CometMath.visualScale`).
    public static let length: CGFloat = 22
    public static let forkLength: CGFloat = 7
    public static let width: CGFloat = 3.2
    public static let colorHex = "#E23131"

    /// 0 (retracted) … 1 (fully out), as a smooth out-and-back per flick.
    public static func reach(at t: Double) -> Double {
        for start in flickStarts {
            let u = (t - start) / flickDuration
            if u > 0 && u < 1 { return sin(.pi * u) }
        }
        return 0
    }

    public struct Shape: Equatable, Sendable {
        public let origin: CGPoint
        public let stemEnd: CGPoint
        public let leftTip: CGPoint
        public let rightTip: CGPoint
    }

    /// The stem grows first; the fork opens over the second half.
    public static func shape(origin: CGPoint, reach: Double, scale: CGFloat) -> Shape {
        let r = CGFloat(min(max(reach, 0), 1))
        let stemEnd = CGPoint(x: origin.x, y: origin.y - length * scale * r)
        let fork = forkLength * scale * max(0, (r - 0.5) / 0.5)
        let dx = fork * sin(.pi / 5), dy = fork * cos(.pi / 5)   // ±36° from straight down
        return Shape(origin: origin,
                     stemEnd: stemEnd,
                     leftTip: CGPoint(x: stemEnd.x - dx, y: stemEnd.y - dy),
                     rightTip: CGPoint(x: stemEnd.x + dx, y: stemEnd.y - dy))
    }

    /// Total time from landing until the last flick retracts.
    public static var duration: Double { (flickStarts.last ?? 0) + flickDuration }
}
