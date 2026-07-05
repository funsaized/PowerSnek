# Comet Animation 2.0 — Design

**Date:** 2026-07-05
**Goal:** Make PowerSnek's charging comet identical to the "Charging comet 2.0" animation from Mac 4 Breakfast (reference: Threads post `@kapisch_ai/DaX27GmkdYS`; exact math extracted from the mac4breakfast.app hero-page JS implementation of the same animation).

## Reference behavior (extracted, authoritative)

All lengths below are in **reference units**: a 1600 × 1038 mock screen with a 173 × 34 notch. At runtime every width/radius/margin/blur is multiplied by `s = viewWidth / 1600`. Path-relative quantities (fractions of perimeter length) are unitless.

### Choreography

1. **Travel** (`travel` seconds, default 3.1): comet starts at the **bottom-left corner**, sweeps **clockwise** (up the left edge → top-left corner → top edge → traces the notch → top edge → top-right → down the right edge → bottom edge), runs `lapCount` full laps plus the extra fraction needed to stop exactly at the **notch-bottom center** (top-center on notchless displays).
2. **Finale** (0.9 s): trail and head vanish; a white flash pops at the landing point; a bright rim glow draws outward around the notch outline from its center; one breathing glow pulse swells around the notch; a small glint shrinks and fades.
3. **Done**: everything is at opacity 0 by the end of the finale; the animator calls its completion (window closes, debounce released) — one-shot, no rest/loop phase.

### Travel math

- Total distance `O = laps + landingFraction` (in perimeter-lengths).
- Eased progress: `e(t) = O · wm(t / travel)` where
  `wm(u) = 0.92 · (u³(u(6u − 15) + 10)) + 0.08 · u` (smootherstep blended with 8 % linear — slow launch, fast mid-sweep, decelerating arrival).
- Head position along path: `r = e mod 1`. Remaining distance: `i = O − e`.
- Trail length: `a = min(0.15, e) · min(1, i / 0.3)` — grows from zero at launch, collapses into the head over the last 0.3 perimeter-lengths of the approach.
- Head throb: width multiplier `1 + 0.07 · sin(2π · 2.2 · t)` applied to head core and head glow.

### Trail (24 segments, index i, `a = (i + 0.5) / 24`)

- Core width: `20 − 17.5 · a^0.9`; core alpha: `(1 − a)^1.35`.
- Core color gradient `Cm(a)`: `a < 0.1` → lerp(white → **bright**, a/0.1); else lerp(**bright** → **tail**, (a − 0.1)/0.9).
- Halo stroke per segment: width × 2.4, alpha × 0.55, color **base**, Gaussian blur 9.
- Segment i spans `[r − ((i+1)/24)·a, r − (i/24)·a]` along the path (dash technique).

### Head

- Dash length 0.0012 of perimeter, round caps.
- Core: white, width 17. Glow: **bright**, width 36, blur 7, opacity 0.85.

### Finale (u = phase progress 0→1 over 0.9 s; `Tm(x) = 1 − (1 − clamp(x))²`)

- **Flash** (white circle at landing point, blur 10): `n = clamp(u / 0.16)`; radius `12 + 80 · Tm(n)`; opacity `0.95 · (1 − n)`.
- **Rim glow** (only when a notch exists; drawn on the notch-rim subpath): draw-out `rf = Tm(u / 0.32) · 0.5`, dash length `max(2·rf, 0.001)` centered at rim-path midpoint (dash offset `−(0.5 − rf)`); fade `f = u < 0.72 ? 1 : 1 − (u − 0.72)/0.28`. Halo stroke: **bright**, width 24, blur 8, opacity 0.85·f. Core stroke: **rimCore**, width 7.5, opacity 1·f.
- **Breath** (the "pulse around the notch"): `o = sin(π · clamp((u − 0.1)/0.62))`.
  Glow A: rounded rect (corner 30, blur 26, fill **base**) centered on the notch, size `(notchW + 60)·(1 + 0.2·o)` × `(notchH + 46)·(1 + 0.45·o)`, vertical center at notch-bottom/2 + 6 (reference y-down; mirror for AppKit y-up), opacity `0.6 · o · f`.
  Glow B: fixed rect `(notchW + 16)` × `(notchH + 12)` (corner 18, blur 14, fill **bright**), opacity `0.3 · o · f`.
  On notchless displays the breath uses a nominal notch rect of 173 × 34 reference units centered at top-center.
- **Glint** (white dot at landing point): radius `max(2, 9·(1 − u))`, opacity `1 − Tm(u)`.

### Palette (derived from the user's comet color C, in sRGB HSB)

Reference greens: base `#2BD46E`, bright `#5BEF96`, tail `rgb(20,156,85)`, rimCore `#d9ffe9`.

- **base** = C.
- **bright** = C with saturation × 0.78, brightness × 1.13 (clamped to 1).
- **tail** = C with saturation × 1.09 (clamped), brightness × 0.73.
- **rimCore** = white blended 15 % toward C.

With the default green these land within a few percent of the reference hexes (hue identical); other colors get the same white-hot-head → hue → darker-tail treatment.

## Architecture

### 1. `PowerSnekKit/PerimeterPathBuilder` (modified)

`buildPath` is replaced by `buildOutline(_:) -> ScreenOutline` returning:

- `path: CGPath` — closed perimeter, **starting at the bottom-left corner arc end (left edge, y = bottom + r)** and ordered **clockwise on screen** (view coords are y-up: up the left edge first).
- `totalLength: CGFloat` — analytic arc length (lines + quarter arcs; no flattening needed).
- `landingFraction: CGFloat` — arc-length fraction of the notch-bottom-center point (or the top-edge center when no notch), computed analytically while building.
- `rimPath: CGPath?` — the notch-rim subpath (left wall → bottom → right wall, same direction as the perimeter), nil when no notch. Its midpoint corresponds to the notch-bottom center.
- `notchRect: CGRect` — notch bounds in view coords (nominal 173·s × 34·s rect at top-center when no notch), for the breath glows.

Pure geometry; unit-tested.

### 2. `PowerSnekKit/CometMath` (new, pure)

Testable functions/constants mirroring the reference: `easedProgress` (`wm`), `easeOutQuad` (`Tm`), `trailProfile(segments:)` (widths/alphas/colors as HSB adjustments), `trailLength(progress:total:)`, `throb(t:)`, and finale envelopes (`flash(u:)`, `rimDraw(u:)`, `breath(u:)`, `glint(u:)`) returning plain value structs. No AppKit/QuartzCore types beyond CoreGraphics scalars.

### 3. `CometAnimator` (rewritten)

- Builds layers once on the host: 24 trail-core `CAShapeLayer`s + 24 trail-halo layers inside a halo group, head core + head glow, rim core + rim halo group, flash and glint layers, breath glows.
- **Glow rendering**: halo/glow groups use `CALayer.filters` with `CIGaussianBlur` (radius × s), which macOS supports; breath glows and the flash use radial `CAGradientLayer`s (no filter needed). If the blur filter fails to render in the shielding-level overlay window (verified visually via the menu-bar test command during implementation), fall back to shadow-based glow (`shadowRadius` = blur × s) as the current code does.
- **Driver**: `NSView.displayLink(target:selector:)` (macOS 14+) owned by the animator; each tick computes phase from `performance-now`-style timestamps and sets `lineDashPattern`/`lineDashPhase`/`lineWidth`/`opacity` (and breath/flash frames) inside `CATransaction` with actions disabled. Dash lengths are in absolute path units (`fraction × totalLength`).
- Phases: travel → finale → invalidate display link, call completion. The completion contract with `AppController` (always called exactly once, including the degenerate-path guard) is preserved.
- API: `run(on:outline:color:laps:sweepDuration:completion:)`.

### 4. `AppController` (small changes)

- Uses `buildOutline`, passes `ScreenOutline` through.
- Travel time scales with distance: `travel = lapDuration × (laps + landingFraction) / (2 + landingFraction)` — i.e. the slider keeps its meaning ("duration of the default 2-lap sweep") and more laps take proportionally longer at the same speed.
- `SettingsStore` registered default for `lapDuration` changes 3.0 → 3.1 (matches the video). Slider range and laps stepper (1–5) unchanged.

### 5. Testing

- **Unit (PowerSnekKit)**: outline starts at bottom-left and runs clockwise (first path points go up the left edge); landing fraction correct for notch and no-notch inputs (analytic vs flattened-path measurement); rim-path midpoint = notch-bottom center; easing endpoints (`wm(0)=0`, `wm(1)=1`, monotonic); trail length grows then collapses to 0 exactly at `e = O`; finale envelopes hit their documented extremes.
- **Visual**: menu-bar "Test animation" on the built-in (notch) display and an external display; verify start corner, direction, acceleration/deceleration, landing, flash + rim + breath pulse, clean completion (window closes, re-fire works).

## Error handling

- Degenerate path (length ≤ 1) → immediate completion (unchanged).
- Display link unavailable (headless/edge cases) → complete immediately after a no-op, never strand the debounce.
- All per-frame math clamps its inputs (as the reference does with `Em`/clamps), so a late/dropped frame can only skip ahead, never render garbage.

## Out of scope

- Reduce-motion accessibility variant, the website's loop/rest mode, changing the default comet color hex, settings UI changes.
