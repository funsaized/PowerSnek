# PowerSnek

> Plug in. Watch it celebrate.

[🏠 Website](http://powersnek.s11a.com/) · [📦 Download](https://github.com/funsaized/PowerSnek/releases/latest)

PowerSnek is a tiny macOS menu-bar app that does one thing: when you plug in
your charger, it draws a green comet around the edge of each display, including
the MacBook notch, then gets out of the way.

It is a one-shot animation, not a background effect. There are no persistent
windows, no Accessibility or Screen Recording permissions, and no ongoing GPU
work after the animation finishes.

- Traces the real screen outline, notch included.
- Runs only on the battery-to-AC transition.
- Animates all connected displays.
- Five tuned styles: Electric, Snek, Aurora, Hyperbolt, and Minimal.
- Shows the battery level ("47% · Charging") under the notch after landing.
- Stays out of the way: pauses over full-screen apps, hides from screen
  recordings and sharing, and waits until you unlock if you plugged in while
  the screen was asleep or locked.
- Respects Reduce Motion with a glow in place instead of laps.

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

Click the menu-bar icon for the status, **Preview Celebration**, a **Style**
submenu, and **Settings...**:

- **Style**: pick one of five tuned styles (changes preview automatically)
- **Celebrate when I plug in**: master on/off
- **Show battery level after landing**: the readout under the notch
- **Pause over full-screen apps**: skip displays showing a full-screen app,
  video, or presentation
- **Hide from screen recordings & sharing**: keep the overlay out of
  screenshots, recordings, and calls
- **Color & timing**: color swatches or any custom color, laps (1-5), and
  speed; overrides the style's presets ("Customized · Reset")
- **Launch PowerSnek at login**: on by default after onboarding, since the app
  must be running to notice your charger
- **Check for updates automatically**: at most once a day, PowerSnek asks
  GitHub for the latest release and lights up a menu item if there is one.
  Nothing is downloaded or installed without a click, and nothing else is sent.

## How it works

The app is a SwiftUI menu-bar agent with AppKit overlay windows and Core
Animation strokes. Testable logic lives in `PowerSnekKit`; the app target owns
the IOKit listener, overlay windows, animation, and UI.

| Piece | Responsibility |
| --- | --- |
| `PowerMonitor` | IOKit power-source notifications; fires only on battery-to-AC, with launch/wake seeded silently |
| `PerimeterPathBuilder` | Pure geometry to a `ScreenOutline`: the closed perimeter path (bottom-left start, clockwise) plus landing metrics (landing point/fraction, notch rim path, notch rect) |
| `ScreenGeometry` | Reads live `NSScreen` insets/notch/corner radius into the builder |
| `CelebrationProfile` | The tuned styles: color, laps, speed, stroke, glow, trail length, hue drift, and finale |
| `CelebrationGate` / `FullScreenCoverage` | Pure policies: defer while nobody can see the screen; detect full-screen apps from window bounds |
| `ScreenProbe` | Reads session lock, display sleep, and on-screen window bounds (no permissions) |
| `CometOverlayWindow` | One borderless, click-through, shield-level window per display |
| `CometAnimator` | `CADisplayLink`-driven per-frame renderer: eased variable-speed sweep, collapsing trail, landing on the notch, then the style's finale and battery readout; a glow-in-place variant for Reduce Motion |
| `AppController` | Orchestrates: on plug-in, celebrate on every visible display, one session per display ID |
| `UpdateChecker` | Daily/manual check of the latest GitHub release |

Diagnostics stay on your Mac: `log show --predicate 'subsystem == "com.powersnek.app"' --last 1h`
explains why a celebration did or didn't play, and the `Animation` signposts
show each celebration in Instruments.

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

## Contributing

PowerSnek is open source. If you think of a feature you want, issues and pull
requests are welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup,
project conventions, and PR expectations.

## Releasing

Tag-triggered, signed and notarized DMGs via
[`.github/workflows/release.yml`](.github/workflows/release.yml). Signing and
notarization secrets are required; see
[`scripts/release/README.md`](scripts/release/README.md) for the required
secrets. To cut a release:

```bash
# After updating MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml
# (and LATEST_VERSION in site/src/release.ts once the release is published):
git tag v0.3.0 && git push origin v0.3.0
```

This builds a universal binary, signs it with Developer ID and Hardened Runtime,
notarizes and staples it, and publishes a draft GitHub Release with a verified
DMG, its checksum, and a version-less `PowerSnek.dmg` alias (for
`releases/latest/download/PowerSnek.dmg` links) attached to the exact tag.

## Requirements

macOS 14+ (built and tested on macOS 26, Apple Silicon).

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
