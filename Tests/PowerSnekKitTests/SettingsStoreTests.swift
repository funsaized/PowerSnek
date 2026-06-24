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
        XCTAssertEqual(s.lapDuration, 3.0, accuracy: 0.0001)
    }

    func test_persistsAcrossInstances() {
        let d = makeDefaults()
        let s1 = SettingsStore(defaults: d)
        s1.effectEnabled = false
        s1.lapCount = 4
        s1.cometColorHex = "#FF0000"
        s1.lapDuration = 0.8

        let s2 = SettingsStore(defaults: d)
        XCTAssertFalse(s2.effectEnabled)
        XCTAssertEqual(s2.lapCount, 4)
        XCTAssertEqual(s2.cometColorHex, "#FF0000")
        XCTAssertEqual(s2.lapDuration, 0.8, accuracy: 0.0001)
    }
}
