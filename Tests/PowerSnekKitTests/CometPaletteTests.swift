import XCTest
@testable import PowerSnekKit

final class CometPaletteTests: XCTestCase {
    // The reference implementation's base green.
    private let referenceGreen = HexColor.nsColor(fromHex: "#2BD46E")!

    private func assertClose(_ color: NSColor, toHex hex: String, tolerance: CGFloat,
                             file: StaticString = #filePath, line: UInt = #line) {
        let a = color.usingColorSpace(.sRGB)!
        let b = HexColor.nsColor(fromHex: hex)!.usingColorSpace(.sRGB)!
        XCTAssertEqual(a.redComponent, b.redComponent, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(a.greenComponent, b.greenComponent, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(a.blueComponent, b.blueComponent, accuracy: tolerance, file: file, line: line)
    }

    func test_palette_matchesReferenceGreens() {
        let p = CometPalette(base: referenceGreen)
        assertClose(p.bright, toHex: "#5BEF96", tolerance: 0.06)
        assertClose(p.tail, toHex: "#149C55", tolerance: 0.06)   // rgb(20,156,85)
        assertClose(p.rimCore, toHex: "#D9FFE9", tolerance: 0.08)
    }

    func test_palette_brightIsBrighterAndTailIsDarker() {
        let p = CometPalette(base: referenceGreen)
        let base = p.base.usingColorSpace(.sRGB)!
        let bright = p.bright.usingColorSpace(.sRGB)!
        let tail = p.tail.usingColorSpace(.sRGB)!
        XCTAssertGreaterThan(bright.brightnessComponent, base.brightnessComponent)
        XCTAssertLessThan(tail.brightnessComponent, base.brightnessComponent)
    }

    func test_trailProfile_countWidthsAndAlphasTaper() {
        let profile = CometPalette(base: referenceGreen).trailProfile()
        XCTAssertEqual(profile.count, 24)
        for i in 1..<profile.count {
            XCTAssertLessThan(profile[i].width, profile[i - 1].width)
            XCTAssertLessThan(profile[i].alpha, profile[i - 1].alpha)
        }
        XCTAssertEqual(profile[0].width, 20 - 17.5 * pow(0.5 / 24, 0.9), accuracy: 1e-6)
        XCTAssertEqual(profile[0].alpha, pow(1 - 0.5 / 24, 1.35), accuracy: 1e-6)
    }

    func test_trailProfile_headAdjacentSegmentIsNearWhite() {
        let profile = CometPalette(base: referenceGreen).trailProfile()
        let head = profile[0].color.usingColorSpace(.sRGB)!
        XCTAssertGreaterThan(head.redComponent, 0.85)
        XCTAssertGreaterThan(head.greenComponent, 0.85)
        XCTAssertGreaterThan(head.blueComponent, 0.85)
    }
}
