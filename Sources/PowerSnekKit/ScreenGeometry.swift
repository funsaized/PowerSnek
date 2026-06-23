import AppKit

public enum ScreenGeometry {
    /// Reads the display's corner radius via private KVC, falling back to a constant.
    /// Guards the KVC access with `responds(to:)` so a missing private key cannot
    /// raise `NSUnknownKeyException` (which AppKit silently swallows mid-event).
    public static func cornerRadius(for screen: NSScreen, fallback: CGFloat) -> CGFloat {
        let key = "_cornerRadius"
        let responds = screen.responds(to: NSSelectorFromString(key))
        if responds, let n = screen.value(forKey: key) as? NSNumber {
            let v = CGFloat(n.doubleValue)
            if v > 0 { return v }
        }
        return fallback
    }

    public static func outlineInput(for screen: NSScreen,
                                    inset: CGFloat,
                                    builtInFallbackRadius: CGFloat,
                                    notchInnerRadius: CGFloat) -> ScreenOutlineInput {
        let frame = screen.frame
        let hasNotchInset = screen.safeAreaInsets.top > 0
        let radius = cornerRadius(for: screen, fallback: hasNotchInset ? builtInFallbackRadius : 0)

        var notch: NotchInput? = nil
        if let l = screen.auxiliaryTopLeftArea, let rgt = screen.auxiliaryTopRightArea {
            notch = PerimeterPathBuilder.makeNotchInput(
                frameMinX: frame.minX,
                auxLeftMaxX: l.maxX,
                auxRightMinX: rgt.minX,
                safeAreaTop: screen.safeAreaInsets.top,
                innerCornerRadius: notchInnerRadius)
        }

        return ScreenOutlineInput(width: frame.width,
                                  height: frame.height,
                                  cornerRadius: radius,
                                  inset: inset,
                                  notch: notch)
    }
}
