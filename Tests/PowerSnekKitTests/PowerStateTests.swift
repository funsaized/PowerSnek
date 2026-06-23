import XCTest
@testable import PowerSnekKit

final class PowerStateTests: XCTestCase {
    func test_fires_onBatteryToAC() {
        XCTAssertTrue(PowerState.shouldFire(previous: .battery, current: .ac))
    }
    func test_doesNotFire_onACToBattery() {
        XCTAssertFalse(PowerState.shouldFire(previous: .ac, current: .battery))
    }
    func test_doesNotFire_onSameState() {
        XCTAssertFalse(PowerState.shouldFire(previous: .ac, current: .ac))
        XCTAssertFalse(PowerState.shouldFire(previous: .battery, current: .battery))
    }
    func test_doesNotFire_fromUnknown() {
        XCTAssertFalse(PowerState.shouldFire(previous: .unknown, current: .ac))
    }
    func test_doesNotFire_toUnknown() {
        XCTAssertFalse(PowerState.shouldFire(previous: .battery, current: .unknown))
    }
}
