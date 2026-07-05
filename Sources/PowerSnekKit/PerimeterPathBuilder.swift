import CoreGraphics

public struct NotchInput: Equatable {
    public let left: CGFloat
    public let right: CGFloat
    public let depth: CGFloat
    public let innerCornerRadius: CGFloat
    public init(left: CGFloat, right: CGFloat, depth: CGFloat, innerCornerRadius: CGFloat) {
        self.left = left; self.right = right; self.depth = depth; self.innerCornerRadius = innerCornerRadius
    }
}

public struct ScreenOutlineInput: Equatable {
    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat
    public let inset: CGFloat
    public let notch: NotchInput?
    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat, inset: CGFloat, notch: NotchInput?) {
        self.width = width; self.height = height; self.cornerRadius = cornerRadius; self.inset = inset; self.notch = notch
    }
}

/// The screen's traced outline plus the landing metrics the Comet 2.0
/// choreography needs. View-local coords, origin bottom-left, y up.
public struct ScreenOutline {
    /// Closed perimeter starting at the bottom-left corner, clockwise on
    /// screen (up the left edge first).
    public let path: CGPath
    public let totalLength: CGFloat
    /// Arc-length fraction where the comet lands (notch-bottom center, or
    /// top-edge center when there is no notch).
    public let landingFraction: CGFloat
    public let landingPoint: CGPoint
    /// The notch outline (entry corner → walls → floor → exit corner),
    /// same direction as the perimeter; nil when there is no notch. Its
    /// arc-length midpoint is the landing point.
    public let rimPath: CGPath?
    public let rimLength: CGFloat
    /// Notch bounds (or a nominal reference-notch-sized rect at top-center
    /// when there is no notch), for the finale's breathing glow.
    public let notchRect: CGRect
    public let hasNotch: Bool
}

/// Builds a CGPath while tracking analytic arc length. Lines and
/// quarter-circle tangent arcs only; callers guarantee each arc starts
/// exactly at the current point so no connecting line is inserted.
private struct PathTracer {
    let path = CGMutablePath()
    private(set) var length: CGFloat = 0

    mutating func move(to p: CGPoint) {
        path.move(to: p)
    }

    mutating func line(to p: CGPoint) {
        let c = path.currentPoint
        path.addLine(to: p)
        length += hypot(p.x - c.x, p.y - c.y)
    }

    mutating func corner(_ tangent: CGPoint, _ end: CGPoint, radius: CGFloat) {
        guard radius > 0 else {
            line(to: tangent)
            return
        }
        path.addArc(tangent1End: tangent, tangent2End: end, radius: radius)
        length += .pi * radius / 2
    }
}

public enum PerimeterPathBuilder {

    /// Converts screen-space notch geometry into view-local NotchInput.
    /// Returns nil when there is no notch (no top safe-area inset or invalid span).
    public static func makeNotchInput(frameMinX: CGFloat,
                                      auxLeftMaxX: CGFloat,
                                      auxRightMinX: CGFloat,
                                      safeAreaTop: CGFloat,
                                      innerCornerRadius: CGFloat) -> NotchInput? {
        guard safeAreaTop > 0 else { return nil }
        let left = auxLeftMaxX - frameMinX
        let right = auxRightMinX - frameMinX
        guard right > left else { return nil }
        return NotchInput(left: left, right: right, depth: safeAreaTop, innerCornerRadius: innerCornerRadius)
    }

    /// Compatibility wrapper; prefer `buildOutline`.
    public static func buildPath(_ input: ScreenOutlineInput) -> CGPath {
        buildOutline(input).path
    }

    /// Builds the closed perimeter outline with Comet 2.0 landing metrics.
    public static func buildOutline(_ input: ScreenOutlineInput) -> ScreenOutline {
        let left = input.inset
        let right = input.width - input.inset
        let bottom = input.inset
        let top = input.height - input.inset
        let r = max(0, min(input.cornerRadius, (right - left) / 2, (top - bottom) / 2))

        var t = PathTracer()
        t.move(to: CGPoint(x: left, y: bottom + r))
        t.line(to: CGPoint(x: left, y: top - r))
        t.corner(CGPoint(x: left, y: top), CGPoint(x: left + r, y: top), radius: r)

        let landingLength: CGFloat
        let landingPoint: CGPoint
        var rimPath: CGPath?
        var rimLength: CGFloat = 0
        let notchRect: CGRect

        if let notch = input.notch {
            // Clamp the notch floor so a pathological depth cannot drop
            // below the bottom edge and self-cross the outline.
            let notchBottom = max(bottom + r, top - notch.depth)
            let depth = top - notchBottom
            let ic = max(0, min(notch.innerCornerRadius, (notch.right - notch.left) / 2, depth / 2))
            let centerX = (notch.left + notch.right) / 2

            t.line(to: CGPoint(x: notch.left - ic, y: top))
            let lengthAtNotchEntry = t.length

            // The notch trace is shared by the perimeter and the finale's
            // rim path; all four corners are rounded, entry corners included.
            func traceNotch(into tracer: inout PathTracer) {
                tracer.corner(CGPoint(x: notch.left, y: top),
                              CGPoint(x: notch.left, y: top - ic), radius: ic)
                tracer.line(to: CGPoint(x: notch.left, y: notchBottom + ic))
                tracer.corner(CGPoint(x: notch.left, y: notchBottom),
                              CGPoint(x: notch.left + ic, y: notchBottom), radius: ic)
                tracer.line(to: CGPoint(x: notch.right - ic, y: notchBottom))
                tracer.corner(CGPoint(x: notch.right, y: notchBottom),
                              CGPoint(x: notch.right, y: notchBottom + ic), radius: ic)
                tracer.line(to: CGPoint(x: notch.right, y: top - ic))
                tracer.corner(CGPoint(x: notch.right, y: top),
                              CGPoint(x: notch.right + ic, y: top), radius: ic)
            }

            traceNotch(into: &t)

            var rim = PathTracer()
            rim.move(to: CGPoint(x: notch.left - ic, y: top))
            traceNotch(into: &rim)
            rimPath = rim.path
            rimLength = rim.length

            // Entry corner + left wall + floor corner + half the floor.
            landingLength = lengthAtNotchEntry
                + .pi * ic / 2
                + ((top - ic) - (notchBottom + ic))
                + .pi * ic / 2
                + (centerX - (notch.left + ic))
            landingPoint = CGPoint(x: centerX, y: notchBottom)
            notchRect = CGRect(x: notch.left, y: notchBottom,
                               width: notch.right - notch.left, height: depth)

            t.line(to: CGPoint(x: right - r, y: top))
        } else {
            let centerX = (left + right) / 2
            landingLength = t.length + (centerX - (left + r))
            landingPoint = CGPoint(x: centerX, y: top)
            let s = CometMath.scale(forScreenWidth: input.width)
            let nw = CometMath.referenceNotchSize.width * s
            let nh = CometMath.referenceNotchSize.height * s
            notchRect = CGRect(x: centerX - nw / 2, y: top - nh, width: nw, height: nh)

            t.line(to: CGPoint(x: right - r, y: top))
        }

        t.corner(CGPoint(x: right, y: top), CGPoint(x: right, y: top - r), radius: r)
        t.line(to: CGPoint(x: right, y: bottom + r))
        t.corner(CGPoint(x: right, y: bottom), CGPoint(x: right - r, y: bottom), radius: r)
        t.line(to: CGPoint(x: left + r, y: bottom))
        t.corner(CGPoint(x: left, y: bottom), CGPoint(x: left, y: bottom + r), radius: r)
        t.path.closeSubpath()

        return ScreenOutline(path: t.path,
                             totalLength: t.length,
                             landingFraction: t.length > 0 ? landingLength / t.length : 0,
                             landingPoint: landingPoint,
                             rimPath: rimPath,
                             rimLength: rimLength,
                             notchRect: notchRect,
                             hasNotch: input.notch != nil)
    }
}
