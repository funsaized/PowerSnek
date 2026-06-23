import XCTest
import CoreGraphics
@testable import PowerSnekKit

final class PerimeterPathBuilderTests: XCTestCase {

    // makeNotchInput
    func test_makeNotchInput_convertsToLocalCoords() {
        let n = PerimeterPathBuilder.makeNotchInput(
            frameMinX: 100, auxLeftMaxX: 600, auxRightMinX: 740,
            safeAreaTop: 38, innerCornerRadius: 6)
        XCTAssertEqual(n, NotchInput(left: 500, right: 640, depth: 38, innerCornerRadius: 6))
    }
    func test_makeNotchInput_nilWhenNoInset() {
        XCTAssertNil(PerimeterPathBuilder.makeNotchInput(
            frameMinX: 0, auxLeftMaxX: 600, auxRightMinX: 740,
            safeAreaTop: 0, innerCornerRadius: 6))
    }
    func test_makeNotchInput_nilWhenRightNotPastLeft() {
        XCTAssertNil(PerimeterPathBuilder.makeNotchInput(
            frameMinX: 0, auxLeftMaxX: 700, auxRightMinX: 600,
            safeAreaTop: 38, innerCornerRadius: 6))
    }

    // buildPath bounding box (both notch and no-notch share the outer rect)
    func test_buildPath_boundingBoxMatchesInsetRect() {
        let input = ScreenOutlineInput(width: 1000, height: 700, cornerRadius: 12, inset: 2, notch: nil)
        let box = PerimeterPathBuilder.buildPath(input).boundingBox
        XCTAssertEqual(box.minX, 2, accuracy: 0.6)
        XCTAssertEqual(box.minY, 2, accuracy: 0.6)
        XCTAssertEqual(box.maxX, 998, accuracy: 0.6)
        XCTAssertEqual(box.maxY, 698, accuracy: 0.6)
    }

    // The notch region is cut OUT of the filled area
    func test_buildPath_notchPointIsOutside() {
        let notch = NotchInput(left: 440, right: 560, depth: 40, innerCornerRadius: 6)
        let input = ScreenOutlineInput(width: 1000, height: 700, cornerRadius: 12, inset: 2, notch: notch)
        let path = PerimeterPathBuilder.buildPath(input)
        // centre of the notch gap: x = 500 (within [440,560]), y just below the top edge
        let p = CGPoint(x: 500, y: 698 - 20) // top = height-inset = 698, depth 40 -> mid at 678
        XCTAssertFalse(path.contains(p))
    }

    // Same point IS inside when there is no notch
    func test_buildPath_samePointInsideWhenNoNotch() {
        let input = ScreenOutlineInput(width: 1000, height: 700, cornerRadius: 12, inset: 2, notch: nil)
        let path = PerimeterPathBuilder.buildPath(input)
        let p = CGPoint(x: 500, y: 698 - 20)
        XCTAssertTrue(path.contains(p))
    }
}
