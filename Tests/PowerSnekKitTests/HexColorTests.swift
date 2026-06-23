import XCTest
import AppKit
@testable import PowerSnekKit

final class HexColorTests: XCTestCase {
    func test_parsesSixDigitHexWithHash() {
        let c = HexColor.nsColor(fromHex: "#34FF6A")
        XCTAssertNotNil(c)
        let s = c!.usingColorSpace(.sRGB)!
        XCTAssertEqual(s.redComponent, 0x34/255.0, accuracy: 0.01)
        XCTAssertEqual(s.greenComponent, 1.0, accuracy: 0.01)
        XCTAssertEqual(s.blueComponent, 0x6A/255.0, accuracy: 0.01)
    }
    func test_parsesWithoutHash() {
        XCTAssertNotNil(HexColor.nsColor(fromHex: "34FF6A"))
    }
    func test_rejectsBadInput() {
        XCTAssertNil(HexColor.nsColor(fromHex: "xyz"))
        XCTAssertNil(HexColor.nsColor(fromHex: "#1234"))
    }
    func test_roundTrip() {
        let c = HexColor.nsColor(fromHex: "#34FF6A")!
        XCTAssertEqual(HexColor.hex(from: c), "#34FF6A")
    }
}
