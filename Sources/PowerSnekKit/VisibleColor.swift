import AppKit

/// The comet is composited with screen blending, which makes dark colors
/// fade toward invisible (pure black draws nothing at all). Colors are
/// brightened to a floor, keeping their hue and saturation, before use.
public enum VisibleColor {
    public static let minimumBrightness: CGFloat = 0.6

    public static func isTooDark(_ color: NSColor) -> Bool {
        hsb(color).brightness < minimumBrightness - 0.001
    }

    public static func clamped(_ color: NSColor) -> NSColor {
        let (h, s, b) = hsb(color)
        guard b < minimumBrightness else { return color.usingColorSpace(.sRGB) ?? color }
        return CometPalette.srgb(hue: h, saturation: s, brightness: minimumBrightness)
    }

    /// Hex in, clamped hex out; invalid hex is returned unchanged.
    public static func clampedHex(_ hex: String) -> String {
        guard let color = HexColor.nsColor(fromHex: hex) else { return hex }
        return HexColor.hex(from: clamped(color))
    }

    private static func hsb(_ color: NSColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        let c = color.usingColorSpace(.sRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }
}
