import AppKit

/// Comet colors derived from the user's chosen color. With the default
/// green these land within a few percent of the reference palette
/// (base #2BD46E, bright #5BEF96, tail rgb(20,156,85), rimCore #d9ffe9).
public struct CometPalette {
    public let base: NSColor
    public let bright: NSColor
    public let tail: NSColor
    public let rimCore: NSColor

    public init(base color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        base = c
        bright = Self.srgb(hue: h, saturation: min(1, s * 0.78), brightness: min(1, b * 1.13))
        tail = Self.srgb(hue: h, saturation: min(1, s * 1.09), brightness: b * 0.73)
        rimCore = Self.lerp(.white, c, 0.15)
    }

    /// White-hot head → bright → tail gradient at trail position `a`
    /// (0 = head, 1 = tail tip).
    public func trailColor(at a: CGFloat) -> NSColor {
        if a < 0.1 { return Self.lerp(.white, bright, a / 0.1) }
        return Self.lerp(bright, tail, (a - 0.1) / 0.9)
    }

    /// The tapered trail segments, head-adjacent first. Widths are in
    /// reference units.
    public func trailProfile(segments: Int = CometMath.trailSegmentCount) -> [TrailSegment] {
        (0..<segments).map { i in
            let a = (CGFloat(i) + 0.5) / CGFloat(segments)
            return TrailSegment(
                width: CometMath.trailBaseWidth - CometMath.trailTaperWidth * pow(a, 0.9),
                alpha: pow(1 - a, 1.35),
                color: trailColor(at: a))
        }
    }

    /// Component-wise sRGB interpolation (the reference lerps raw RGB).
    static func lerp(_ from: NSColor, _ to: NSColor, _ t: CGFloat) -> NSColor {
        let f = from.usingColorSpace(.sRGB) ?? from
        let g = to.usingColorSpace(.sRGB) ?? to
        let u = min(max(t, 0), 1)
        return NSColor(srgbRed: f.redComponent + (g.redComponent - f.redComponent) * u,
                       green: f.greenComponent + (g.greenComponent - f.greenComponent) * u,
                       blue: f.blueComponent + (g.blueComponent - f.blueComponent) * u,
                       alpha: 1)
    }

    /// HSV→RGB directly in sRGB, avoiding NSColor's calibrated-space
    /// hue initializer (which would shift the color).
    static func srgb(hue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat) -> NSColor {
        let i = floor(h * 6)
        let f = h * 6 - i
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

/// One stacked stroke of the comet's tail.
public struct TrailSegment {
    public let width: CGFloat
    public let alpha: CGFloat
    public let color: NSColor
}
