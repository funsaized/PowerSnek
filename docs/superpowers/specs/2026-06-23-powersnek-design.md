# PowerSnek — Design Spec

**Date:** 2026-06-23
**Status:** Approved for planning
**Target:** macOS 26 (Tahoe), Apple Silicon. Built and tested on MacBook Air M4.

## 1. Summary

PowerSnek is a lightweight, native macOS menu bar app. The instant a charger
connects, a vivid green "comet" (an electric snake) sweeps around the perimeter
of every connected display, tracing the exact screen contour — including the
notch on the built-in display — for a configurable number of laps, then fades on
its own. It is a one-shot flourish, not a running animation: zero persistent
windows, GPU-composited, negligible battery and CPU cost.

## 2. Goals & non-goals

### Goals
- Fire a celebratory perimeter animation **only** on the unplugged → plugged
  transition.
- Trace the precise built-in display contour, detouring around the notch.
- Animate on **all** connected displays simultaneously (externals trace a plain
  rounded rectangle).
- Be genuinely lightweight: no persistent overlay, no per-frame CPU work, no
  special permissions (no Accessibility, no Screen Recording prompts).
- Ship as a polished, shareable, Developer ID-signed and notarized app.
- Let users customize: enable/disable, launch at login, comet color, lap count,
  speed.

### Non-goals (YAGNI)
- No animation on unplug, on launch, or on wake-from-sleep.
- No battery percentage UI, charging stats, or menu bar metering.
- No themes/presets beyond a single color + speed + laps.
- No Intel / pre-notch hardware optimization (graceful fallback only — see §7).
- No Mac App Store build in v1 (Developer ID + notarized DMG instead).

## 3. Architecture overview

SwiftUI app shell hosts a menu bar item and a Settings window. The visual
effect drops to AppKit + Core Animation, which is the right tool for borderless,
click-through, above-the-menu-bar overlay windows and GPU-composited stroke
animation.

```
                +------------------+
   IOKit  --->  |  PowerMonitor    |  emits .didPlugIn (battery -> AC only)
 power src      +------------------+
                          |
                          v
                +------------------+      reads NSScreen.screens
                |  AppController   |----> for each screen:
                +------------------+
                   |   ^                +-----------------------+
   enabled toggle  |   | Test command  |  CometOverlayWindow    | (1 per screen)
   from Settings   |   |               |   - borderless/clear   |
                   v   |               |   - click-through      |
                +------------------+   |   - shield level       |
                |  Settings (model)|   +-----------+-----------+
                |  @AppStorage     |               |
                +------------------+               v
                                       +-----------------------+
                                       | PerimeterPathBuilder  | (pure)
                                       |  frame+insets -> CGPath|
                                       +-----------+-----------+
                                                   |
                                                   v
                                       +-----------------------+
                                       |  CometAnimator        |
                                       |  layered CAShapeLayers |
                                       |  N laps + fade -> done |
                                       +-----------------------+
```

## 4. Components

Each component has one purpose, a defined interface, and is testable in
isolation.

### 4.1 `PowerMonitor`
- **Purpose:** Detect the moment the charger connects.
- **Implementation:** IOKit power sources. Register a run-loop source via
  `IOPSNotificationCreateRunLoopSource`; on callback, snapshot with
  `IOPSCopyPowerSourcesInfo()` and read the providing source type with
  `IOPSGetProvidingPowerSourceType()` → `"AC Power"` vs `"Battery Power"`.
- **Transition logic (extracted as a pure function for testing):**
  `shouldFire(previous:current:) -> Bool` returns `true` only when
  `previous == .battery && current == .ac`. Initial state is seeded from the
  current power source **without** firing, so launch/wake never trigger it.
- **Interface:** `start(onPlugIn: () -> Void)`, `stop()`. Holds the previous
  `PowerState` (`.ac` / `.battery` / `.unknown`).
- **Depends on:** IOKit (`IOKit.ps`). No permissions required.

### 4.2 `PerimeterPathBuilder`
- **Purpose:** Build the closed outline path for one screen. The signature
  feature and the most-tested unit.
- **Signature (pure):**
  `buildPath(frame: CGRect, safeAreaTopInset: CGFloat, auxiliaryTopLeft: CGRect?, auxiliaryTopRight: CGRect?, cornerRadius: CGFloat, inset: CGFloat) -> CGPath`
  All inputs are plain values, so tests construct them directly with no live
  screen.
- **Behavior:**
  - Coordinates are in the overlay view's local space (origin at the window's
    bottom-left; the window covers the full `screen.frame`).
  - Produces a rounded rectangle inset by `inset` points from the bezel.
  - **Notch present** (`safeAreaTopInset > 0` and both auxiliary rects given):
    notch horizontal span = `[auxiliaryTopLeft.maxX, auxiliaryTopRight.minX]`
    (converted to local space); notch depth = `safeAreaTopInset`. The top edge
    detours down around the notch with small rounded inner corners.
  - **No notch** (`safeAreaTopInset == 0` or auxiliary rects nil): plain rounded
    rectangle. Used for externals and any non-notch built-in.
  - The path direction is consistent (e.g., clockwise starting at a fixed
    anchor) so `strokeStart`/`strokeEnd` animate predictably.
- **Depends on:** Core Graphics only.

### 4.3 `ScreenGeometry` (thin adapter)
- **Purpose:** Read live `NSScreen` values and the private corner radius, then
  call `PerimeterPathBuilder`. Keeps all the "impure" screen reads in one small
  place so the builder stays pure.
- **Corner radius:** attempt `screen.value(forKey: "_cornerRadius")` (or the
  equivalent KVC/selector) inside a defensive wrapper. On nil/throw, fall back
  to a constant (built-in ≈ display corner radius constant; external = 0).
- **Notch reads:** `screen.safeAreaInsets.top`, `screen.auxiliaryTopLeftArea`,
  `screen.auxiliaryTopRightArea` (all public, macOS 12+).

### 4.4 `CometOverlayWindow`
- **Purpose:** A transparent canvas covering one entire display.
- **Configuration:**
  - `NSWindow(contentRect: screen.frame, styleMask: .borderless, ...)`
  - `level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))` — above
    the menu bar and notch region; also covers fullscreen apps.
  - `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`
  - `ignoresMouseEvents = true` (fully click-through)
  - `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`
  - Content view hosts the Core Animation layer tree.
- **Lifecycle:** created on-demand per fire, ordered front without activating the
  app, torn down when the animation completes. No window persists at rest.

### 4.5 `CometAnimator`
- **Purpose:** Draw and run the comet along a given path, then signal completion.
- **Look (neon comet):**
  - A short bright stroke segment = the "head," with a tapering "tail" produced
    by stacking a few `CAShapeLayer`s: a wide, dim, blurred stroke + a narrow,
    bright stroke, each with a green `shadowColor` / `shadowRadius` glow.
  - Motion: animate `strokeStart` and `strokeEnd` (head leads, tail trails by a
    fixed gap) around the closed path with `CABasicAnimation` /
    `CAKeyframeAnimation`, looping for `lapCount` laps.
- **Timing:** `lapDuration` from settings (speed slider); total =
  `lapDuration * lapCount`, then a ~0.4s opacity fade. Completion delivered via
  `CATransaction.completionBlock` / animation delegate → triggers window
  teardown.
- **Depends on:** QuartzCore. Pure GPU compositing; no per-frame app code.

### 4.6 `AppController`
- **Purpose:** Orchestrator. Owns `PowerMonitor` and the comet color/timing.
- **Behavior:**
  - On `.didPlugIn` (and only if `effectEnabled`): snapshot
    `NSScreen.screens`, build one `CometOverlayWindow` + animation per screen,
    fire all simultaneously.
  - **Debounce:** track screens with an in-flight animation; ignore re-triggers
    for a screen until its animation completes.
  - **Test command:** `runTestAnimation()` fires the same path on the main
    screen (wired to the menu "Test animation" and the Settings "Preview"),
    independent of real power state.
  - Observe `NSApplication.didChangeScreenParametersNotification` only to drop
    stale references; geometry is always read fresh at fire time.

### 4.7 Settings model
- `@AppStorage`-backed (`UserDefaults`), one observable object:
  - `effectEnabled: Bool = true`
  - `launchAtLogin: Bool` — setter calls `SMAppService.mainApp.register()` /
    `.unregister()`; initial value reflects `SMAppService.mainApp.status`.
  - `cometColorHex: String` (default vivid green, ≈ `#34FF6A`; stored as hex,
    surfaced via a SwiftUI `ColorPicker`).
  - `lapCount: Int = 2` (range 1–5).
  - `lapDuration: Double` (speed slider; default ≈ 1.2 s/lap, range ≈ 0.6–2.0).

## 5. UI

### 5.1 Menu bar (`MenuBarExtra`, `.menu` style)
- Icon: SF Symbol (e.g. `bolt.fill`) or a small custom template image.
- Items: **Enabled** (toggle) · **Test animation** · **Settings…** (opens the
  Settings scene) · **Quit PowerSnek**.

### 5.2 Settings window (SwiftUI `Settings` scene, ⌘,)
- A single `Form`:
  - Enable effect — toggle
  - Launch at login — toggle
  - Comet color — `ColorPicker`
  - Laps — `Stepper` (1–5)
  - Speed — `Slider`
  - **Preview** — button calling `AppController.runTestAnimation()`

## 6. Data flow (happy path)

1. App launches as a menu bar agent; `PowerMonitor.start` seeds current power
   state silently and begins listening.
2. User connects charger → IOKit callback → `shouldFire(.battery, .ac) == true`
   → `onPlugIn`.
3. `AppController` checks `effectEnabled`, snapshots `NSScreen.screens`.
4. For each screen: `ScreenGeometry` reads insets/aux/corner radius →
   `PerimeterPathBuilder.buildPath` → `CometOverlayWindow` created →
   `CometAnimator` runs `lapCount` laps + fade.
5. On completion, each window tears down. Nothing persists.

## 7. Edge cases & error handling

- **No notch** (external display, or built-in reporting `safeAreaTop == 0`):
  plain rounded-rect path; everything else identical.
- **Effect disabled:** power events are ignored (no windows created).
- **Rapid plug/unplug:** re-trigger ignored while a screen's animation is in
  flight (debounce set).
- **Display disconnected mid-animation:** window's screen reference is guarded;
  teardown is safe if the screen vanishes.
- **Private corner-radius API returns nil / fails:** defensive wrapper falls back
  to a constant; no crash.
- **Already plugged in at launch / wake from sleep:** seeded initial state means
  no fire; only a real battery → AC edge fires.
- **No special permissions:** overlay windows and IOKit power reads need neither
  Accessibility nor Screen Recording. Verified as a requirement.

## 8. Testing strategy

- **Unit (TDD, pure logic):**
  - `PerimeterPathBuilder`: notch present (correct notch span/depth in path),
    notch absent (plain rounded rect), external (radius 0), inset applied.
    Assert on path element counts / key points via `CGPath.applyWithBlock`.
  - `PowerMonitor.shouldFire`: all transitions
    (battery→ac fires; ac→battery, ac→ac, battery→battery, unknown→* do not).
  - Settings persistence round-trips through `UserDefaults`.
- **Manual / visual:** the animation itself, via "Test animation" and the
  Settings "Preview" button — no need to physically unplug to iterate.

## 9. Distribution

- Developer ID Application code-signing + Hardened Runtime.
- Notarization (`notarytool`) + staple.
- Ship as a notarized DMG ("Download free for macOS").
- Apple Developer account is available (confirmed).

## 10. Project layout (proposed)

```
PowerSnek/
  PowerSnek.xcodeproj
  PowerSnek/
    PowerSnekApp.swift          # @main, MenuBarExtra + Settings scenes
    AppController.swift
    Power/PowerMonitor.swift     # + PowerState, shouldFire
    Geometry/PerimeterPathBuilder.swift
    Geometry/ScreenGeometry.swift
    Overlay/CometOverlayWindow.swift
    Overlay/CometAnimator.swift
    Settings/SettingsModel.swift
    Settings/SettingsView.swift
    Resources/Assets.xcassets    # app + menu bar icons
    Info.plist                   # LSUIElement = YES
  PowerSnekTests/
    PerimeterPathBuilderTests.swift
    PowerMonitorTests.swift
    SettingsModelTests.swift
  docs/superpowers/specs/2026-06-23-powersnek-design.md
```

## 11. Open implementation risks (carry into planning)

1. **Corner-radius private API** — primary visual-fidelity risk; mitigated by
   fallback constant.
2. **Drawing over the menu bar / notch region** — confirm shield window level
   reliably renders in the menu bar strip on macOS 26; fallback to
   `.statusBar + 1` if needed.
3. **Comet tail aesthetics** — stacked-stroke glow needs visual tuning; the Test
   command makes iteration fast.
