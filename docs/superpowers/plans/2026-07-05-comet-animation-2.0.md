# Comet Animation 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace PowerSnek's linear comet with the Comet 2.0 choreography: bottom-left clockwise launch, eased variable-speed sweep, deceleration into a landing on the notch, then a flash / rim-glow / breathing-pulse finale.

**Architecture:** Pure math and geometry (easing, trail profile, palette, outline with landing metrics) live in `PowerSnekKit` and are unit-tested. A rewritten `CometAnimator` in the app target drives per-frame layer updates from a `CADisplayLink`, exactly porting the reference implementation's formulas (documented in the spec: `docs/superpowers/specs/2026-07-05-comet-animation-2.0-design.md`).

**Tech Stack:** Swift 6, AppKit + Core Animation, XcodeGen, XCTest.

## Global Constraints

- macOS deployment target **14.0**; Swift 6; 4-space indent; explicit access control for all `PowerSnekKit` API.
- New/removed source files require `xcodegen generate` (never hand-edit `PowerSnek.xcodeproj`).
- Test method naming: `test_behavior_condition` style, in `Tests/PowerSnekKitTests`.
- Build: `xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` (append `-only-testing:PowerSnekKitTests/<Class>` for a single class).
- All reference dimensions (stroke widths, radii, margins, blurs) are in **reference units** calibrated to a 1600-wide screen; multiply by `scale = screenWidth / 1600` at render time.
- Commits: Conventional Commit subjects, e.g. `feat(kit): …`. Working directory is `/Users/saiguy/Documents/programming/funsaized/PowerSnek`, branch `main`.

---

### Task 1: CometMath — travel and finale math

**Files:**
- Create: `Sources/PowerSnekKit/CometMath.swift`
- Test: `Tests/PowerSnekKitTests/CometMathTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 2–4):
  - `CometMath.referenceScreenWidth: CGFloat`, `referenceNotchSize: CGSize`
  - `CometMath.trailSegmentCount: Int`, `trailBaseWidth/trailTaperWidth/headCoreWidth/headGlowWidth/rimHaloWidth/rimCoreWidth: CGFloat`, `headDashFraction: Double`, `trailHaloWidthRatio/trailHaloAlphaRatio: CGFloat`, blur constants, `finaleDuration: Double`
  - `CometMath.scale(forScreenWidth:) -> CGFloat`
  - `CometMath.clamp01(_:) / easedProgress(_:) / easeOutQuad(_:) -> Double`
  - `CometMath.throb(at:) -> Double`
  - `CometMath.trailLength(progress:total:) -> Double`
  - `CometMath.travelDuration(lapDuration:laps:landingFraction:) -> Double`
  - `FinaleState.at(_ u: Double) -> FinaleState` with `flashRadius/flashOpacity/rimFraction/fade/breath/glintRadius/glintOpacity: CGFloat`

- [ ] **Step 1: Write the failing tests**

Create `Tests/PowerSnekKitTests/CometMathTests.swift`:

```swift
import XCTest
@testable import PowerSnekKit

final class CometMathTests: XCTestCase {

    // Easing: 0.92·smootherstep + 0.08·linear
    func test_easedProgress_endpointsAndMidpoint() {
        XCTAssertEqual(CometMath.easedProgress(0), 0, accuracy: 1e-9)
        XCTAssertEqual(CometMath.easedProgress(1), 1, accuracy: 1e-9)
        XCTAssertEqual(CometMath.easedProgress(0.5), 0.5, accuracy: 1e-9)
    }

    func test_easedProgress_monotonicallyIncreasing() {
        var prev = -1.0
        for i in 0...100 {
            let v = CometMath.easedProgress(Double(i) / 100)
            XCTAssertGreaterThan(v, prev)
            prev = v
        }
    }

    func test_easedProgress_fastMiddleSlowEnds() {
        let dt = 0.01
        let launch = (CometMath.easedProgress(dt) - CometMath.easedProgress(0)) / dt
        let mid = (CometMath.easedProgress(0.5 + dt / 2) - CometMath.easedProgress(0.5 - dt / 2)) / dt
        let arrival = (CometMath.easedProgress(1) - CometMath.easedProgress(1 - dt)) / dt
        XCTAssertGreaterThan(mid, 1.5)     // sprints through the middle
        XCTAssertLessThan(launch, 0.2)     // gentle launch
        XCTAssertLessThan(arrival, 0.2)    // decelerating arrival
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

    // Finale envelopes
    func test_finale_startState() {
        let f = FinaleState.at(0)
        XCTAssertEqual(f.flashRadius, 12, accuracy: 1e-6)
        XCTAssertEqual(f.flashOpacity, 0.95, accuracy: 1e-6)
        XCTAssertEqual(f.rimFraction, 0, accuracy: 1e-6)
        XCTAssertEqual(f.fade, 1, accuracy: 1e-6)
        XCTAssertEqual(f.breath, 0, accuracy: 1e-6)
        XCTAssertEqual(f.glintRadius, 9, accuracy: 1e-6)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/CometMathTests 2>&1 | tail -20`
Expected: **build failure** — `cannot find 'CometMath' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/PowerSnekKit/CometMath.swift`:

```swift
import CoreGraphics
import Foundation

/// Pure math for the Comet 2.0 animation, ported from the reference
/// implementation (see docs/superpowers/specs/2026-07-05-comet-animation-2.0-design.md).
/// Width-like constants are in reference units calibrated to a 1600-wide
/// screen; multiply by `scale(forScreenWidth:)` before rendering.
public enum CometMath {

    public static let referenceScreenWidth: CGFloat = 1600
    public static let referenceNotchSize = CGSize(width: 173, height: 34)

    public static let trailSegmentCount = 24
    public static let trailMaxFraction: Double = 0.15
    public static let collapseFraction: Double = 0.3
    public static let finaleDuration: Double = 0.9
    /// Lap count the speed slider is calibrated against ("2 laps take
    /// `lapDuration` seconds").
    public static let calibrationLaps: Double = 2

    public static let trailBaseWidth: CGFloat = 20
    public static let trailTaperWidth: CGFloat = 17.5
    public static let trailHaloWidthRatio: CGFloat = 2.4
    public static let trailHaloAlphaRatio: CGFloat = 0.55
    public static let headCoreWidth: CGFloat = 17
    public static let headGlowWidth: CGFloat = 36
    public static let headDashFraction: Double = 0.0012
    public static let rimHaloWidth: CGFloat = 24
    public static let rimCoreWidth: CGFloat = 7.5

    public static let trailHaloBlur: CGFloat = 9
    public static let headGlowBlur: CGFloat = 7
    public static let rimHaloBlur: CGFloat = 8
    public static let flashBlur: CGFloat = 10
    public static let breathABlur: CGFloat = 26
    public static let breathBBlur: CGFloat = 14

    public static func scale(forScreenWidth width: CGFloat) -> CGFloat {
        width / referenceScreenWidth
    }

    public static func clamp01(_ u: Double) -> Double { min(max(u, 0), 1) }

    /// Travel easing: smootherstep blended with 8 % linear — slow launch,
    /// fast mid-sweep, decelerating arrival that never fully stalls.
    public static func easedProgress(_ u: Double) -> Double {
        let x = clamp01(u)
        return 0.92 * (x * x * x * (x * (x * 6 - 15) + 10)) + 0.08 * x
    }

    public static func easeOutQuad(_ u: Double) -> Double {
        let x = clamp01(u)
        return 1 - (1 - x) * (1 - x)
    }

    /// Head width multiplier while traveling (2.2 Hz, ±7 %).
    public static func throb(at t: Double) -> Double {
        1 + 0.07 * sin(t * 2 * .pi * 2.2)
    }

    /// Visible trail length (fraction of the perimeter) at eased progress
    /// `e` of `total`: grows from launch, collapses into the head over the
    /// last `collapseFraction` of the approach.
    public static func trailLength(progress e: Double, total: Double) -> Double {
        min(trailMaxFraction, e) * min(1, max(0, total - e) / collapseFraction)
    }

    /// Total sweep duration: scales with distance so the speed stays
    /// constant across lap counts, calibrated so the default 2-lap sweep
    /// takes `lapDuration` seconds.
    public static func travelDuration(lapDuration: Double, laps: Int, landingFraction: Double) -> Double {
        let distance = Double(max(1, laps)) + landingFraction
        return lapDuration * distance / (calibrationLaps + landingFraction)
    }
}

/// Envelope values for the landing finale at phase `u` (0…1 over
/// `CometMath.finaleDuration`). Radii are in reference units.
public struct FinaleState: Equatable {
    public let flashRadius: CGFloat
    public let flashOpacity: CGFloat
    /// Dash half-length drawn outward from the rim path's midpoint (0…0.5).
    public let rimFraction: CGFloat
    /// Shared late-phase fade factor (1 until u = 0.72, then → 0).
    public let fade: CGFloat
    /// Breathing-glow envelope (one sin pulse, 0…1…0).
    public let breath: CGFloat
    public let glintRadius: CGFloat
    public let glintOpacity: CGFloat

    public static func at(_ u: Double) -> FinaleState {
        let n = CometMath.clamp01(u / 0.16)
        let fade = u < 0.72 ? 1.0 : max(0, 1 - (u - 0.72) / 0.28)
        return FinaleState(
            flashRadius: CGFloat(12 + 80 * CometMath.easeOutQuad(n)),
            flashOpacity: CGFloat(0.95 * (1 - n)),
            rimFraction: CGFloat(CometMath.easeOutQuad(u / 0.32) * 0.5),
            fade: CGFloat(fade),
            breath: CGFloat(sin(.pi * CometMath.clamp01((u - 0.1) / 0.62))),
            glintRadius: CGFloat(max(2, 9 * (1 - u))),
            glintOpacity: CGFloat(1 - CometMath.easeOutQuad(u)))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/CometMathTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/CometMath.swift Tests/PowerSnekKitTests/CometMathTests.swift
git commit -m "feat(kit): add Comet 2.0 travel and finale math"
```

---

### Task 2: CometPalette — colors and trail profile

**Files:**
- Create: `Sources/PowerSnekKit/CometPalette.swift`
- Test: `Tests/PowerSnekKitTests/CometPaletteTests.swift`

**Interfaces:**
- Consumes: `CometMath.trailSegmentCount/trailBaseWidth/trailTaperWidth` (Task 1).
- Produces (used by Task 4):
  - `CometPalette(base: NSColor)` with `base/bright/tail/rimCore: NSColor`
  - `CometPalette.trailColor(at a: CGFloat) -> NSColor`
  - `CometPalette.trailProfile(segments: Int = CometMath.trailSegmentCount) -> [TrailSegment]`
  - `TrailSegment` with `width: CGFloat` (reference units), `alpha: CGFloat`, `color: NSColor`

- [ ] **Step 1: Write the failing tests**

Create `Tests/PowerSnekKitTests/CometPaletteTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/CometPaletteTests 2>&1 | tail -20`
Expected: **build failure** — `cannot find 'CometPalette' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/PowerSnekKit/CometPalette.swift`:

```swift
import AppKit

/// Comet colors derived from the user's chosen color. With the default
/// green these land within a few percent of the reference palette
/// (base #2BD46E, bright #5BEF96, tail rgb(20,156,85), rimCore #d9ffe9).
public struct CometPalette {
    public let base: NSColor
    public let bright: NSColor
    public let tail: NSColor
    public let rimCore: NSColor

    public init(base color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        base = c
        bright = Self.srgb(hue: h, saturation: min(1, s * 0.78), brightness: min(1, b * 1.13))
        tail = Self.srgb(hue: h, saturation: min(1, s * 1.09), brightness: b * 0.73)
        rimCore = Self.lerp(.white, c, 0.15)
    }

    /// White-hot head → bright → tail gradient at trail position `a`
    /// (0 = head, 1 = tail tip).
    public func trailColor(at a: CGFloat) -> NSColor {
        if a < 0.1 { return Self.lerp(.white, bright, a / 0.1) }
        return Self.lerp(bright, tail, (a - 0.1) / 0.9)
    }

    /// The tapered trail segments, head-adjacent first. Widths are in
    /// reference units.
    public func trailProfile(segments: Int = CometMath.trailSegmentCount) -> [TrailSegment] {
        (0..<segments).map { i in
            let a = (CGFloat(i) + 0.5) / CGFloat(segments)
            return TrailSegment(
                width: CometMath.trailBaseWidth - CometMath.trailTaperWidth * pow(a, 0.9),
                alpha: pow(1 - a, 1.35),
                color: trailColor(at: a))
        }
    }

    /// Component-wise sRGB interpolation (the reference lerps raw RGB).
    static func lerp(_ from: NSColor, _ to: NSColor, _ t: CGFloat) -> NSColor {
        let f = from.usingColorSpace(.sRGB) ?? from
        let g = to.usingColorSpace(.sRGB) ?? to
        let u = min(max(t, 0), 1)
        return NSColor(srgbRed: f.redComponent + (g.redComponent - f.redComponent) * u,
                       green: f.greenComponent + (g.greenComponent - f.greenComponent) * u,
                       blue: f.blueComponent + (g.blueComponent - f.blueComponent) * u,
                       alpha: 1)
    }

    /// HSV→RGB directly in sRGB, avoiding NSColor's calibrated-space
    /// hue initializer (which would shift the color).
    static func srgb(hue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat) -> NSColor {
        let i = floor(h * 6)
        let f = h * 6 - i
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

/// One stacked stroke of the comet's tail.
public struct TrailSegment {
    public let width: CGFloat
    public let alpha: CGFloat
    public let color: NSColor
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/CometPaletteTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/CometPalette.swift Tests/PowerSnekKitTests/CometPaletteTests.swift
git commit -m "feat(kit): add CometPalette trail color profile"
```

---

### Task 3: ScreenOutline — bottom-left clockwise path with landing metrics

**Files:**
- Modify: `Sources/PowerSnekKit/PerimeterPathBuilder.swift`
- Test: `Tests/PowerSnekKitTests/ScreenOutlineTests.swift` (new)
- Existing tests in `Tests/PowerSnekKitTests/PerimeterPathBuilderTests.swift` must keep passing unchanged (`buildPath` stays as a wrapper).

**Interfaces:**
- Consumes: `CometMath.referenceNotchSize`, `CometMath.scale(forScreenWidth:)` (Task 1); existing `ScreenOutlineInput`/`NotchInput`.
- Produces (used by Task 4):
  - `PerimeterPathBuilder.buildOutline(_ input: ScreenOutlineInput) -> ScreenOutline`
  - `ScreenOutline` with `path: CGPath`, `totalLength: CGFloat`, `landingFraction: CGFloat`, `landingPoint: CGPoint`, `rimPath: CGPath?`, `rimLength: CGFloat`, `notchRect: CGRect`, `hasNotch: Bool`

**Geometry contract (view-local coords, origin bottom-left, y up):** the path starts at `(left, bottom + r)` and runs **clockwise on screen**: up the left edge → top-left corner → top edge → (notch trace with all four corners rounded at radius `ic`, entry corners included, like the reference) → top edge → top-right corner → down the right edge → bottom-right corner → bottom edge → bottom-left corner → close. `landingPoint` is the notch-bottom center (or top-edge center without a notch); `landingFraction` is its analytic arc-length fraction. `rimPath` traces `(notchLeft − ic, top)` → entry corner → left wall → floor → right wall → exit corner → `(notchRight + ic, top)`, so its arc-length midpoint is the notch-bottom center. `notchRect` covers the notch (or a nominal `173·s × 34·s` top-center rect without one, `s = width/1600`).

- [ ] **Step 1: Write the failing tests**

Create `Tests/PowerSnekKitTests/ScreenOutlineTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/ScreenOutlineTests 2>&1 | tail -20`
Expected: **build failure** — `cannot find 'buildOutline'` / `cannot find type 'ScreenOutline'`.

- [ ] **Step 3: Write the implementation**

In `Sources/PowerSnekKit/PerimeterPathBuilder.swift`, keep `NotchInput`, `ScreenOutlineInput`, and `makeNotchInput` unchanged. Add the `ScreenOutline` struct and `PathTracer`, replace `buildPath`'s body with a wrapper, and add `buildOutline`. Full new content after the unchanged `makeNotchInput`:

```swift
/// The screen's traced outline plus the landing metrics the Comet 2.0
/// choreography needs. View-local coords, origin bottom-left, y up.
public struct ScreenOutline {
    /// Closed perimeter starting at the bottom-left corner, clockwise on
    /// screen (up the left edge first).
    public let path: CGPath
    public let totalLength: CGFloat
    /// Arc-length fraction where the comet lands (notch-bottom center, or
    /// top-edge center when there is no notch).
    public let landingFraction: CGFloat
    public let landingPoint: CGPoint
    /// The notch outline (entry corner → walls → floor → exit corner),
    /// same direction as the perimeter; nil when there is no notch. Its
    /// arc-length midpoint is the landing point.
    public let rimPath: CGPath?
    public let rimLength: CGFloat
    /// Notch bounds (or a nominal reference-notch-sized rect at top-center
    /// when there is no notch), for the finale's breathing glow.
    public let notchRect: CGRect
    public let hasNotch: Bool
}

/// Builds a CGPath while tracking analytic arc length. Lines and
/// quarter-circle tangent arcs only; callers guarantee each arc starts
/// exactly at the current point so no connecting line is inserted.
private struct PathTracer {
    let path = CGMutablePath()
    private(set) var length: CGFloat = 0

    mutating func move(to p: CGPoint) {
        path.move(to: p)
    }

    mutating func line(to p: CGPoint) {
        let c = path.currentPoint
        path.addLine(to: p)
        length += hypot(p.x - c.x, p.y - c.y)
    }

    mutating func corner(_ tangent: CGPoint, _ end: CGPoint, radius: CGFloat) {
        guard radius > 0 else {
            line(to: tangent)
            return
        }
        path.addArc(tangent1End: tangent, tangent2End: end, radius: radius)
        length += .pi * radius / 2
    }
}

public enum PerimeterPathBuilder {

    // ... makeNotchInput unchanged ...

    /// Compatibility wrapper; prefer `buildOutline`.
    public static func buildPath(_ input: ScreenOutlineInput) -> CGPath {
        buildOutline(input).path
    }

    /// Builds the closed perimeter outline with Comet 2.0 landing metrics.
    public static func buildOutline(_ input: ScreenOutlineInput) -> ScreenOutline {
        let left = input.inset
        let right = input.width - input.inset
        let bottom = input.inset
        let top = input.height - input.inset
        let r = max(0, min(input.cornerRadius, (right - left) / 2, (top - bottom) / 2))

        var t = PathTracer()
        t.move(to: CGPoint(x: left, y: bottom + r))
        t.line(to: CGPoint(x: left, y: top - r))
        t.corner(CGPoint(x: left, y: top), CGPoint(x: left + r, y: top), radius: r)

        let landingLength: CGFloat
        let landingPoint: CGPoint
        var rimPath: CGPath?
        var rimLength: CGFloat = 0
        let notchRect: CGRect

        if let notch = input.notch {
            // Clamp the notch floor so a pathological depth cannot drop
            // below the bottom edge and self-cross the outline.
            let notchBottom = max(bottom + r, top - notch.depth)
            let depth = top - notchBottom
            let ic = max(0, min(notch.innerCornerRadius, (notch.right - notch.left) / 2, depth / 2))
            let centerX = (notch.left + notch.right) / 2

            t.line(to: CGPoint(x: notch.left - ic, y: top))
            let lengthAtNotchEntry = t.length

            // The notch trace is shared by the perimeter and the finale's
            // rim path; all four corners are rounded, entry corners included.
            func traceNotch(into tracer: inout PathTracer) {
                tracer.corner(CGPoint(x: notch.left, y: top),
                              CGPoint(x: notch.left, y: top - ic), radius: ic)
                tracer.line(to: CGPoint(x: notch.left, y: notchBottom + ic))
                tracer.corner(CGPoint(x: notch.left, y: notchBottom),
                              CGPoint(x: notch.left + ic, y: notchBottom), radius: ic)
                tracer.line(to: CGPoint(x: notch.right - ic, y: notchBottom))
                tracer.corner(CGPoint(x: notch.right, y: notchBottom),
                              CGPoint(x: notch.right, y: notchBottom + ic), radius: ic)
                tracer.line(to: CGPoint(x: notch.right, y: top - ic))
                tracer.corner(CGPoint(x: notch.right, y: top),
                              CGPoint(x: notch.right + ic, y: top), radius: ic)
            }

            traceNotch(into: &t)

            var rim = PathTracer()
            rim.move(to: CGPoint(x: notch.left - ic, y: top))
            traceNotch(into: &rim)
            rimPath = rim.path
            rimLength = rim.length

            // Entry corner + left wall + floor corner + half the floor.
            landingLength = lengthAtNotchEntry
                + .pi * ic / 2
                + ((top - ic) - (notchBottom + ic))
                + .pi * ic / 2
                + (centerX - (notch.left + ic))
            landingPoint = CGPoint(x: centerX, y: notchBottom)
            notchRect = CGRect(x: notch.left, y: notchBottom,
                               width: notch.right - notch.left, height: depth)

            t.line(to: CGPoint(x: right - r, y: top))
        } else {
            let centerX = (left + right) / 2
            landingLength = t.length + (centerX - (left + r))
            landingPoint = CGPoint(x: centerX, y: top)
            let s = CometMath.scale(forScreenWidth: input.width)
            let nw = CometMath.referenceNotchSize.width * s
            let nh = CometMath.referenceNotchSize.height * s
            notchRect = CGRect(x: centerX - nw / 2, y: top - nh, width: nw, height: nh)

            t.line(to: CGPoint(x: right - r, y: top))
        }

        t.corner(CGPoint(x: right, y: top), CGPoint(x: right, y: top - r), radius: r)
        t.line(to: CGPoint(x: right, y: bottom + r))
        t.corner(CGPoint(x: right, y: bottom), CGPoint(x: right - r, y: bottom), radius: r)
        t.line(to: CGPoint(x: left + r, y: bottom))
        t.corner(CGPoint(x: left, y: bottom), CGPoint(x: left, y: bottom + r), radius: r)
        t.path.closeSubpath()

        return ScreenOutline(path: t.path,
                             totalLength: t.length,
                             landingFraction: t.length > 0 ? landingLength / t.length : 0,
                             landingPoint: landingPoint,
                             rimPath: rimPath,
                             rimLength: rimLength,
                             notchRect: notchRect,
                             hasNotch: input.notch != nil)
    }
}
```

Delete the old `buildPath` body (the manual notch/no-notch construction) — it is fully replaced by the wrapper + `buildOutline`.

- [ ] **Step 4: Run the new AND existing geometry tests**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:PowerSnekKitTests/ScreenOutlineTests -only-testing:PowerSnekKitTests/PerimeterPathBuilderTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` — including the pre-existing `PerimeterPathBuilderTests` (bounding box, notch cut-out, depth clamp) against the new path.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/PerimeterPathBuilder.swift Tests/PowerSnekKitTests/ScreenOutlineTests.swift
git commit -m "feat(kit): build screen outline with clockwise bottom-left start and landing metrics"
```

---

### Task 4: CometAnimator rewrite + wiring

**Files:**
- Rewrite: `Sources/PowerSnek/Overlay/CometAnimator.swift` (full replacement)
- Modify: `Sources/PowerSnek/AppController.swift:52-74` (fire method)
- Modify: `Sources/PowerSnekKit/SettingsStore.swift:30` (default 3.0 → 3.1)
- Modify: `Tests/PowerSnekKitTests/SettingsStoreTests.swift:17` (expectation 3.0 → 3.1)

**Interfaces:**
- Consumes: `ScreenOutline`, `buildOutline` (Task 3); `CometMath`, `FinaleState` (Task 1); `CometPalette`, `TrailSegment` (Task 2).
- Produces: `CometAnimator.run(on:displayLinkView:outline:color:laps:lapDuration:completion:)`; completion contract unchanged (always called exactly once).

- [ ] **Step 1: Update the SettingsStore default and its test (red → green in one step, it's one line each)**

`Sources/PowerSnekKit/SettingsStore.swift` line 30: `Key.duration: 3.0,` → `Key.duration: 3.1,`
`Tests/PowerSnekKitTests/SettingsStoreTests.swift` line 17: `XCTAssertEqual(s.lapDuration, 3.0, accuracy: 0.0001)` → `XCTAssertEqual(s.lapDuration, 3.1, accuracy: 0.0001)`

- [ ] **Step 2: Replace `Sources/PowerSnek/Overlay/CometAnimator.swift` entirely with:**

```swift
import AppKit
import PowerSnekKit
import QuartzCore

/// Drives the Comet 2.0 animation: a CADisplayLink ticks the reference
/// per-frame math — an eased sweep that launches from the bottom-left,
/// laps the screen clockwise, and decelerates into a landing on the
/// notch — then a flash / rim-glow / breathing-pulse finale.
@MainActor
public final class CometAnimator {

    /// Runs one comet on `host`. Calls `completion` exactly once, even if
    /// the display link never ticks (watchdog) or the path is degenerate.
    public static func run(on host: CALayer,
                           displayLinkView view: NSView,
                           outline: ScreenOutline,
                           color: NSColor,
                           laps: Int,
                           lapDuration: Double,
                           completion: @escaping @MainActor () -> Void) {
        guard outline.totalLength > 1 else { completion(); return }
        CometAnimator(host: host, view: view, outline: outline, color: color,
                      laps: laps, lapDuration: lapDuration, completion: completion).start()
    }

    // MARK: - State

    private let host: CALayer
    private let view: NSView
    private let outline: ScreenOutline
    private let scale: CGFloat
    private let palette: CometPalette
    private let segments: [TrailSegment]
    private let travel: Double
    private let totalDistance: Double
    private var completion: (@MainActor () -> Void)?

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?

    // Layers, bottom to top (matching the reference stacking order).
    private var trailHalos: [CAShapeLayer] = []
    private let trailHaloGroup = CALayer()
    private var trailCores: [CAShapeLayer] = []
    private let headGlowGroup = CALayer()
    private let headGlow = CAShapeLayer()
    private let headCore = CAShapeLayer()
    private let breathA = CALayer()
    private let breathB = CALayer()
    private let rimHaloGroup = CALayer()
    private var rimHalo: CAShapeLayer?
    private var rimCore: CAShapeLayer?
    private let flash = CALayer()
    private let glint = CALayer()

    private init(host: CALayer, view: NSView, outline: ScreenOutline, color: NSColor,
                 laps: Int, lapDuration: Double,
                 completion: @escaping @MainActor () -> Void) {
        self.host = host
        self.view = view
        self.outline = outline
        self.scale = CometMath.scale(forScreenWidth: view.bounds.width)
        self.palette = CometPalette(base: color)
        self.segments = palette.trailProfile()
        let frac = Double(outline.landingFraction)
        self.totalDistance = Double(max(1, laps)) + frac
        self.travel = CometMath.travelDuration(lapDuration: lapDuration,
                                               laps: laps, landingFraction: frac)
        self.completion = completion
    }

    private func start() {
        buildLayers()
        // The display link retains its target, keeping this animator alive
        // until finish() invalidates it.
        let dl = view.displayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
        // Watchdog: if the link stalls (display sleep/detach), still finish
        // so AppController's per-screen debounce is never stranded.
        let deadline = travel + CometMath.finaleDuration + 2
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(deadline))
            self?.finish()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let start = startTime ?? now
        startTime = start
        let t = now - start

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if t <= travel {
            renderTravel(t)
        } else if t <= travel + CometMath.finaleDuration {
            renderFinale((t - travel) / CometMath.finaleDuration)
        } else {
            CATransaction.commit()
            finish()
            return
        }
        CATransaction.commit()
    }

    private func finish() {
        guard let done = completion else { return }   // already finished
        completion = nil
        link?.invalidate()
        link = nil
        ([trailHaloGroup, headGlowGroup, rimHaloGroup, flash, glint, breathA, breathB]
            + trailCores + [headCore]).forEach { $0.removeFromSuperlayer() }
        rimCore?.removeFromSuperlayer()
        done()
    }

    // MARK: - Layer construction

    private func buildLayers() {
        func makeStroke(_ path: CGPath, _ color: NSColor, width: CGFloat,
                        cap: CAShapeLayerLineCap = .butt) -> CAShapeLayer {
            let s = CAShapeLayer()
            s.frame = host.bounds
            s.path = path
            s.fillColor = nil
            s.strokeColor = color.cgColor
            s.lineWidth = width
            s.lineCap = cap
            s.lineJoin = .round
            s.opacity = 0
            return s
        }
        func blur(_ layer: CALayer, radius: CGFloat) {
            layer.masksToBounds = false
            if let f = CIFilter(name: "CIGaussianBlur") {
                f.setValue(radius, forKey: kCIInputRadiusKey)
                layer.filters = [f]
            }
        }

        trailHaloGroup.frame = host.bounds
        blur(trailHaloGroup, radius: CometMath.trailHaloBlur * scale)
        for seg in segments {
            let halo = makeStroke(outline.path, palette.base,
                                  width: seg.width * CometMath.trailHaloWidthRatio * scale)
            trailHaloGroup.addSublayer(halo)
            trailHalos.append(halo)
        }
        host.addSublayer(trailHaloGroup)

        for seg in segments {
            let core = makeStroke(outline.path, seg.color, width: seg.width * scale)
            host.addSublayer(core)
            trailCores.append(core)
        }

        headGlowGroup.frame = host.bounds
        blur(headGlowGroup, radius: CometMath.headGlowBlur * scale)
        let glow = makeStroke(outline.path, palette.bright,
                              width: CometMath.headGlowWidth * scale, cap: .round)
        headGlowGroup.addSublayer(glow)
        host.addSublayer(headGlowGroup)
        configureHead(headGlow, from: glow)

        let core = makeStroke(outline.path, .white,
                              width: CometMath.headCoreWidth * scale, cap: .round)
        host.addSublayer(core)
        configureHead(headCore, from: core)

        breathA.backgroundColor = palette.base.cgColor
        breathA.cornerRadius = 30 * scale
        breathA.opacity = 0
        blur(breathA, radius: CometMath.breathABlur * scale)
        host.addSublayer(breathA)

        let nr = outline.notchRect
        let bw = nr.width + 16 * scale
        let bh = nr.height + 12 * scale
        breathB.backgroundColor = palette.bright.cgColor
        breathB.cornerRadius = 18 * scale
        breathB.frame = CGRect(x: nr.midX - bw / 2,
                               y: host.bounds.height - 2 * scale - bh,
                               width: bw, height: bh)
        breathB.opacity = 0
        blur(breathB, radius: CometMath.breathBBlur * scale)
        host.addSublayer(breathB)

        if let rim = outline.rimPath {
            rimHaloGroup.frame = host.bounds
            blur(rimHaloGroup, radius: CometMath.rimHaloBlur * scale)
            let halo = makeStroke(rim, palette.bright,
                                  width: CometMath.rimHaloWidth * scale, cap: .round)
            rimHaloGroup.addSublayer(halo)
            host.addSublayer(rimHaloGroup)
            rimHalo = halo
            let rcore = makeStroke(rim, palette.rimCore,
                                   width: CometMath.rimCoreWidth * scale, cap: .round)
            host.addSublayer(rcore)
            rimCore = rcore
        }

        flash.backgroundColor = NSColor.white.cgColor
        flash.opacity = 0
        blur(flash, radius: CometMath.flashBlur * scale)
        host.addSublayer(flash)

        glint.backgroundColor = NSColor.white.cgColor
        glint.opacity = 0
        host.addSublayer(glint)
    }

    /// The stored head layers are `let`s; copy a configured stroke's
    /// properties onto them so they live in the right group.
    private func configureHead(_ target: CAShapeLayer, from template: CAShapeLayer) {
        target.frame = template.frame
        target.path = template.path
        target.fillColor = nil
        target.strokeColor = template.strokeColor
        target.lineWidth = template.lineWidth
        target.lineCap = template.lineCap
        target.lineJoin = template.lineJoin
        target.opacity = 0
        template.superlayer.map { parent in
            parent.replaceSublayer(template, with: target)
        }
    }

    // MARK: - Per-frame rendering

    private func wrap(_ x: Double) -> Double {
        (x.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
    }

    /// Shows a dash segment covering [start, start+length] (perimeter
    /// fractions; wraps across the path start automatically).
    private func setDash(_ layer: CAShapeLayer, start: Double, length: Double,
                         width: CGFloat, opacity: Float) {
        let total = Double(outline.totalLength)
        let len = max(length, 1e-5) * total
        layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
        layer.lineDashPhase = -CGFloat(wrap(start) * total)
        layer.lineWidth = width
        layer.opacity = opacity
    }

    private func setCircle(_ layer: CALayer, center: CGPoint, radius: CGFloat) {
        layer.frame = CGRect(x: center.x - radius, y: center.y - radius,
                             width: radius * 2, height: radius * 2)
        layer.cornerRadius = radius
    }

    private func renderTravel(_ t: Double) {
        let e = totalDistance * CometMath.easedProgress(t / travel)
        let head = wrap(e)
        let trail = CometMath.trailLength(progress: e, total: totalDistance)
        let throb = CGFloat(CometMath.throb(at: t))
        let n = segments.count

        for i in 0..<n {
            let far = Double(i + 1) / Double(n) * trail
            let near = Double(i) / Double(n) * trail
            let seg = segments[i]
            setDash(trailCores[i], start: head - far, length: far - near,
                    width: seg.width * scale, opacity: Float(seg.alpha))
            setDash(trailHalos[i], start: head - far, length: far - near,
                    width: seg.width * CometMath.trailHaloWidthRatio * scale,
                    opacity: Float(seg.alpha * CometMath.trailHaloAlphaRatio))
        }
        setDash(headGlow, start: head - CometMath.headDashFraction,
                length: CometMath.headDashFraction,
                width: CometMath.headGlowWidth * scale * throb, opacity: 0.85)
        setDash(headCore, start: head - CometMath.headDashFraction,
                length: CometMath.headDashFraction,
                width: CometMath.headCoreWidth * scale * throb, opacity: 1)
        setFinaleHidden()
    }

    private func renderFinale(_ u: Double) {
        setTravelHidden()
        let f = FinaleState.at(u)

        setCircle(flash, center: outline.landingPoint, radius: f.flashRadius * scale)
        flash.opacity = Float(f.flashOpacity)

        if let rimHalo, let rimCore {
            let total = Double(outline.rimLength)
            let len = max(Double(f.rimFraction) * 2, 0.001) * total
            for layer in [rimHalo, rimCore] {
                layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
                layer.lineDashPhase = -CGFloat((0.5 - Double(f.rimFraction)) * total)
            }
            rimHalo.opacity = Float(0.85 * f.fade)
            rimCore.opacity = Float(f.fade)
        }

        let nr = outline.notchRect
        let o = f.breath
        let width = (nr.width + 60 * scale) * (1 + 0.2 * o)
        let height = (nr.height + 46 * scale) * (1 + 0.45 * o)
        // The reference centers the breath between the screen's top edge and
        // the notch floor, nudged 6 units toward the notch (mirrored: y-up).
        let centerY = (host.bounds.height + nr.minY) / 2 - 6 * scale
        breathA.frame = CGRect(x: nr.midX - width / 2, y: centerY - height / 2,
                               width: width, height: height)
        breathA.opacity = Float(0.6 * o * f.fade)
        breathB.opacity = Float(0.3 * o * f.fade)

        setCircle(glint, center: outline.landingPoint, radius: f.glintRadius * scale)
        glint.opacity = Float(f.glintOpacity)
    }

    private func setTravelHidden() {
        (trailCores + trailHalos + [headCore, headGlow]).forEach { $0.opacity = 0 }
    }

    private func setFinaleHidden() {
        var layers: [CALayer] = [flash, glint, breathA, breathB]
        rimHalo.map { layers.append($0) }
        rimCore.map { layers.append($0) }
        layers.forEach { $0.opacity = 0 }
    }
}
```

Note: `configureHead(_:from:)` exists because `headGlow`/`headCore` are stored `let` layers but must be built by the same `makeStroke` helper — if this feels awkward during implementation, an equally good alternative is making `headGlow`/`headCore` stored `var`s assigned directly from `makeStroke` and added to their groups; either is fine, keep whichever compiles cleanly.

- [ ] **Step 3: Update `AppController.fire(on:)` (lines 52–74) to:**

```swift
        let input = ScreenGeometry.outlineInput(for: screen,
                                                inset: inset,
                                                builtInFallbackRadius: builtInFallbackRadius,
                                                notchInnerRadius: notchInnerRadius)
        let outline = PerimeterPathBuilder.buildOutline(input)
        let color = HexColor.nsColor(fromHex: settings.cometColorHex) ?? NSColor.systemGreen

        let window = CometOverlayWindow(screen: screen)
        window.orderFrontRegardless()
        activeWindows.append(window)

        CometAnimator.run(on: window.hostLayer,
                          displayLinkView: window.contentView!,   // set in CometOverlayWindow.init
                          outline: outline,
                          color: color,
                          laps: settings.lapCount,
                          lapDuration: settings.lapDuration) { [weak self, weak window] in
            guard let self else { return }
            if let window {
                window.orderOut(nil)
                self.activeWindows.removeAll { $0 === window }
            }
            self.animatingScreens.remove(id)
        }
```

(The debounce comment above `animatingScreens.insert(id)` stays accurate: `run` still always calls completion — degenerate guard, normal finish, or watchdog.)

- [ ] **Step 4: Build and run the full test suite**

Run: `xcodegen generate && xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **` (all suites: CometMath, CometPalette, ScreenOutline, PerimeterPathBuilder, HexColor, PowerState, SettingsStore).

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnek/Overlay/CometAnimator.swift Sources/PowerSnek/AppController.swift \
        Sources/PowerSnekKit/SettingsStore.swift Tests/PowerSnekKitTests/SettingsStoreTests.swift
git commit -m "feat(overlay): rewrite comet with eased sweep and notch-landing finale"
```

---

### Task 5: Visual verification on real displays

**Files:**
- Possibly modify: `Sources/PowerSnek/Overlay/CometAnimator.swift` (blur fallback, only if needed)

**Interfaces:** none new.

- [ ] **Step 1: Build and launch the app, trigger the test animation**

```bash
xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
open build/Build/Products/Debug/PowerSnek.app
```

Then trigger the menu-bar **Test animation** command (ask the user to click it, or use the preview command if one is scriptable) and observe the built-in (notch) display.

- [ ] **Step 2: Verify the checklist against the reference choreography**

- Comet appears at the **bottom-left corner** and moves **up the left edge** (clockwise).
- Speed visibly **accelerates** through the middle laps and **decelerates** on approach.
- Trail is white-hot at the head fading through green to dark green, and **shrinks into the head** just before landing.
- Head lands exactly on the **notch center**; white **flash** pops; the **notch rim lights up** outward from its center; one **breathing glow pulse** swells around the notch; everything fades cleanly.
- Window disappears afterward and a second test run fires correctly (debounce released).
- On an external notchless display (if attached): landing + flash + breath at top-center, no rim trace.

- [ ] **Step 3 (contingency): if the CIGaussianBlur layer filters don't render** (halos/glows show as hard-edged strokes or invisible)

Replace the `blur(_:radius:)` helper's filter with shadow-based glow on the stroke layers themselves: in `makeStroke`, set `s.shadowColor = color.cgColor; s.shadowRadius = <the blur radius> * scale; s.shadowOpacity = 0.9; s.shadowOffset = .zero` for halo/glow layers, drop the group filters, and for `breathA`/`breathB`/`flash` swap the blurred solid layers for radial `CAGradientLayer`s (`type = .radial`, colors `[fill, fill.withAlphaComponent(0)]`, `startPoint/endPoint` centered). Re-run the visual checklist.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix(overlay): adjust comet glow rendering after visual verification"
```

(Skip if Step 3 wasn't needed and no changes were made.)
