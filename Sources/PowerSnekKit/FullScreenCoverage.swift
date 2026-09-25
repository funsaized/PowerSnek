import CoreGraphics

/// The subset of a `CGWindowListCopyWindowInfo` entry PowerSnek needs. These
/// fields are readable without Screen Recording permission.
public struct WindowSnapshot: Equatable, Sendable {
    /// Global display coordinates (origin top-left of the main display, y down).
    public let bounds: CGRect
    public let layer: Int
    public let alpha: Double
    public let ownerPID: Int32

    public init(bounds: CGRect, layer: Int, alpha: Double, ownerPID: Int32) {
        self.bounds = bounds; self.layer = layer; self.alpha = alpha; self.ownerPID = ownerPID
    }
}

/// Decides whether a display is currently showing a full-screen app, video,
/// or presentation, so a charger connection doesn't paint over it.
public enum FullScreenCoverage {
    /// `kCGNormalWindowLevel`: full-screen apps live here. Utility overlays
    /// (dimmers, border tools, HUDs) sit higher and are deliberately ignored
    /// so they can't make PowerSnek think every display is always busy.
    public static let normalLayer = 0
    /// `kCGMainMenuWindowLevel`: the menu bar. It is hidden in a full-screen
    /// Space, which distinguishes real full screen from a merely maximized
    /// window that happens to cover the display.
    public static let mainMenuLayer = 24

    /// - Parameters:
    ///   - displayBounds: the display in the same global coordinates as the windows.
    ///   - topInset: the display's top safe-area inset. Full-screen windows on
    ///     notched MacBooks stop below the notch, so they cover the display
    ///     only up to this inset.
    public static func isFullScreenAppShowing(on displayBounds: CGRect,
                                              topInset: CGFloat,
                                              windows: [WindowSnapshot],
                                              excludingPID: Int32) -> Bool {
        let menuBarVisible = windows.contains { w in
            w.layer == mainMenuLayer && w.alpha > 0.01 && w.bounds.intersects(displayBounds)
        }
        guard !menuBarVisible else { return false }
        return windows.contains { w in
            w.ownerPID != excludingPID
                && w.layer == normalLayer
                && w.alpha > 0.01
                && covers(w.bounds, displayBounds, topInset: topInset)
        }
    }

    /// True when `window` covers `display`, allowing the top `topInset`
    /// points (y-down coordinates) and one point of rounding slack.
    static func covers(_ window: CGRect, _ display: CGRect, topInset: CGFloat) -> Bool {
        let slack: CGFloat = 1
        return window.minX <= display.minX + slack
            && window.maxX >= display.maxX - slack
            && window.maxY >= display.maxY - slack
            && window.minY <= display.minY + max(0, topInset) + slack
    }
}
