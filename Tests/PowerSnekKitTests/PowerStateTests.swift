import XCTest
@testable import PowerSnekKit

final class PowerStateTests: XCTestCase {
    func test_states_areDistinct() {
        XCTAssertNotEqual(PowerState.ac, PowerState.battery)
    }
}
