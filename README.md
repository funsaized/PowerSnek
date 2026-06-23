# PowerSnek

> Plug in. Watch it celebrate.

PowerSnek is a lightweight, native macOS menu-bar app. The instant your charger
connects, a vivid green comet sweeps around the perimeter of **every** connected
display — tracing the exact contour of your screen, **notch and all** — for a
couple of laps, then fades on its own. A one-shot flourish, not a running
animation: GPU-composited, no persistent windows, negligible battery cost.

- 🟢 **Traces your notch** — the comet hugs the real contour of the built-in display.
- ⚡ **Only when you plug in** — fires on the battery→AC transition, then fades.
- 🔋 **Zero battery cost** — a one-shot Core Animation flourish. Toggle it anytime.
- 🖥️ **All displays** — every connected screen celebrates at once.

## Install

**Download:** grab the latest `PowerSnek-x.y.z.dmg` from
[Releases](https://github.com/funsaized/PowerSnek/releases), open it, and drag
**PowerSnek** to Applications. Launch it — a ⚡ icon appears in your menu bar
(no Dock icon).

**Build from source:**

```bash
brew install xcodegen
xcodegen generate
open PowerSnek.xcodeproj      # ⌘R to run
```

## Settings

Click the menu-bar ⚡ → **Settings…**:

- **Enable effect** — master on/off
- **Launch at login** — start automatically (via `SMAppService`)
- **Comet color** — defaults to vivid green `#34FF6A`
- **Laps** — 1–5 (default 2)
- **Speed** — lap duration
- **Preview** — fire the animation on all displays without unplugging

The menu also has **Test Animation** for a quick preview.

## How it works

A SwiftUI menu-bar agent drives AppKit + Core Animation. The testable logic
lives in a `PowerSnekKit` framework; the app target owns the IOKit listener,
overlay windows, the comet, and the UI.

| Piece | Responsibility |
| --- | --- |
| `PowerMonitor` | IOKit power-source notifications; fires only on battery→AC (seeded silently so launch/wake never trigger it) |
| `PerimeterPathBuilder` | Pure geometry → a closed `CGPath` outline, detouring around the notch |
| `ScreenGeometry` | Reads live `NSScreen` insets/notch/corner radius into the builder |
| `CometOverlayWindow` | One borderless, click-through, shield-level window per display |
| `CometAnimator` | Stacked `CAShapeLayer` strokes + glow, driven by an animated `lineDashPhase` |
| `AppController` | Orchestrates: on plug-in, animate every display (with per-display debounce) |

No Accessibility or Screen Recording permissions required.

## Development

```bash
xcodegen generate                                                    # regenerate the project
xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
xcodebuild test  -project PowerSnek.xcodeproj -scheme PowerSnek \
  -destination 'platform=macOS'
```

- `project.yml` is the source of truth ([XcodeGen](https://github.com/yonaskolb/XcodeGen)); `PowerSnek.xcodeproj` is generated and git-ignored.
- CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) builds and tests on every push and PR.
- Design spec and implementation plan live under [`docs/superpowers/`](docs/superpowers/).

## Releasing

Tag-triggered, signed + notarized DMGs via
[`.github/workflows/release.yml`](.github/workflows/release.yml). Signing and
notarization are **secret-gated** — see
[`scripts/release/README.md`](scripts/release/README.md) for the required
secrets. To cut a release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

This builds a universal binary, signs it with Developer ID + Hardened Runtime,
notarizes and staples it, and publishes a **draft** GitHub Release with the DMG
and its checksum.

## Requirements

macOS 14+ (built and tested on macOS 26, Apple Silicon).
