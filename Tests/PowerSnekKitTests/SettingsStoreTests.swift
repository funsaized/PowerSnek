import XCTest
@testable import PowerSnekKit

final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func test_defaults() {
        let s = SettingsStore(defaults: makeDefaults())
        XCTAssertTrue(s.effectEnabled)
        XCTAssertEqual(s.cometColorHex, "#34FF6A")
        XCTAssertEqual(s.lapCount, 2)
        XCTAssertEqual(s.lapDuration, 3.1, accuracy: 0.0001)
        XCTAssertFalse(s.hasCompletedOnboarding)
        XCTAssertTrue(s.pauseOverFullScreen)
        XCTAssertTrue(s.hideFromScreenCapture)
    }

    func test_darkColor_isStoredBrightened() {
        let d = makeDefaults()
        let s = SettingsStore(defaults: d)
        s.cometColorHex = "#000000"
        XCTAssertEqual(s.cometColorHex, VisibleColor.clampedHex("#000000"))
        XCTAssertEqual(SettingsStore(defaults: d).cometColorHex, s.cometColorHex)
    }

    func test_legacyDarkColor_isBrightenedOnLoad() {
        let d = makeDefaults()
        d.set("#010101", forKey: "cometColorHex")
        XCTAssertFalse(VisibleColor.isTooDark(HexColor.nsColor(fromHex: SettingsStore(defaults: d).cometColorHex)!))
    }

    func test_persistsAcrossInstances() {
        let d = makeDefaults()
        let s1 = SettingsStore(defaults: d)
        s1.effectEnabled = false
        s1.lapCount = 4
        s1.cometColorHex = "#FF0000"
        s1.lapDuration = 0.8
        s1.hasCompletedOnboarding = true

        let s2 = SettingsStore(defaults: d)
        XCTAssertFalse(s2.effectEnabled)
        XCTAssertEqual(s2.lapCount, 4)
        XCTAssertEqual(s2.cometColorHex, "#FF0000")
        XCTAssertEqual(s2.lapDuration, 0.8, accuracy: 0.0001)
        XCTAssertTrue(s2.hasCompletedOnboarding)
    }
}
