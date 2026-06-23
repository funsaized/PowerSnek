import AppKit

public enum ScreenGeometry {
    /// Reads the display's corner radius via private KVC, falling back to a constant.
    public static func cornerRadius(for screen: NSScreen, fallback: CGFloat) -> CGFloat {
        if let n = screen.value(forKey: "_cornerRadius") as? NSNumber {
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
