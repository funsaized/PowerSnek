import XCTest
import CoreGraphics
@testable import PowerSnekKit

final class ScreenOutlineTests: XCTestCase {

    private let notchInput = ScreenOutlineInput(
        width: 1000, height: 700, cornerRadius: 12, inset: 2,
        notch: NotchInput(left: 440, right: 560, depth: 40, innerCornerRadius: 6))
    private let plainInput = ScreenOutlineInput(
        width: 1000, height: 700, cornerRadius: 12, inset: 2, notch: nil)

    func test_outline_startsAtBottomLeftGoingUpTheLeftEdge() {
        let outline = PerimeterPathBuilder.buildOutline(notchInput)
        let els = pathElements(outline.path)
        XCTAssertEqual(els[0].type, .moveToPoint)
        XCTAssertEqual(els[0].point.x, 2, accuracy: 1e-6)     // left inset
        XCTAssertEqual(els[0].point.y, 14, accuracy: 1e-6)    // bottom + r
        XCTAssertEqual(els[1].type, .addLineToPoint)
        XCTAssertEqual(els[1].point.x, 2, accuracy: 1e-6)
        XCTAssertEqual(els[1].point.y, 686, accuracy: 1e-6)   // top − r: clockwise = up first
    }

    func test_outline_totalLengthMatchesFlattenedMeasurement() {
        for input in [notchInput, plainInput] {
            let outline = PerimeterPathBuilder.buildOutline(input)
            let measured = flattenedLength(outline.path)
            XCTAssertEqual(Double(outline.totalLength), Double(measured),
                           accuracy: Double(outline.totalLength) * 0.005)
        }
    }

    func test_outline_landingIsNotchBottomCenter() {
        let outline = PerimeterPathBuilder.buildOutline(notchInput)
        XCTAssertEqual(outline.landingPoint.x, 500, accuracy: 1e-6)
        XCTAssertEqual(outline.landingPoint.y, 658, accuracy: 1e-6)   // top 698 − depth 40
        let measured = point(along: outline.path, atFraction: outline.landingFraction)
        XCTAssertEqual(measured.x, 500, accuracy: 1.0)
        XCTAssertEqual(measured.y, 658, accuracy: 1.0)
        XCTAssertTrue(outline.hasNotch)
    }

    func test_outline_landingIsTopCenterWithoutNotch() {
        let outline = PerimeterPathBuilder.buildOutline(plainInput)
        XCTAssertEqual(outline.landingPoint.x, 500, accuracy: 1e-6)
        XCTAssertEqual(outline.landingPoint.y, 698, accuracy: 1e-6)   // top edge
        let measured = point(along: outline.path, atFraction: outline.landingFraction)
        XCTAssertEqual(measured.x, 500, accuracy: 1.0)
        XCTAssertEqual(measured.y, 698, accuracy: 1.0)
        XCTAssertNil(outline.rimPath)
        XCTAssertFalse(outline.hasNotch)
    }

    func test_outline_rimMidpointIsNotchBottomCenter() throws {
        let outline = PerimeterPathBuilder.buildOutline(notchInput)
        let rim = try XCTUnwrap(outline.rimPath)
        XCTAssertEqual(Double(outline.rimLength), Double(flattenedLength(rim)),
                       accuracy: Double(outline.rimLength) * 0.005)
        let mid = point(along: rim, atFraction: 0.5)
        XCTAssertEqual(mid.x, 500, accuracy: 1.0)
        XCTAssertEqual(mid.y, 658, accuracy: 1.0)
    }

    func test_outline_notchRectCoversNotch() {
        let outline = PerimeterPathBuilder.buildOutline(notchInput)
        XCTAssertEqual(outline.notchRect, CGRect(x: 440, y: 658, width: 120, height: 40))
    }

    func test_outline_nominalNotchRectWithoutNotch() {
        let outline = PerimeterPathBuilder.buildOutline(plainInput)
        let s: CGFloat = 1000.0 / 1600.0
        XCTAssertEqual(outline.notchRect.width, 173 * s, accuracy: 1e-6)
        XCTAssertEqual(outline.notchRect.height, 34 * s, accuracy: 1e-6)
        XCTAssertEqual(outline.notchRect.midX, 500, accuracy: 1e-6)
        XCTAssertEqual(outline.notchRect.maxY, 698, accuracy: 1e-6)
    }
}

// MARK: - Path measurement helpers (test-only)

private struct PathElement {
    let type: CGPathElementType
    let point: CGPoint
}

private func pathElements(_ path: CGPath) -> [PathElement] {
    var result: [PathElement] = []
    path.applyWithBlock { el in
        let e = el.pointee
        switch e.type {
        case .moveToPoint, .addLineToPoint:
            result.append(PathElement(type: e.type, point: e.points[0]))
        case .addQuadCurveToPoint:
            result.append(PathElement(type: e.type, point: e.points[1]))
        case .addCurveToPoint:
            result.append(PathElement(type: e.type, point: e.points[2]))
        default:
            result.append(PathElement(type: e.type, point: .zero))
        }
    }
    return result
}

/// Flattens curves into sampled points so lengths/positions can be
/// measured independently of the analytic bookkeeping under test.
private func flattenedPoints(_ path: CGPath, samplesPerCurve: Int = 64) -> [CGPoint] {
    var pts: [CGPoint] = []
    var start = CGPoint.zero
    path.applyWithBlock { el in
        let e = el.pointee
        switch e.type {
        case .moveToPoint:
            pts.append(e.points[0]); start = e.points[0]
        case .addLineToPoint:
            pts.append(e.points[0])
        case .addQuadCurveToPoint:
            let p0 = pts.last ?? .zero, c = e.points[0], p1 = e.points[1]
            for i in 1...samplesPerCurve {
                let t = CGFloat(i) / CGFloat(samplesPerCurve), mt = 1 - t
                pts.append(CGPoint(x: mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x,
                                   y: mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y))
            }
        case .addCurveToPoint:
            let p0 = pts.last ?? .zero, c1 = e.points[0], c2 = e.points[1], p1 = e.points[2]
            for i in 1...samplesPerCurve {
                let t = CGFloat(i) / CGFloat(samplesPerCurve), mt = 1 - t
                pts.append(CGPoint(
                    x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p1.x,
                    y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p1.y))
            }
        case .closeSubpath:
            pts.append(start)
        @unknown default:
            break
        }
    }
    return pts
}

private func flattenedLength(_ path: CGPath) -> CGFloat {
    let pts = flattenedPoints(path)
    var total: CGFloat = 0
    for i in 1..<pts.count { total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) }
    return total
}

private func point(along path: CGPath, atFraction f: CGFloat) -> CGPoint {
    let pts = flattenedPoints(path)
    var remaining = f * flattenedLength(path)
    for i in 1..<pts.count {
        let d = hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
        if remaining <= d, d > 0 {
            let t = remaining / d
            return CGPoint(x: pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t,
                           y: pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t)
        }
        remaining -= d
    }
    return pts.last ?? .zero
}
