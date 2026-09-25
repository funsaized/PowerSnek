import XCTest
@testable import PowerSnekKit

final class LaunchAtLoginTests: XCTestCase {
    private let installed = "/Applications/PowerSnek.app"

    func test_isOn_countsPendingApprovalAsOn() {
        XCTAssertTrue(LaunchAtLoginState.enabled.isOn)
        XCTAssertTrue(LaunchAtLoginState.requiresApproval.isOn)
        XCTAssertFalse(LaunchAtLoginState.disabled.isOn)
        XCTAssertFalse(LaunchAtLoginState.unavailable.isOn)
    }

    func test_shouldEnableByDefault_onFirstRunWhenDisabled() {
        XCTAssertTrue(LaunchAtLoginPolicy.shouldEnableByDefault(
            hasCompletedOnboarding: false, state: .disabled, bundlePath: installed))
    }

    func test_shouldEnableByDefault_neverAfterOnboarding() {
        XCTAssertFalse(LaunchAtLoginPolicy.shouldEnableByDefault(
            hasCompletedOnboarding: true, state: .disabled, bundlePath: installed))
    }

    func test_shouldEnableByDefault_leavesOtherStatesAlone() {
        for state in [LaunchAtLoginState.enabled, .requiresApproval, .unavailable] {
            XCTAssertFalse(LaunchAtLoginPolicy.shouldEnableByDefault(
                hasCompletedOnboarding: false, state: state, bundlePath: installed))
        }
    }

    func test_shouldEnableByDefault_skipsTransientLocations() {
        XCTAssertFalse(LaunchAtLoginPolicy.shouldEnableByDefault(
            hasCompletedOnboarding: false, state: .disabled,
            bundlePath: "/Volumes/PowerSnek/PowerSnek.app"))
        XCTAssertFalse(LaunchAtLoginPolicy.shouldEnableByDefault(
            hasCompletedOnboarding: false, state: .disabled,
            bundlePath: "/private/var/folders/xy/T/AppTranslocation/ABC/d/PowerSnek.app"))
    }

    func test_isTransientLocation_acceptsNormalInstalls() {
        XCTAssertFalse(LaunchAtLoginPolicy.isTransientLocation(installed))
        XCTAssertFalse(LaunchAtLoginPolicy.isTransientLocation("/Users/me/Applications/PowerSnek.app"))
    }
}
