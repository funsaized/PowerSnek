import XCTest
@testable import PowerSnekKit

final class CometMathTests: XCTestCase {

    func test_travelProgress_launchesCruisesAndCaptures() {
        let duration = 3.1
        XCTAssertEqual(CometMath.travelProgress(elapsed: 0, duration: duration), 0, accuracy: 1e-9)
        XCTAssertEqual(CometMath.travelProgress(elapsed: duration, duration: duration), 1, accuracy: 1e-9)

        let dt = 0.01
        let launchSpeed = (CometMath.travelProgress(elapsed: dt, duration: duration)
            - CometMath.travelProgress(elapsed: 0, duration: duration)) / dt
        let cruiseSpeed = (CometMath.travelProgress(elapsed: 1 + dt, duration: duration)
            - CometMath.travelProgress(elapsed: 1, duration: duration)) / dt
        let landingSpeed = (CometMath.travelProgress(elapsed: duration, duration: duration)
            - CometMath.travelProgress(elapsed: duration - dt, duration: duration)) / dt

        XCTAssertGreaterThan(cruiseSpeed, launchSpeed * 2)
        XCTAssertGreaterThan(cruiseSpeed, landingSpeed * 5)
    }

    func test_travelProgress_isMonotonic() {
        var previous = -1.0
        for i in 0...500 {
            let value = CometMath.travelProgress(elapsed: 3.1 * Double(i) / 500, duration: 3.1)
            XCTAssertGreaterThan(value, previous)
            previous = value
        }
    }

    func test_travelProgress_cruiseHasConstantVelocity() {
        let first = CometMath.travelProgress(elapsed: 1.2, duration: 3.1)
            - CometMath.travelProgress(elapsed: 1.0, duration: 3.1)
        let second = CometMath.travelProgress(elapsed: 1.8, duration: 3.1)
            - CometMath.travelProgress(elapsed: 1.6, duration: 3.1)
        XCTAssertEqual(first, second, accuracy: 1e-9)
    }

    func test_visualScale_isClampedForExtremeDisplayWidths() {
        XCTAssertEqual(CometMath.visualScale(forScreenWidth: 800), 0.8, accuracy: 1e-9)
        XCTAssertEqual(CometMath.visualScale(forScreenWidth: 1600), 1, accuracy: 1e-9)
        XCTAssertEqual(CometMath.visualScale(forScreenWidth: 4000), 1.35, accuracy: 1e-9)
    }

    func test_trailLength_growsThenCollapsesToZeroAtLanding() {
        let total = 2.46
        XCTAssertEqual(CometMath.trailLength(progress: 0, total: total), 0, accuracy: 1e-9)
        XCTAssertEqual(CometMath.trailLength(progress: 0.1, total: total), 0.1, accuracy: 1e-9)
        XCTAssertEqual(CometMath.trailLength(progress: 1.0, total: total), 0.15, accuracy: 1e-9)
        XCTAssertEqual(CometMath.trailLength(progress: total - 0.15, total: total), 0.075, accuracy: 1e-9)
        XCTAssertEqual(CometMath.trailLength(progress: total, total: total), 0, accuracy: 1e-9)
    }

    func test_throb_oscillatesAroundOneWithSevenPercentAmplitude() {
        XCTAssertEqual(CometMath.throb(at: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(CometMath.throb(at: 1 / 8.8), 1.07, accuracy: 1e-6) // sin peak: 2π·2.2·t = π/2
    }

    func test_travelDuration_twoLapsMatchesSliderValue() {
        XCTAssertEqual(CometMath.travelDuration(lapDuration: 3.1, laps: 2, landingFraction: 0.46),
                       3.1, accuracy: 1e-9)
    }

    func test_travelDuration_scalesLinearlyWithDistance() {
        let d2 = CometMath.travelDuration(lapDuration: 3.1, laps: 2, landingFraction: 0.46)
        let d4 = CometMath.travelDuration(lapDuration: 3.1, laps: 4, landingFraction: 0.46)
        XCTAssertEqual(d4 / d2, (4 + 0.46) / (2 + 0.46), accuracy: 1e-9)
    }

    func test_travelDuration_floorsNonPositiveLapDuration() {
        XCTAssertEqual(CometMath.travelDuration(lapDuration: 0, laps: 2, landingFraction: 0.46),
                       0.1, accuracy: 1e-9)
    }

    // Finale envelopes
    func test_finale_startState() {
        let f = FinaleState.at(0)
        XCTAssertEqual(f.flashRadius, 12, accuracy: 1e-6)
        XCTAssertEqual(f.flashOpacity, 0.95, accuracy: 1e-6)
        XCTAssertEqual(f.rimFraction, 0, accuracy: 1e-6)
        XCTAssertEqual(f.fade, 1, accuracy: 1e-6)
        XCTAssertEqual(f.breath, 0, accuracy: 1e-6)
        XCTAssertEqual(f.glintRadius, 14, accuracy: 1e-6)
        XCTAssertEqual(f.glintOpacity, 1, accuracy: 1e-6)
    }

    func test_finale_endStateIsFullyInvisible() {
        let f = FinaleState.at(1)
        XCTAssertEqual(f.flashOpacity, 0, accuracy: 1e-6)
        XCTAssertEqual(f.fade, 0, accuracy: 1e-6)
        XCTAssertEqual(f.breath, 0, accuracy: 1e-4)
        XCTAssertEqual(f.glintOpacity, 0, accuracy: 1e-6)
    }

    func test_finale_breathPeaksMidPhase() {
        XCTAssertEqual(FinaleState.at(0.41).breath, 1, accuracy: 1e-6) // sin(π·clamp((u−0.1)/0.62)) peaks at u = 0.41
        XCTAssertGreaterThan(FinaleState.at(0.41).breath, FinaleState.at(0.2).breath)
        XCTAssertGreaterThan(FinaleState.at(0.41).breath, FinaleState.at(0.65).breath)
    }

    func test_finale_rimFullyDrawnAtThirtyTwoPercent() {
        XCTAssertEqual(FinaleState.at(0.32).rimFraction, 0.5, accuracy: 1e-6)
    }
}
