# PowerSnek Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu bar app that sweeps a glowing green "comet" around every connected display's perimeter — tracing the notch on the built-in screen — the instant a charger is connected.

**Architecture:** A SwiftUI menu bar agent (`MenuBarExtra` + `Settings`) drives AppKit/Core Animation overlay windows. Pure, testable logic (power-transition decision, perimeter path geometry, settings persistence, color conversion) lives in a `PowerSnekKit` framework with XCTest unit tests; the app target contains the IOKit power listener, overlay windows, Core Animation comet, and UI. The effect is a one-shot: overlay windows are created on plug-in and torn down after the fade, so nothing persists at rest.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Core Animation (QuartzCore), IOKit power sources (`IOKit.ps`), ServiceManagement (`SMAppService`), XcodeGen (project generation), XCTest.

## Global Constraints

- **Platform:** macOS 26 (Tahoe), Apple Silicon. Deployment target `macos 14.0` minimum floor (SettingsLink, NSColor(Color), SMAppService all require 13–14+); build/test on macOS 26.
- **App is an agent:** `LSUIElement = YES` (no Dock icon).
- **No special permissions:** must not require Accessibility or Screen Recording. Do not call any screen-capture API.
- **Fire condition:** animate ONLY on the `battery → AC` transition. Never on launch, wake, or unplug.
- **Zero persistent windows:** overlay windows are created per fire and destroyed after the animation completes.
- **Default comet color:** vivid green `#34FF6A`. Default laps: `2` (range 1–5). Default lap duration: `1.2` s (range 0.6–2.0).
- **App/bundle name:** `PowerSnek`. Bundle id: `com.powersnek.app` (adjust to your team if needed).
- **Frameworks split:** testable value/logic types go in `PowerSnekKit`; window/animation/IOKit/UI go in the `PowerSnek` app target.
- **TDD:** every pure-logic task writes the failing test first. Commit after every green step.

---

## File Structure

```
PowerSnek/
  project.yml                                  # XcodeGen spec (targets + schemes)
  Sources/
    PowerSnekKit/                              # framework — pure/testable
      PowerState.swift                         # PowerState enum + shouldFire
      HexColor.swift                           # hex <-> NSColor
      SettingsStore.swift                      # UserDefaults-backed ObservableObject
      PerimeterPathBuilder.swift               # NotchInput, ScreenOutlineInput, buildPath, makeNotchInput
      ScreenGeometry.swift                     # NSScreen -> ScreenOutlineInput (live reads)
    PowerSnek/                                 # app target
      PowerSnekApp.swift                       # @main App + AppDelegate + AppEnvironment
      AppController.swift                      # orchestration + debounce + test command
      PowerMonitor.swift                       # IOKit power-source listener
      Overlay/CometOverlayWindow.swift         # transparent click-through NSWindow
      Overlay/CometAnimator.swift              # lineDashPhase comet + glow + fade
      Settings/LoginItemManager.swift          # SMAppService wrapper
      Settings/SettingsView.swift              # SwiftUI settings form
      Resources/Info.plist                     # LSUIElement
      Resources/Assets.xcassets                # app icon (placeholder ok)
  Tests/
    PowerSnekKitTests/
      PowerStateTests.swift
      HexColorTests.swift
      SettingsStoreTests.swift
      PerimeterPathBuilderTests.swift
  docs/superpowers/specs/2026-06-23-powersnek-design.md
  docs/superpowers/plans/2026-06-23-powersnek.md
```

---

## Task 1: Project scaffold (XcodeGen + framework + app + tests)

**Files:**
- Create: `project.yml`
- Create: `Sources/PowerSnek/PowerSnekApp.swift` (minimal)
- Create: `Sources/PowerSnek/Resources/Info.plist`
- Create: `Sources/PowerSnekKit/PowerState.swift` (placeholder so framework compiles)
- Create: `Tests/PowerSnekKitTests/PowerStateTests.swift` (placeholder)

**Interfaces:**
- Produces: a buildable Xcode project with three targets (`PowerSnekKit` framework, `PowerSnek` app, `PowerSnekKitTests`) and a `PowerSnek` scheme whose test action runs `PowerSnekKitTests`.

- [ ] **Step 1: Ensure XcodeGen is installed**

Run: `which xcodegen || brew install xcodegen`
Expected: a path to `xcodegen`, or Homebrew installs it.

- [ ] **Step 2: Write `project.yml`**

```yaml
name: PowerSnek
options:
  bundleIdPrefix: com.powersnek
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  PowerSnekKit:
    type: framework
    platform: macOS
    sources:
      - Sources/PowerSnekKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.powersnek.kit
  PowerSnek:
    type: application
    platform: macOS
    sources:
      - Sources/PowerSnek
    dependencies:
      - target: PowerSnekKit
        embed: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.powersnek.app
        INFOPLIST_FILE: Sources/PowerSnek/Resources/Info.plist
        ENABLE_HARDENED_RUNTIME: YES
  PowerSnekKitTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests/PowerSnekKitTests
    dependencies:
      - target: PowerSnekKit
schemes:
  PowerSnek:
    build:
      targets:
        PowerSnek: all
        PowerSnekKit: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - PowerSnekKitTests
```

- [ ] **Step 3: Write `Sources/PowerSnek/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>PowerSnek</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: Write minimal `Sources/PowerSnek/PowerSnekApp.swift`**

```swift
import SwiftUI

@main
struct PowerSnekApp: App {
    var body: some Scene {
        MenuBarExtra("PowerSnek", systemImage: "bolt.fill") {
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
        }
    }
}
```

- [ ] **Step 5: Write placeholder `Sources/PowerSnekKit/PowerState.swift`**

```swift
public enum PowerState: Equatable {
    case ac
    case battery
    case unknown
}
```

- [ ] **Step 6: Write placeholder `Tests/PowerSnekKitTests/PowerStateTests.swift`**

```swift
import XCTest
@testable import PowerSnekKit

final class PowerStateTests: XCTestCase {
    func test_states_areDistinct() {
        XCTAssertNotEqual(PowerState.ac, PowerState.battery)
    }
}
```

- [ ] **Step 7: Generate the project**

Run: `cd /Users/saiguy/Documents/programming/PowerSnek && xcodegen generate`
Expected: `Created project at PowerSnek.xcodeproj`.

- [ ] **Step 8: Build the app**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Run the unit tests**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **` (1 test passes).

- [ ] **Step 10: Launch the app and confirm a menu bar item appears with no Dock icon**

Run: `open build/Build/Products/Debug/PowerSnek.app`
Expected: a `bolt.fill` icon appears in the menu bar; no Dock icon. Quit it from its menu afterward.

- [ ] **Step 11: Commit**

```bash
git add project.yml Sources Tests .gitignore
git commit -m "chore: scaffold PowerSnek (XcodeGen, framework, app, tests)"
```

> Note: `PowerSnek.xcodeproj` is generated by XcodeGen and should stay gitignored. Add `PowerSnek.xcodeproj/` to `.gitignore` if not already covered.

---

## Task 2: PowerState transition logic (`shouldFire`)

**Files:**
- Modify: `Sources/PowerSnekKit/PowerState.swift`
- Modify: `Tests/PowerSnekKitTests/PowerStateTests.swift`

**Interfaces:**
- Produces: `PowerState.shouldFire(previous: PowerState, current: PowerState) -> Bool` — `true` only for `battery → ac`. Consumed by `PowerMonitor` (Task 7).

- [ ] **Step 1: Write failing tests**

Replace the contents of `Tests/PowerSnekKitTests/PowerStateTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: FAIL — `shouldFire` is not a member of `PowerState`.

- [ ] **Step 3: Implement `shouldFire`**

Replace `Sources/PowerSnekKit/PowerState.swift`:

```swift
public enum PowerState: Equatable {
    case ac
    case battery
    case unknown

    /// Fire the celebration only on the unplugged -> plugged transition.
    public static func shouldFire(previous: PowerState, current: PowerState) -> Bool {
        previous == .battery && current == .ac
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/PowerState.swift Tests/PowerSnekKitTests/PowerStateTests.swift
git commit -m "feat: power-state shouldFire transition logic"
```

---

## Task 3: Hex <-> NSColor conversion

**Files:**
- Create: `Sources/PowerSnekKit/HexColor.swift`
- Create: `Tests/PowerSnekKitTests/HexColorTests.swift`

**Interfaces:**
- Produces: `HexColor.nsColor(fromHex: String) -> NSColor?` and `HexColor.hex(from: NSColor) -> String`. Consumed by `SettingsView` (Task 12) and `AppController` (Task 10).

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: FAIL — no type `HexColor`.

- [ ] **Step 3: Implement `HexColor`**

```swift
import AppKit

public enum HexColor {
    public static func nsColor(fromHex hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    public static func hex(from color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/HexColor.swift Tests/PowerSnekKitTests/HexColorTests.swift
git commit -m "feat: hex <-> NSColor conversion"
```

---

## Task 4: SettingsStore (UserDefaults persistence)

**Files:**
- Create: `Sources/PowerSnekKit/SettingsStore.swift`
- Create: `Tests/PowerSnekKitTests/SettingsStoreTests.swift`

**Interfaces:**
- Produces: `SettingsStore: ObservableObject` with `init(defaults: UserDefaults = .standard)` and published vars `effectEnabled: Bool`, `cometColorHex: String`, `lapCount: Int`, `lapDuration: Double`; static `defaultColorHex = "#34FF6A"`. Consumed by `AppController` (Task 10), `SettingsView` (Task 12), `AppEnvironment` (Task 11).
- Note: launch-at-login is NOT in this store — it reflects `SMAppService` status via `LoginItemManager` (Task 12).

- [ ] **Step 1: Write failing tests**

```swift
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
        XCTAssertEqual(s.lapDuration, 1.2, accuracy: 0.0001)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: FAIL — no type `SettingsStore`.

- [ ] **Step 3: Implement `SettingsStore`**

```swift
import Foundation
import Combine

public final class SettingsStore: ObservableObject {
    public static let defaultColorHex = "#34FF6A"

    private enum Key {
        static let enabled = "effectEnabled"
        static let color = "cometColorHex"
        static let laps = "lapCount"
        static let duration = "lapDuration"
    }

    private let defaults: UserDefaults

    @Published public var effectEnabled: Bool { didSet { defaults.set(effectEnabled, forKey: Key.enabled) } }
    @Published public var cometColorHex: String { didSet { defaults.set(cometColorHex, forKey: Key.color) } }
    @Published public var lapCount: Int { didSet { defaults.set(lapCount, forKey: Key.laps) } }
    @Published public var lapDuration: Double { didSet { defaults.set(lapDuration, forKey: Key.duration) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.color: SettingsStore.defaultColorHex,
            Key.laps: 2,
            Key.duration: 1.2,
        ])
        self.effectEnabled = defaults.bool(forKey: Key.enabled)
        self.cometColorHex = defaults.string(forKey: Key.color) ?? SettingsStore.defaultColorHex
        self.lapCount = defaults.integer(forKey: Key.laps)
        self.lapDuration = defaults.double(forKey: Key.duration)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/SettingsStore.swift Tests/PowerSnekKitTests/SettingsStoreTests.swift
git commit -m "feat: UserDefaults-backed SettingsStore"
```

---

## Task 5: PerimeterPathBuilder (notch geometry + outline path)

**Files:**
- Create: `Sources/PowerSnekKit/PerimeterPathBuilder.swift`
- Create: `Tests/PowerSnekKitTests/PerimeterPathBuilderTests.swift`

**Interfaces:**
- Produces:
  - `struct NotchInput: Equatable { left, right, depth, innerCornerRadius: CGFloat }`
  - `struct ScreenOutlineInput: Equatable { width, height, cornerRadius, inset: CGFloat; notch: NotchInput? }`
  - `PerimeterPathBuilder.makeNotchInput(frameMinX:auxLeftMaxX:auxRightMinX:safeAreaTop:innerCornerRadius:) -> NotchInput?`
  - `PerimeterPathBuilder.buildPath(_ input: ScreenOutlineInput) -> CGPath`
- Consumed by `ScreenGeometry` (Task 6) and `AppController` (Task 10). Coordinates are view-local with origin at bottom-left (non-flipped), y increasing upward.

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: FAIL — no type `PerimeterPathBuilder`.

- [ ] **Step 3: Implement `PerimeterPathBuilder`**

```swift
import CoreGraphics

public struct NotchInput: Equatable {
    public let left: CGFloat
    public let right: CGFloat
    public let depth: CGFloat
    public let innerCornerRadius: CGFloat
    public init(left: CGFloat, right: CGFloat, depth: CGFloat, innerCornerRadius: CGFloat) {
        self.left = left; self.right = right; self.depth = depth; self.innerCornerRadius = innerCornerRadius
    }
}

public struct ScreenOutlineInput: Equatable {
    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat
    public let inset: CGFloat
    public let notch: NotchInput?
    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat, inset: CGFloat, notch: NotchInput?) {
        self.width = width; self.height = height; self.cornerRadius = cornerRadius; self.inset = inset; self.notch = notch
    }
}

public enum PerimeterPathBuilder {

    /// Converts screen-space notch geometry into view-local NotchInput.
    /// Returns nil when there is no notch (no top safe-area inset or invalid span).
    public static func makeNotchInput(frameMinX: CGFloat,
                                      auxLeftMaxX: CGFloat,
                                      auxRightMinX: CGFloat,
                                      safeAreaTop: CGFloat,
                                      innerCornerRadius: CGFloat) -> NotchInput? {
        guard safeAreaTop > 0 else { return nil }
        let left = auxLeftMaxX - frameMinX
        let right = auxRightMinX - frameMinX
        guard right > left else { return nil }
        return NotchInput(left: left, right: right, depth: safeAreaTop, innerCornerRadius: innerCornerRadius)
    }

    /// Builds the closed perimeter outline. View-local coords, origin bottom-left, y up.
    public static func buildPath(_ input: ScreenOutlineInput) -> CGPath {
        let left = input.inset
        let right = input.width - input.inset
        let bottom = input.inset
        let top = input.height - input.inset
        let r = max(0, min(input.cornerRadius, (right - left) / 2, (top - bottom) / 2))

        let path = CGMutablePath()

        guard let notch = input.notch else {
            path.addRoundedRect(in: CGRect(x: left, y: bottom, width: right - left, height: top - bottom),
                                cornerWidth: r, cornerHeight: r)
            return path
        }

        let ic = max(0, min(notch.innerCornerRadius, (notch.right - notch.left) / 2, notch.depth / 2))
        let notchBottom = top - notch.depth

        // Top edge, left of notch
        path.move(to: CGPoint(x: left + r, y: top))
        path.addLine(to: CGPoint(x: notch.left, y: top))
        // Down left wall, rounded bottom-left inner corner
        path.addLine(to: CGPoint(x: notch.left, y: notchBottom + ic))
        path.addArc(tangent1End: CGPoint(x: notch.left, y: notchBottom),
                    tangent2End: CGPoint(x: notch.left + ic, y: notchBottom), radius: ic)
        // Across notch bottom, rounded bottom-right inner corner
        path.addLine(to: CGPoint(x: notch.right - ic, y: notchBottom))
        path.addArc(tangent1End: CGPoint(x: notch.right, y: notchBottom),
                    tangent2End: CGPoint(x: notch.right, y: notchBottom + ic), radius: ic)
        // Up right wall, continue top edge
        path.addLine(to: CGPoint(x: notch.right, y: top))
        path.addLine(to: CGPoint(x: right - r, y: top))
        // Outer corners (tangent arcs), clockwise: TR, BR, BL, TL
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: bottom), radius: r)
        path.addLine(to: CGPoint(x: right, y: bottom + r))
        path.addArc(tangent1End: CGPoint(x: right, y: bottom), tangent2End: CGPoint(x: left, y: bottom), radius: r)
        path.addLine(to: CGPoint(x: left + r, y: bottom))
        path.addArc(tangent1End: CGPoint(x: left, y: bottom), tangent2End: CGPoint(x: left, y: top), radius: r)
        path.addLine(to: CGPoint(x: left, y: top - r))
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: right, y: top), radius: r)
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS'`
Expected: `** TEST SUCCEEDED **`.

> If `test_buildPath_notchPointIsOutside` fails, confirm the path winding makes the notch a true cut-out; `CGPath.contains` defaults to the non-zero winding rule, which is correct for this single non-self-intersecting outline.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnekKit/PerimeterPathBuilder.swift Tests/PowerSnekKitTests/PerimeterPathBuilderTests.swift
git commit -m "feat: perimeter path builder with notch cut-out"
```

---

## Task 6: ScreenGeometry (live NSScreen -> ScreenOutlineInput)

**Files:**
- Create: `Sources/PowerSnekKit/ScreenGeometry.swift`

**Interfaces:**
- Consumes: `PerimeterPathBuilder.makeNotchInput`, `ScreenOutlineInput`, `NotchInput`.
- Produces: `ScreenGeometry.outlineInput(for: NSScreen, inset:builtInFallbackRadius:notchInnerRadius:) -> ScreenOutlineInput` and `ScreenGeometry.cornerRadius(for: NSScreen, fallback:) -> CGFloat`. Consumed by `AppController` (Task 10).
- This task touches live `NSScreen` (impure), so it has no unit test; correctness is verified end-to-end in Task 11.

- [ ] **Step 1: Implement `ScreenGeometry`**

```swift
import AppKit

public enum ScreenGeometry {
    /// Reads the display's corner radius via private KVC, falling back to a constant.
    public static func cornerRadius(for screen: NSScreen, fallback: CGFloat) -> CGFloat {
        if let n = screen.value(forKey: "_cornerRadius") as? NSNumber {
            let v = CGFloat(n.doubleValue)
            if v > 0 { return v }
        }
        return fallback
    }

    public static func outlineInput(for screen: NSScreen,
                                    inset: CGFloat,
                                    builtInFallbackRadius: CGFloat,
                                    notchInnerRadius: CGFloat) -> ScreenOutlineInput {
        let frame = screen.frame
        let hasNotchInset = screen.safeAreaInsets.top > 0
        let radius = cornerRadius(for: screen, fallback: hasNotchInset ? builtInFallbackRadius : 0)

        var notch: NotchInput? = nil
        if let l = screen.auxiliaryTopLeftArea, let rgt = screen.auxiliaryTopRightArea {
            notch = PerimeterPathBuilder.makeNotchInput(
                frameMinX: frame.minX,
                auxLeftMaxX: l.maxX,
                auxRightMinX: rgt.minX,
                safeAreaTop: screen.safeAreaInsets.top,
                innerCornerRadius: notchInnerRadius)
        }

        return ScreenOutlineInput(width: frame.width,
                                  height: frame.height,
                                  cornerRadius: radius,
                                  inset: inset,
                                  notch: notch)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/PowerSnekKit/ScreenGeometry.swift
git commit -m "feat: ScreenGeometry adapter (NSScreen -> outline input)"
```

---

## Task 7: PowerMonitor (IOKit power-source listener)

**Files:**
- Create: `Sources/PowerSnek/PowerMonitor.swift`

**Interfaces:**
- Consumes: `PowerState`, `PowerState.shouldFire` (from `PowerSnekKit`).
- Produces: `PowerMonitor` class with `init()`, `start(onPlugIn: @escaping () -> Void)`, `stop()`, and `static func currentState() -> PowerState`. Consumed by `AppController` (Task 10).
- Uses IOKit power-source notifications. No permissions required. Verified manually in Task 11.

- [ ] **Step 1: Implement `PowerMonitor`**

```swift
import Foundation
import IOKit.ps
import PowerSnekKit

public final class PowerMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var previous: PowerState = .unknown
    private var onPlugIn: (() -> Void)?

    public init() {}

    public static func currentState() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return .unknown }
        guard let typeCF = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else { return .unknown }
        let type = typeCF as String
        switch type {
        case kIOPMACPowerKey: return .ac
        case kIOPMBatteryPowerKey: return .battery
        default: return .unknown
        }
    }

    public func start(onPlugIn: @escaping () -> Void) {
        self.onPlugIn = onPlugIn
        self.previous = PowerMonitor.currentState()   // seed silently; never fires on launch

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handleChange()
        }, context)?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func handleChange() {
        let current = PowerMonitor.currentState()
        if PowerState.shouldFire(previous: previous, current: current) {
            onPlugIn?()
        }
        previous = current
    }

    public func stop() {
        if let s = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .defaultMode)
            runLoopSource = nil
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/PowerSnek/PowerMonitor.swift
git commit -m "feat: IOKit PowerMonitor (battery->AC notifications)"
```

---

## Task 8: CometOverlayWindow (transparent click-through window)

**Files:**
- Create: `Sources/PowerSnek/Overlay/CometOverlayWindow.swift`

**Interfaces:**
- Produces: `CometOverlayWindow: NSWindow` with `init(screen: NSScreen)` and `let hostLayer: CALayer` (sized to the screen, ready for sublayers). Consumed by `AppController` (Task 10).

- [ ] **Step 1: Implement `CometOverlayWindow`**

```swift
import AppKit

public final class CometOverlayWindow: NSWindow {
    public let hostLayer = CALayer()

    public init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // fully click-through
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel())) // over menu bar + fullscreen
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        setFrame(screen.frame, display: false)

        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        if let root = view.layer {
            hostLayer.frame = view.bounds
            root.addSublayer(hostLayer)
        }
        contentView = view
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/PowerSnek/Overlay/CometOverlayWindow.swift
git commit -m "feat: transparent click-through overlay window"
```

---

## Task 9: CometAnimator (glowing comet + fade)

**Files:**
- Create: `Sources/PowerSnek/Overlay/CometAnimator.swift`

**Interfaces:**
- Produces: `CometAnimator.run(on host: CALayer, path: CGPath, color: NSColor, lapDuration: Double, lapCount: Int, completion: @escaping () -> Void)`. The comet is a `lineDashPhase`-driven dash that wraps the seam; two stacked stroke layers (wide dim glow + narrow bright core) give the neon look; after `lapCount` laps the host fades over 0.4 s and `completion` is called on the main queue. Consumed by `AppController` (Task 10).

- [ ] **Step 1: Implement `CometAnimator`**

```swift
import AppKit
import QuartzCore

public enum CometAnimator {

    public static func run(on host: CALayer,
                           path: CGPath,
                           color: NSColor,
                           lapDuration: Double,
                           lapCount: Int,
                           completion: @escaping () -> Void) {
        let cg = color.cgColor
        let brightCG = (NSColor.white.blended(withFraction: 0.5, of: color) ?? color).cgColor
        let length = pathLength(path)
        let comet = max(40, length * 0.10)         // visible comet length in points
        let dash: [NSNumber] = [NSNumber(value: Double(comet)),
                                NSNumber(value: Double(length - comet))]
        let laps = Float(max(1, lapCount))

        // Wide, dim glow layer
        let glow = CAShapeLayer()
        glow.path = path
        glow.fillColor = nil
        glow.strokeColor = cg
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.opacity = 0.55
        glow.lineDashPattern = dash
        glow.shadowColor = cg
        glow.shadowRadius = 14
        glow.shadowOpacity = 1
        glow.shadowOffset = .zero

        // Narrow, bright core layer
        let core = CAShapeLayer()
        core.path = path
        core.fillColor = nil
        core.strokeColor = brightCG
        core.lineWidth = 2.5
        core.lineCap = .round
        core.lineDashPattern = dash
        core.shadowColor = cg
        core.shadowRadius = 7
        core.shadowOpacity = 1
        core.shadowOffset = .zero

        host.addSublayer(glow)
        host.addSublayer(core)

        let phase = CABasicAnimation(keyPath: "lineDashPhase")
        phase.fromValue = 0
        phase.toValue = -length                    // negative advances forward along the path
        phase.duration = max(0.1, lapDuration)
        phase.repeatCount = laps
        phase.timingFunction = CAMediaTimingFunction(name: .linear)
        phase.isRemovedOnCompletion = false
        phase.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // Fade the whole host out, then report completion on the main queue.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.4
            fade.isRemovedOnCompletion = false
            fade.fillMode = .forwards
            CATransaction.begin()
            CATransaction.setCompletionBlock { DispatchQueue.main.async { completion() } }
            host.opacity = 0
            host.add(fade, forKey: "fade")
            CATransaction.commit()
        }
        glow.add(phase, forKey: "phase")
        core.add(phase, forKey: "phase")
        CATransaction.commit()
    }

    /// Approximate length of a CGPath by flattening curves.
    static func pathLength(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var current = CGPoint.zero
        var start = CGPoint.zero
        path.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]; start = current
            case .addLineToPoint:
                length += dist(current, e.points[0]); current = e.points[0]
            case .addQuadCurveToPoint:
                length += quadLength(current, e.points[0], e.points[1]); current = e.points[1]
            case .addCurveToPoint:
                length += cubicLength(current, e.points[0], e.points[1], e.points[2]); current = e.points[2]
            case .closeSubpath:
                length += dist(current, start); current = start
            @unknown default:
                break
            }
        }
        return length
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func quadLength(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, samples: Int = 16) -> CGFloat {
        var prev = p0, total: CGFloat = 0
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let mt = 1 - t
            let x = mt*mt*p0.x + 2*mt*t*c.x + t*t*p1.x
            let y = mt*mt*p0.y + 2*mt*t*c.y + t*t*p1.y
            let pt = CGPoint(x: x, y: y)
            total += dist(prev, pt); prev = pt
        }
        return total
    }

    private static func cubicLength(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, samples: Int = 16) -> CGFloat {
        var prev = p0, total: CGFloat = 0
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let mt = 1 - t
            let x = mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p1.x
            let y = mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p1.y
            let pt = CGPoint(x: x, y: y)
            total += dist(prev, pt); prev = pt
        }
        return total
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/PowerSnek/Overlay/CometAnimator.swift
git commit -m "feat: lineDashPhase comet animator with glow and fade"
```

---

## Task 10: AppController (orchestration + debounce + test command)

**Files:**
- Create: `Sources/PowerSnek/AppController.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `ScreenGeometry`, `PerimeterPathBuilder`, `HexColor` (from `PowerSnekKit`); `PowerMonitor`, `CometOverlayWindow`, `CometAnimator` (app target).
- Produces: `@MainActor final class AppController` with `init(settings: SettingsStore)`, `start()`, `fireAll()`, `runTestAnimation()`. Consumed by `AppEnvironment`/`AppDelegate` and `SettingsView` (Tasks 11–12).

- [ ] **Step 1: Implement `AppController`**

```swift
import AppKit
import PowerSnekKit

@MainActor
public final class AppController {
    private let settings: SettingsStore
    private let monitor = PowerMonitor()
    private var activeWindows: [CometOverlayWindow] = []
    private var animatingScreens: Set<CGDirectDisplayID> = []

    // Geometry tuning constants
    private let inset: CGFloat = 2
    private let builtInFallbackRadius: CGFloat = 12
    private let notchInnerRadius: CGFloat = 6

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func start() {
        monitor.start { [weak self] in
            Task { @MainActor in self?.fireAll() }
        }
    }

    public func fireAll() {
        guard settings.effectEnabled else { return }
        for screen in NSScreen.screens {
            fire(on: screen)
        }
    }

    public func runTestAnimation() {
        guard let screen = NSScreen.main else { return }
        fire(on: screen)
    }

    private func fire(on screen: NSScreen) {
        let id = screen.displayID
        guard !animatingScreens.contains(id) else { return }   // debounce
        animatingScreens.insert(id)

        let input = ScreenGeometry.outlineInput(for: screen,
                                                inset: inset,
                                                builtInFallbackRadius: builtInFallbackRadius,
                                                notchInnerRadius: notchInnerRadius)
        let path = PerimeterPathBuilder.buildPath(input)
        let color = HexColor.nsColor(fromHex: settings.cometColorHex) ?? NSColor.systemGreen

        let window = CometOverlayWindow(screen: screen)
        window.orderFrontRegardless()
        activeWindows.append(window)

        CometAnimator.run(on: window.hostLayer,
                          path: path,
                          color: color,
                          lapDuration: settings.lapDuration,
                          lapCount: settings.lapCount) { [weak self, weak window] in
            guard let self else { return }
            if let window {
                window.orderOut(nil)
                self.activeWindows.removeAll { $0 === window }
            }
            self.animatingScreens.remove(id)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Sources/PowerSnek/AppController.swift
git commit -m "feat: AppController orchestration with per-display debounce"
```

---

## Task 11: App shell (MenuBarExtra + wiring + first visible run)

**Files:**
- Modify: `Sources/PowerSnek/PowerSnekApp.swift`

**Interfaces:**
- Consumes: `SettingsStore` (PowerSnekKit), `AppController` (app), `SettingsView` (Task 12 — referenced here; create a stub if executing strictly in order, or do Task 12 first).
- Produces: `AppEnvironment.shared` (holds `settings` + `controller`), `AppDelegate`, and the `@main` `PowerSnekApp` scene graph. This is the first task that produces a fully visible, testable animation via "Test Animation".

> Execution note: this task references `SettingsView` from Task 12. If running tasks strictly in order, add a one-line stub `struct SettingsView: View { var body: some View { Text("Settings") } }` now and replace it in Task 12, OR execute Task 12 before this one. The reviewer should accept either ordering.

- [ ] **Step 1: Replace `PowerSnekApp.swift`**

```swift
import SwiftUI
import PowerSnekKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    let settings = SettingsStore()
    lazy var controller = AppController(settings: settings)
    private init() {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start listening for charger connect events.
        AppEnvironment.shared.controller.start()
    }
}

@main
struct PowerSnekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra("PowerSnek", systemImage: "bolt.fill") {
            Toggle("Enabled", isOn: $env.settings.effectEnabled)
            Button("Test Animation") { env.controller.runTestAnimation() }
            Divider()
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(env.settings)
        }
    }
}
```

- [ ] **Step 2: Build the app**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Launch and trigger the Test Animation**

Run: `open build/Build/Products/Debug/PowerSnek.app`
Then click the menu bar `bolt.fill` icon → **Test Animation**.
Expected: a green glowing comet sweeps the screen perimeter twice and traces the notch on the built-in display, then fades. No Dock icon; clicks pass through the overlay.

- [ ] **Step 4: Verify the real trigger (manual hardware check)**

With the app running and the Mac on battery, connect the charger.
Expected: the comet fires once. Unplugging does nothing. Relaunching while plugged in does nothing.

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnek/PowerSnekApp.swift
git commit -m "feat: app shell wiring (MenuBarExtra, AppController, power start)"
```

---

## Task 12: Settings UI (LoginItemManager + SettingsView)

**Files:**
- Create: `Sources/PowerSnek/Settings/LoginItemManager.swift`
- Create: `Sources/PowerSnek/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `HexColor` (PowerSnekKit); `AppEnvironment` (app).
- Produces: `LoginItemManager` (`static var isEnabled: Bool`, `static func setEnabled(_:)`) and `SettingsView` (the SwiftUI form referenced by Task 11).

- [ ] **Step 1: Implement `LoginItemManager`**

```swift
import ServiceManagement
import Foundation

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("PowerSnek login item error: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Implement `SettingsView`**

```swift
import SwiftUI
import PowerSnekKit

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var launchAtLogin = LoginItemManager.isEnabled

    private var cometColor: Binding<Color> {
        Binding(
            get: { Color(HexColor.nsColor(fromHex: settings.cometColorHex) ?? .systemGreen) },
            set: { settings.cometColorHex = HexColor.hex(from: NSColor($0)) }
        )
    }

    var body: some View {
        Form {
            Toggle("Enable effect", isOn: $settings.effectEnabled)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }

            ColorPicker("Comet color", selection: cometColor, supportsOpacity: false)

            Stepper("Laps: \(settings.lapCount)", value: $settings.lapCount, in: 1...5)

            VStack(alignment: .leading, spacing: 2) {
                Text("Speed")
                HStack {
                    Text("slower").font(.caption).foregroundStyle(.secondary)
                    // Higher lapDuration = slower; invert the slider so right = faster.
                    Slider(value: Binding(
                        get: { 2.6 - settings.lapDuration },     // maps 0.6..2.0 -> 2.0..0.6
                        set: { settings.lapDuration = 2.6 - $0 }
                    ), in: 0.6...2.0)
                    Text("faster").font(.caption).foregroundStyle(.secondary)
                }
            }

            Button("Preview") { AppEnvironment.shared.controller.runTestAnimation() }
        }
        .padding(20)
        .frame(width: 360)
    }
}
```

- [ ] **Step 3: Build the app**

Run: `xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Launch and exercise Settings**

Run: `open build/Build/Products/Debug/PowerSnek.app`
Then menu bar icon → **Settings…**. Verify:
- Toggling "Enable effect" off makes **Test Animation** do nothing; on restores it.
- **Preview** fires the comet.
- Changing **Comet color** changes the comet color on the next Preview.
- **Laps** changes the number of laps; **Speed** changes pace.
- **Launch at login** toggles without error (verify in System Settings → General → Login Items that "PowerSnek" appears/disappears).

- [ ] **Step 5: Commit**

```bash
git add Sources/PowerSnek/Settings/LoginItemManager.swift Sources/PowerSnek/Settings/SettingsView.swift
git commit -m "feat: settings window (color, laps, speed, launch at login, preview)"
```

---

## Task 13: Distribution (code-sign + notarize)

**Files:**
- Create: `scripts/release.sh`
- Modify: `project.yml` (set `DEVELOPMENT_TEAM` and signing for Release)

> This task is operational, not TDD. Requires your Apple Developer "Developer ID Application" certificate installed in the login keychain and a notarytool credential profile. Replace `TEAMID` and `you@example.com` with your values.

- [ ] **Step 1: Add your team + Developer ID signing to `project.yml`**

Add under the `PowerSnek` target `settings.base`:

```yaml
        DEVELOPMENT_TEAM: TEAMID
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "Developer ID Application"
        ENABLE_HARDENED_RUNTIME: YES
```

Then regenerate: `xcodegen generate`

- [ ] **Step 2: Store a notarytool credential profile (one time)**

Run:
```bash
xcrun notarytool store-credentials PowerSnekNotary \
  --apple-id "you@example.com" --team-id TEAMID
```
Expected: prompts for an app-specific password and saves the `PowerSnekNotary` profile.

- [ ] **Step 3: Write `scripts/release.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate

xcodebuild -project PowerSnek.xcodeproj -scheme PowerSnek \
  -configuration Release -derivedDataPath build archive \
  -archivePath build/PowerSnek.xcarchive

xcodebuild -exportArchive \
  -archivePath build/PowerSnek.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist scripts/ExportOptions.plist

APP="build/export/PowerSnek.app"
DMG="build/PowerSnek.dmg"
hdiutil create -volname "PowerSnek" -srcfolder "$APP" -ov -format UDZO "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile PowerSnekNotary --wait
xcrun stapler staple "$DMG"
echo "Notarized DMG ready: $DMG"
```

Also create `scripts/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TEAMID</string>
</dict>
</plist>
```

- [ ] **Step 4: Run the release script**

Run: `chmod +x scripts/release.sh && ./scripts/release.sh`
Expected: archive + export succeed; `notarytool submit ... --wait` returns `status: Accepted`; stapling succeeds; `build/PowerSnek.dmg` exists.

- [ ] **Step 5: Verify Gatekeeper acceptance**

Run: `spctl -a -vvv -t install build/PowerSnek.dmg` and `xcrun stapler validate build/PowerSnek.dmg`
Expected: `accepted` / `source=Notarized Developer ID` and `The validate action worked!`.

- [ ] **Step 6: Commit**

```bash
git add scripts/release.sh scripts/ExportOptions.plist project.yml
git commit -m "build: Developer ID signing + notarization release script"
```

---

## Self-Review (completed by plan author)

**Spec coverage:**
- Menu bar agent / LSUIElement → Task 1 (Info.plist) + Task 11 (MenuBarExtra). ✅
- PowerMonitor battery→AC, silent seed → Tasks 2, 7. ✅
- PerimeterPathBuilder with notch via public APIs → Tasks 5, 6. ✅
- One overlay window per display, click-through, created/destroyed per fire → Tasks 8, 10. ✅
- CometAnimator stacked strokes + glow + N laps + fade → Task 9. ✅
- Settings (enable, launch-at-login, color, laps, speed) + Preview → Tasks 4, 12. ✅
- All displays simultaneously, debounce → Task 10. ✅
- No-notch fallback, disabled effect, rapid plug/unplug, corner-radius fallback, no-permissions → Tasks 5/6/10 + Global Constraints. ✅
- Test command for visual iteration → Tasks 10, 11. ✅
- Distribution (Developer ID + notarized DMG) → Task 13. ✅
- Unit tests for path builder, power transition, settings, color → Tasks 2–5. ✅

**Placeholder scan:** Task 11 intentionally notes a `SettingsView` stub option for strict in-order execution; the real implementation is in Task 12. No "TBD"/"add error handling"/empty steps remain. ✅

**Type consistency:** `shouldFire(previous:current:)`, `buildPath(_:)`, `makeNotchInput(...)`, `outlineInput(for:inset:builtInFallbackRadius:notchInnerRadius:)`, `CometAnimator.run(on:path:color:lapDuration:lapCount:completion:)`, `AppController.runTestAnimation()`, `CometOverlayWindow(screen:).hostLayer`, `SettingsStore(defaults:)` — all defined once and consumed with matching signatures across tasks. ✅
