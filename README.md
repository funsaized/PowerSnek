# PowerSnek

> Plug in. Watch it celebrate.

[Website](http://powersnek.s11a.com/) · [Download](https://github.com/funsaized/PowerSnek/releases/latest)

PowerSnek is a tiny macOS menu-bar app that does one thing: when you plug in
your charger, it draws a green comet around the edge of each display, including
the MacBook notch, then gets out of the way.

It is a one-shot animation, not a background effect. There are no persistent
windows, no Accessibility or Screen Recording permissions, and no ongoing GPU
work after the animation finishes.

- Traces the real screen outline, notch included.
- Runs only on the battery-to-AC transition.
- Animates all connected displays.
- Can be toggled or previewed from the menu bar.

## Install

**Download:** get the latest `PowerSnek-x.y.z.dmg` from
[Releases](https://github.com/funsaized/PowerSnek/releases), open it, and drag
**PowerSnek** to Applications. Launch it, and a small power icon appears in the
menu bar. There is no Dock icon.

**Build from source:**

```bash
brew install xcodegen
xcodegen generate
open PowerSnek.xcodeproj      # ⌘R to run
```

## Settings

Click the menu-bar icon, then open **Settings...**:

- **Enable effect**: master on/off
- **Launch at login**: start automatically with `SMAppService`
- **Comet color**: defaults to `#34FF6A`
- **Laps**: 1-5, default 2
- **Speed**: lap duration
- **Preview**: run the animation without unplugging

The menu also has **Test Animation** for a quick preview.

## How it works

The app is a SwiftUI menu-bar agent with AppKit overlay windows and Core
Animation strokes. Testable logic lives in `PowerSnekKit`; the app target owns
the IOKit listener, overlay windows, animation, and UI.

| Piece | Responsibility |
| --- | --- |
| `PowerMonitor` | IOKit power-source notifications; fires only on battery-to-AC, with launch/wake seeded silently |
| `PerimeterPathBuilder` | Pure geometry to a closed `CGPath` outline, including notch detours |
| `ScreenGeometry` | Reads live `NSScreen` insets/notch/corner radius into the builder |
| `CometOverlayWindow` | One borderless, click-through, shield-level window per display |
| `CometAnimator` | Stacked `CAShapeLayer` strokes + glow, driven by an animated `lineDashPhase` |
| `AppController` | Orchestrates: on plug-in, animate every display (with per-display debounce) |

PowerSnek does not request Accessibility or Screen Recording permissions.

## Development

```bash
xcodegen generate                                                    # regenerate the project
xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
xcodebuild test  -project PowerSnek.xcodeproj -scheme PowerSnek \
  -destination 'platform=macOS'
```

- `project.yml` is the source of truth ([XcodeGen](https://github.com/yonaskolb/XcodeGen)); regenerate the Xcode project from it.
- CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) builds and tests on every push and PR.
- Design spec and implementation plan live under [`docs/superpowers/`](docs/superpowers/).

## Releasing

Tag-triggered, signed and notarized DMGs via
[`.github/workflows/release.yml`](.github/workflows/release.yml). Signing and
notarization are secret-gated; see
[`scripts/release/README.md`](scripts/release/README.md) for the required
secrets. To cut a release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

This builds a universal binary, signs it with Developer ID and Hardened Runtime,
notarizes and staples it, and publishes a draft GitHub Release with the DMG
and its checksum.

## Requirements

macOS 14+ (built and tested on macOS 26, Apple Silicon).
