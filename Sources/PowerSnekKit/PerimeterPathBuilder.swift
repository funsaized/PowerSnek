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

    /// Builds the closed perimeter outline. View-local coords, origin bottom-left, y up.
    public static func buildPath(_ input: ScreenOutlineInput) -> CGPath {
        let left = input.inset
        let right = input.width - input.inset
        let bottom = input.inset
        let top = input.height - input.inset
        let r = max(0, min(input.cornerRadius, (right - left) / 2, (top - bottom) / 2))

        let path = CGMutablePath()

        guard let notch = input.notch else {
            path.addRoundedRect(in: CGRect(x: left, y: bottom, width: right - left, height: top - bottom),
                                cornerWidth: r, cornerHeight: r)
            return path
        }

        // Clamp the notch floor so a pathological depth (exceeding the usable
        // height) cannot drop below the bottom edge and self-cross the outline.
        let notchBottom = max(bottom + r, top - notch.depth)
        let actualDepth = top - notchBottom
        let ic = max(0, min(notch.innerCornerRadius, (notch.right - notch.left) / 2, actualDepth / 2))

        // Top edge, left of notch
        path.move(to: CGPoint(x: left + r, y: top))
        path.addLine(to: CGPoint(x: notch.left, y: top))
        // Down left wall, rounded bottom-left inner corner
        path.addLine(to: CGPoint(x: notch.left, y: notchBottom + ic))
        path.addArc(tangent1End: CGPoint(x: notch.left, y: notchBottom),
                    tangent2End: CGPoint(x: notch.left + ic, y: notchBottom), radius: ic)
        // Across notch bottom, rounded bottom-right inner corner
        path.addLine(to: CGPoint(x: notch.right - ic, y: notchBottom))
        path.addArc(tangent1End: CGPoint(x: notch.right, y: notchBottom),
                    tangent2End: CGPoint(x: notch.right, y: notchBottom + ic), radius: ic)
        // Up right wall, continue top edge
        path.addLine(to: CGPoint(x: notch.right, y: top))
        path.addLine(to: CGPoint(x: right - r, y: top))
        // Outer corners (tangent arcs), clockwise: TR, BR, BL, TL
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: bottom), radius: r)
        path.addLine(to: CGPoint(x: right, y: bottom + r))
        path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: left, y: bottom), radius: r)
        path.addLine(to: CGPoint(x: left + r, y: bottom))
        path.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: left, y: top), radius: r)
        path.addLine(to: CGPoint(x: left, y: top - r))
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: r)
        path.closeSubpath()
        return path
    }
}
