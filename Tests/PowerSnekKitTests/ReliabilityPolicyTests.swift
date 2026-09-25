import XCTest
@testable import PowerSnekKit

final class FullScreenCoverageTests: XCTestCase {
    // A 1512x982 notched MacBook display at the global origin (y down).
    private let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let notchInset: CGFloat = 38
    private let me: Int32 = 100

    private func window(_ rect: CGRect, layer: Int = 0, alpha: Double = 1, pid: Int32 = 200) -> WindowSnapshot {
        WindowSnapshot(bounds: rect, layer: layer, alpha: alpha, ownerPID: pid)
    }

    private var menuBar: WindowSnapshot {
        window(CGRect(x: 0, y: 0, width: 1512, height: notchInset), layer: FullScreenCoverage.mainMenuLayer, pid: 1)
    }

    func test_fullScreenWindowBelowNotch_counts() {
        let fullScreen = window(CGRect(x: 0, y: notchInset, width: 1512, height: 982 - notchInset))
        XCTAssertTrue(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: notchInset, windows: [fullScreen], excludingPID: me))
    }

    func test_windowCoveringWholeDisplay_counts() {
        XCTAssertTrue(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: 0, windows: [window(display)], excludingPID: me))
    }

    func test_visibleMenuBar_meansNotFullScreen() {
        // A maximized window with a hidden Dock covers the same area as a
        // full-screen one; the visible menu bar tells them apart.
        let maximized = window(CGRect(x: 0, y: notchInset, width: 1512, height: 982 - notchInset))
        XCTAssertFalse(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: notchInset, windows: [menuBar, maximized], excludingPID: me))
    }

    func test_partialWindow_doesNotCount() {
        let half = window(CGRect(x: 0, y: 0, width: 756, height: 982))
        XCTAssertFalse(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: 0, windows: [half], excludingPID: me))
    }

    func test_ignoresOwnWindowsOverlaysAndTransparentWindows() {
        let windows = [
            window(display, pid: me),                // our own overlay
            window(display, layer: 25),              // a utility overlay above normal level
            window(display, alpha: 0),               // an invisible window
        ]
        XCTAssertFalse(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: 0, windows: windows, excludingPID: me))
    }

    func test_windowOnAnotherDisplay_doesNotCount() {
        let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        XCTAssertFalse(FullScreenCoverage.isFullScreenAppShowing(
            on: display, topInset: 0, windows: [window(external)], excludingPID: me))
    }
}

final class CelebrationGateTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func test_firesImmediatelyWhenPresentable() {
        var gate = CelebrationGate()
        XCTAssertEqual(gate.chargerConnected(at: t0, presentable: true), .fireNow)
        XCTAssertNil(gate.pendingSince)
        XCTAssertFalse(gate.becamePresentable(at: t0.addingTimeInterval(1), stillOnAC: true))
    }

    func test_defersUntilPresentable_thenFiresOnce() {
        var gate = CelebrationGate()
        XCTAssertEqual(gate.chargerConnected(at: t0, presentable: false), .deferred)
        XCTAssertTrue(gate.becamePresentable(at: t0.addingTimeInterval(5), stillOnAC: true))
        XCTAssertFalse(gate.becamePresentable(at: t0.addingTimeInterval(6), stillOnAC: true))
    }

    func test_dropsDeferredCelebrationAfterWindow() {
        var gate = CelebrationGate()
        _ = gate.chargerConnected(at: t0, presentable: false)
        XCTAssertFalse(gate.becamePresentable(
            at: t0.addingTimeInterval(CelebrationGate.deferWindow + 1), stillOnAC: true))
        XCTAssertNil(gate.pendingSince)
    }

    func test_dropsDeferredCelebrationWhenUnpluggedMeanwhile() {
        var gate = CelebrationGate()
        _ = gate.chargerConnected(at: t0, presentable: false)
        XCTAssertFalse(gate.becamePresentable(at: t0.addingTimeInterval(3), stillOnAC: false))
    }
}

final class VisibleColorTests: XCTestCase {
    func test_black_isBrightenedToVisibleGray() {
        let hex = VisibleColor.clampedHex("#000000")
        let c = HexColor.nsColor(fromHex: hex)!
        XCTAssertFalse(VisibleColor.isTooDark(c))
        XCTAssertEqual(c.redComponent, c.greenComponent, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, c.blueComponent, accuracy: 0.01)
    }

    func test_darkColor_keepsHue() {
        let dark = HexColor.nsColor(fromHex: "#0A3300")!   // very dark green
        XCTAssertTrue(VisibleColor.isTooDark(dark))
        let fixed = VisibleColor.clamped(dark).usingColorSpace(.sRGB)!
        XCTAssertEqual(fixed.hueComponent, dark.usingColorSpace(.sRGB)!.hueComponent, accuracy: 0.01)
        XCTAssertEqual(fixed.brightnessComponent, VisibleColor.minimumBrightness, accuracy: 0.01)
    }

    func test_brightColors_areUnchanged() {
        for hex in ["#34FF6A", "#FFFFFF", "#C3FB1C", "#FF0000"] {
            XCTAssertEqual(VisibleColor.clampedHex(hex), hex)
        }
    }

    func test_invalidHex_isReturnedUnchanged() {
        XCTAssertEqual(VisibleColor.clampedHex("nope"), "nope")
    }
}

final class SessionRegistryTests: XCTestCase {
    func test_beginDebouncesUntilEnd() {
        var registry = SessionRegistry<UInt32, String>()
        XCTAssertTrue(registry.begin(1, "a"))
        XCTAssertFalse(registry.begin(1, "b"))
        XCTAssertEqual(registry.sessions[1], "a")
        XCTAssertEqual(registry.end(1), "a")
        XCTAssertFalse(registry.isActive(1))
        XCTAssertTrue(registry.begin(1, "c"))
    }

    func test_keysWhere_findsStaleSessions() {
        var registry = SessionRegistry<UInt32, Int>()
        registry.begin(1, 10)
        registry.begin(2, 20)
        registry.begin(3, 30)
        let live: [UInt32: Int] = [1: 10, 2: 99]
        XCTAssertEqual(Set(registry.keys { id, value in live[id] != value }), [2, 3])
    }
}
