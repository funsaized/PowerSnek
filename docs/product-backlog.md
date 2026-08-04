# PowerSnek Product and Engineering Backlog

**Status:** Proposed
**Analysis date:** 2026-08-04
**Inspected revision:** `d532b5ba4a1d4318ad085cbff785f01288df3b4a` (`main`)
**Purpose:** Turn PowerSnek from a polished implementation with no usable acquisition funnel into a small, distinctive Mac product that can be installed, understood, measured, and improved.

## Executive verdict

PowerSnek's core implementation is better than its adoption suggests. It is a focused native Mac app with a sensible split between deterministic framework logic and OS-facing code, unusually thorough geometry and animation tests, no persistent rendering loop, no invasive permissions, and a genuinely distinctive full-display effect.

The immediate problem is not a missing feature. The product is effectively unavailable:

- The public `v0.2.0` release is marked latest but has no DMG or checksum assets.[1]
- The website's primary CTA opens the GitHub releases index, where the latest release offers only source archives rather than an installable app (`site/src/components/PowerSnekHero.tsx:77-83`).
- The only downloadable DMG is attached to `v0.1.0`, and GitHub reports one download. The repository currently reports zero stars and zero forks.[2]
- There is no direct-download conversion path, update channel, privacy-respecting funnel measurement, real product recording, or distribution beyond GitHub.

That means “nobody uses it” is not yet evidence that people reject the concept. The acquisition funnel is broken before a user can make that decision.

The strategic recommendation is therefore:

1. Repair distribution and instrument the funnel without adding in-app surveillance.
2. Unify the brand and make the real effect demonstrable in five seconds.
3. Improve reliability, accessibility, and measurable animation performance.
4. Run a bounded validation sprint before expanding the feature surface.
5. If the wedge works, evolve from “one charging animation” into “the lightweight celebration layer for meaningful Mac system moments” without becoming another persistent Dynamic Island clone.

Do **not** start with a rewrite, a settings architecture overhaul, or a pile of new triggers. Those are ways to polish a product users still cannot download.

## Product contract

### Primary user

A MacBook owner who enjoys polished desktop customization but does not want another always-open dashboard, intrusive permission request, or resource-heavy notch utility.

### Job to be done

> Give me a small, beautiful confirmation that power is flowing when I connect my Mac, then disappear completely.

### Core promise

- One-shot celebration on a real battery-to-AC transition.
- Traces every connected display and follows the MacBook notch.
- No Dock icon, persistent window, Accessibility permission, Screen Recording permission, or ongoing animation work.
- User-selectable color, laps, speed, enablement, and launch-at-login.

### Product boundaries to preserve

1. **Moment, not dashboard.** PowerSnek should not become a media player, calendar, file shelf, or permanent notch surface. Boring Notch already combines charging indicators with media controls, calendar, file handling, HUD replacements, and other persistent notch features.[4][5]
2. **No-permission by default.** New features must not casually trade away the strongest trust differentiator.
3. **Zero meaningful idle cost.** At rest, the app should remain an IOKit notification listener rather than a polling service.
4. **Instantly demonstrable.** Every acquisition surface must show the actual value in five seconds or less.
5. **Opinionated defaults before more knobs.** Aesthetic products win through tuned presets, not a control panel that asks users to become motion designers.

## Current system

```text
IOKit power notification
        |
        v
PowerMonitor -- battery -> AC edge only
        |
        v
AppController (@MainActor)
        |
        +-- SettingsStore guard
        +-- NSScreen.screens fan-out
        +-- per-display debounce
        |
        v
ScreenGeometry -> PerimeterPathBuilder -> ScreenOutline
        |
        v
CometOverlayWindow (transparent, click-through, shield-level)
        |
        v
CometAnimator (CADisplayLink)
        |
        +-- 24 core trail segments
        +-- 24 halo trail segments
        +-- head, flash, notch rim, breath, glint
        |
        v
completion -> close window -> release debounce
```

### User-facing flow

```text
Website
  -> GitHub releases index
  -> DMG download (currently missing for Latest)
  -> drag app to Applications
  -> first-run welcome
  -> automatic preview
  -> opt into launch at login
  -> future charger connection
  -> one-shot celebration
```

### What is strong and should remain locked

- `PowerSnekKit` contains pure power-state, color, geometry, path, palette, animation math, and settings behavior; the app target contains IOKit, AppKit, SwiftUI, screen, window, and rendering integration (`project.yml:12-47`).
- `PowerState.shouldFire` encodes the exact battery-to-AC edge and silently seeds launch/wake state (`Sources/PowerSnekKit/PowerState.swift:7-9`, `Sources/PowerSnek/PowerMonitor.swift:25-48`).
- Geometry and motion are deterministic and heavily unit-tested, including analytic-versus-flattened perimeter checks and monotonic motion (`Tests/PowerSnekKitTests/ScreenOutlineTests.swift`, `Tests/PowerSnekKitTests/CometMathTests.swift`).
- Overlay windows do not steal focus or mouse input and span spaces/full-screen apps (`Sources/PowerSnek/Overlay/CometOverlayWindow.swift:7-31`).
- Animation teardown is idempotent and includes a watchdog, protecting the per-display debounce (`Sources/PowerSnek/Overlay/CometAnimator.swift:74-127`).
- The first-run experience already auto-previews the effect and offers launch-at-login (`Sources/PowerSnek/Onboarding/WelcomeView.swift:51-78`).
- The website has a coherent responsive visual style and honors reduced motion (`site/src/app/globals.css:167-175`).
- `NSView.displayLink(target:selector:)` is a documented macOS 14+ AppKit API, not private API.[7] Replacing it with CoreVideo would add complexity without solving an observed problem.

## Why adoption is currently near zero

### Proven blockers

1. **Latest release has no installable asset.** `v0.2.0` is public and latest, but its asset list is empty.[1]
2. **Release automation silently published to the wrong target.** The successful `v0.2.0` workflow built, signed, notarized, checksummed, and uploaded a CI artifact. In the separate publish job, `GITHUB_REF_NAME` resolved empty, so the workflow created an untagged draft instead of uploading the files to `v0.2.0`. The public release was later published without those files. The workflow currently has no post-publish assertion (`.github/workflows/release.yml:125-154`).
3. **The website CTA is not a download.** It sends users to a release-management page and asks them to identify the correct asset (`site/src/components/PowerSnekHero.tsx:77-83`). Today that page cannot satisfy the request.
4. **No real product evidence.** The site uses a synthetic looping SVG; the README contains no image or recording. A stranger cannot verify that the native effect matches the marketing rendering.
5. **No funnel visibility.** There is no site click measurement, install proxy, update check, or app telemetry. Only GitHub asset download counts are available.

### High-confidence product friction

- The website's chartreuse mascot brand (`#C3FB1C`) and the native app's neon-green default (`#34FF6A`) feel like separate visual systems (`site/src/app/globals.css:4-13`, `Sources/PowerSnekKit/SettingsStore.swift:5`).
- The web mascot is distinctive; the native welcome and settings surfaces use generic SF Symbols (`Sources/PowerSnek/Onboarding/WelcomeView.swift:37-42`).
- The status icon carries little of the snake/comet identity and is the app's most frequently visible surface.
- Settings expose raw color/laps/speed controls but no tuned styles or intensity concept (`Sources/PowerSnek/Settings/SettingsView.swift:15-43`).
- The native effect ignores the user's Reduce Motion preference even though the site honors it.
- There is no update channel, so even a repaired release leaves early users stranded on old builds.

### Unknowns that require validation

- Whether users like the effect after seeing the real animation.
- Whether “charging celebration” alone is enough reason to keep a menu-bar slot.
- Which visual style, duration, and intensity users prefer.
- Whether users want additional charging states or broader system-event celebrations.
- Whether Homebrew, the Mac App Store, or direct DMG distribution converts best for this audience.

These are product questions, not excuses to guess. The backlog below creates evidence before committing to large scope.

## Architecture and maintainability assessment

### Overall

The codebase is small: 1,244 Swift code lines across 23 Swift files and 2,255 code lines across the repository excluding dependencies/build output. The current boundaries are appropriate. Maintainability risk is concentrated in OS lifecycle edges, release engineering, visual configuration, and the lack of observability—not in fundamental architecture.

### Simplify now

1. **Make release state explicit.** Pass the resolved tag/version between jobs as outputs; never derive critical publish state independently in a later job.
2. **Replace parallel display collections with one keyed session model.** `activeWindows` plus `animatingScreens` can drift. A dictionary keyed by validated display ID can own window + animation state together (`Sources/PowerSnek/AppController.swift:8-9,43-75`).
3. **Stop returning display ID `0` as a valid identity.** Treat a missing `NSScreenNumber` as “cannot animate safely,” log it, and release cleanly (`Sources/PowerSnek/AppController.swift:79-82`).
4. **Centralize visual tuning.** Move inset, radii, stroke/glow parameters, palette default, lap count, and timing into explicit immutable profiles before adding themes. Do not scatter a second style across `AppController`, `CometMath`, `CometPalette`, and SwiftUI.
5. **Keep generated site state out of source control.** `npm run build` modifies tracked `site/tsconfig.tsbuildinfo` and `site/next-env.d.ts`. Ignore/untrack the build-info file and make the Next-generated declaration deterministic or validate it in CI.
6. **Split the 348-line hero only when editing it.** Extracting mascot/logo/feature rows into focused components is reasonable during the next site revision; a standalone refactor has no user value.

### Do not simplify yet

- Do not merge `PowerSnekKit` back into the app. Its test seam is valuable.
- Do not replace `CADisplayLink` with a custom timer or CoreVideo bridge; the current AppKit API is display-aware and documented for the deployment target.[7]
- Do not introduce a generic event bus, dependency-injection framework, or plugin system for one trigger and one renderer.
- Do not split `AppEnvironment` into state/services solely to remove the writable binding comment. Revisit only when multiple trigger services or update state make ownership materially harder.
- Do not cache palette calculations or optimize the small active-window array for Big-O reasons. The maximum real cardinality is tiny, and clarity matters more.

## Performance assessment

### Measured from implementation

- At rest there is no polling loop or animation timer; `PowerMonitor` owns one IOKit run-loop source (`Sources/PowerSnek/PowerMonitor.swift:25-55`).
- During the effect, each display receives its own overlay and display link.
- Each travel frame updates dash pattern/phase for 24 core and 24 halo segments, plus the head (`Sources/PowerSnek/Overlay/CometAnimator.swift:264-291`).
- Layer construction adds multiple screen-blended groups and Gaussian blur filters (`Sources/PowerSnek/Overlay/CometAnimator.swift:131-235`).
- Default travel is calibrated to roughly 3.1 seconds for two laps plus a 0.9-second finale, not seven seconds (`Sources/PowerSnekKit/CometMath.swift:108-115`).

### Hypotheses to measure

- On a 120 Hz Retina display, allocation and property churn from rebuilding dash-pattern arrays 48+ times per frame may be more important than the pure math.
- On multi-display setups, blurred screen-blended groups may keep the GPU/compositor busy enough to cause dropped frames or visible energy impact.
- Mixed-DPI displays may render inconsistently because `CometAnimator` derives `contentsScale` from the window/view and falls back to the main screen (`Sources/PowerSnek/Overlay/CometAnimator.swift:57-66`).

Do not add rasterization, Metal, custom shaders, or layer pooling until Instruments identifies the dominant cost.

## Prioritization model

- **P0 — Funnel/release blocker:** users cannot install or evidence cannot be trusted.
- **P1 — Product quality:** materially improves activation, trust, accessibility, retention, or reliability.
- **P2 — Validated growth:** expands distribution or product value after the repaired funnel produces signal.
- **P3 — Optional bets:** only pursue after measured demand.

Effort uses **S** (hours to one day), **M** (two to five days), **L** (one to two weeks), **XL** (multi-sprint).

---

# Backlog

## P0 — Make the product installable and measurable

### PS-001 — Repair the release publication contract

**Outcome:** A tagged release cannot report success unless the matching signed/notarized DMG and checksum are attached to that exact tag.

**Why:** The current `v0.2.0` workflow built valid artifacts but published them to an untagged draft because the publish job resolved an empty tag. The public latest release has no assets.[1]

**Implementation:**

- Resolve `version` and `tag` once and expose both as outputs from a dedicated metadata job.
- Pass outputs to build and publish jobs; do not depend on shell expansion of `GITHUB_REF_NAME` in the publish job.
- Name the release asset with a stable alias (`PowerSnek.dmg`) in addition to the versioned filename, or generate the website URL from the release API.
- After upload, query the release API and assert:
  - tag matches the intended tag;
  - release is not an untagged draft;
  - DMG and checksum exist and are non-empty;
  - checksum matches the uploaded DMG;
  - the public download URL returns success.
- Fail the workflow if any assertion fails.
- Add a documented recovery procedure for attaching CI artifacts to an existing release.

**Acceptance:**

- A dry-run/test tag proves the exact-tag upload path.
- `gh release view <tag> --json assets` lists both files.
- A clean machine can download, mount, drag, launch, and pass Gatekeeper.
- The workflow has a regression test or shell-level contract check for empty tag/version values.

**Effort:** M
**Dependencies:** none
**Evidence:** `.github/workflows/release.yml:53-62,125-154`; run `28156755647`.

### PS-002 — Publish a corrected installable release

**Outcome:** The public “Latest” release contains the current app.

**Implementation:**

- Cut `v0.2.1` rather than mutating the meaning of the existing broken release.
- Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate with XcodeGen, and verify the app/DMG metadata before tagging.
- Generate accurate release notes from `v0.2.0...v0.2.1`; remove the current self-comparison.
- Keep `v0.2.0` visible with a note directing users to `v0.2.1`, or mark it superseded.
- Verify signing, notarization, stapling, checksum, universal architecture, and macOS 14 launch.

**Acceptance:**

- Latest-release API returns the new tag and non-empty assets.
- Direct DMG URL works in a private browser window.
- The site CTA installs the app in no more than two clicks.

**Effort:** S after PS-001
**Dependencies:** PS-001.

### PS-003 — Replace the releases-page CTA with a real download flow

**Outcome:** A visitor knows exactly what will download and can install without interpreting GitHub release internals.

**Implementation:**

- Make the primary CTA a direct DMG download.
- Add secondary “View source” and “All releases” links.
- Put version, download size, macOS requirement, universal binary support, signed/notarized status, and “free/open source” beside the CTA.
- Add a concise three-step install strip: download → drag to Applications → launch from menu bar.
- Add a visible fallback/error state if the release API has no DMG rather than linking to a dead funnel.

**Acceptance:**

- CTA resolves to an actual DMG.
- Keyboard and screen-reader users get a descriptive link name including version/file type.
- A release-without-asset fixture renders an unavailable state.
- Mobile and desktop visual checks pass.

**Effort:** M
**Dependencies:** PS-001.

### PS-004 — Establish privacy-respecting funnel metrics

**Outcome:** We can distinguish no traffic, CTA failure, download failure, and weak retention hypotheses without adding invasive app analytics.

**Implementation:**

- Add privacy-respecting, cookie-free site analytics or first-party server logs for page views and outbound download clicks.
- Snapshot GitHub release asset download counts daily or weekly.
- Record only aggregate events; publish a one-paragraph privacy statement.
- Do not add in-app telemetry in this phase.
- Create a simple weekly funnel:
  - landing views;
  - primary CTA clicks;
  - DMG downloads;
  - issue/crash reports;
  - release-update adoption once an updater exists.

**Acceptance:**

- Metrics can be inspected without user-level identifiers.
- The privacy statement matches implementation.
- A test click appears in aggregate reporting.
- Baseline is recorded before promotion.

**Effort:** M
**Dependencies:** PS-003.

### PS-005 — Add real product evidence

**Outcome:** A visitor sees the native effect—not an approximation—before downloading.

**Implementation:**

- Capture a 4–6 second native recording on a notched MacBook and one external display.
- Show plug-in → full border sweep → notch landing → clean disappearance.
- Produce optimized MP4/WebM and an animated fallback for README/GitHub.
- Keep the current SVG or a still image for Reduce Motion and data-saver contexts.
- Add screenshots of first-run welcome and settings below the hero.
- Add an Open Graph image that communicates the effect and brand.

**Acceptance:**

- Website and README both show the real app.
- Media does not autoplay with sound.
- Reduced-motion users see a static representative frame.
- Largest-contentful-paint regression stays within an agreed budget.

**Effort:** M
**Dependencies:** PS-002.

## P1 — Make the product feel coherent, trustworthy, and polished

### PS-101 — Define one visual system across app, icon, website, and release assets

**Outcome:** PowerSnek looks like one product everywhere.

**Implementation:**

- Choose the canonical primary green (recommendation: chartreuse `#C3FB1C` as brand; retain `#34FF6A` as the “electric green” effect preset).
- Define named tokens for brand, effect, surface, ink, accent, glow, and tongue/red.
- Rework the app icon, welcome header, settings accent, website, README art, and DMG background from the same tokens.
- Bring a restrained version of the snake mascot into onboarding; do not turn settings into a cartoon.
- Replace generic “green” copy with the named style where appropriate.

**Acceptance:**

- Design token table exists in product documentation.
- Native and web defaults are intentionally related.
- App icon remains legible at 16/32/128/512 px.
- Increased Contrast mode remains readable.

**Effort:** M.

### PS-102 — Redesign the status icon and menu as the persistent product surface

**Outcome:** The menu-bar presence is recognizable, compact, and useful enough to justify its slot.

**Implementation:**

- Design a template-rendered snake/comet/bolt silhouette that survives 18 px.
- Test light/dark menu bars, Increased Contrast, crowded status bars, and non-Retina displays.
- Tighten menu copy:
  - status line: “Ready for the next charge” / “Effect paused”;
  - primary action: “Preview celebration”;
  - settings and quit remain standard.
- Include current version in the menu or About surface.
- Avoid a global hotkey until user demand justifies occupying a system-wide shortcut.

**Acceptance:**

- Icon is distinguishable from a notification dot and battery glyph in blinded review.
- VoiceOver reads “PowerSnek” and meaningful control labels through standard SwiftUI accessibility.
- Menu fully operates from keyboard.

**Effort:** M.

### PS-103 — Replace raw customization with three tuned celebration styles

**Outcome:** Users can choose a meaningful aesthetic in one click while advanced controls remain available.

**Recommended initial styles:**

- **Electric Snek** — chartreuse/electric green, current two-lap signature.
- **Aurora** — cooler gradient, slower one-lap glow, softer finale.
- **Hyperbolt** — high-speed single lap, short sharp impact, lower total duration.

**Implementation:**

- Add an immutable `CelebrationProfile` in `PowerSnekKit` containing palette, laps, travel timing, width/glow intensity, and finale parameters.
- Persist selected profile plus optional overrides.
- Show visual swatches and duration in Settings.
- Keep “Advanced” disclosure for color/laps/speed instead of exposing every new parameter.
- Add profile snapshot/math tests; do not duplicate renderer code per style.

**Acceptance:**

- Each preset has a documented duration and Reduce Motion variant.
- Switching presets previews immediately and persists.
- Existing users retain their current custom settings through migration.
- No preset adds idle work.

**Effort:** L
**Dependencies:** PS-101, PS-106.

### PS-104 — Make onboarding a conversion surface, not a feature list

**Outcome:** A new user sees the real effect, understands persistence, and makes one meaningful choice.

**Implementation:**

- Keep automatic first preview.
- Replace generic SF Symbol bullets with one short explanation and the real mascot/effect visual.
- Lead with “Preview again” and the three style cards from PS-103.
- Keep launch-at-login visible and explain why it matters: the app must be running to notice the next charger connection.
- Confirm state after action: “PowerSnek is ready in your menu bar.”
- Add an explicit route to replay onboarding from Settings/About.

**Acceptance:**

- First preview occurs once, safely, after screen state is stable.
- Dismissing with X and Done have documented behavior.
- Keyboard/VoiceOver traversal is coherent.
- Onboarding fits at larger text sizes without clipping.

**Effort:** M
**Dependencies:** PS-101; PS-103 preferred.

### PS-105 — Honor macOS accessibility display preferences

**Outcome:** The native app respects system animation and contrast choices.

**Implementation:**

- Read Reduce Motion before firing.
- Define a reduced-motion profile: immediate border/rim pulse with a short crossfade, no multi-lap travel or throbbing.
- Observe preference changes while the app runs.
- Verify Increase Contrast and Reduce Transparency for welcome/settings and overlay visibility.
- Treat the overlay as decorative; do not create noisy VoiceOver announcements on every charge. Make controls accessible and document the visual-only effect honestly.

**Acceptance:**

- Reduce Motion produces no perimeter travel.
- Preference changes apply without relaunch.
- All controls remain keyboard and VoiceOver operable.
- Automated tests cover profile selection; manual accessibility matrix is recorded.

**Effort:** M.

### PS-106 — Centralize animation configuration without rewriting the renderer

**Outcome:** Visual changes become reviewable data changes rather than edits scattered through rendering code.

**Implementation:**

- Introduce `CelebrationProfile` and `GeometryProfile` value types in `PowerSnekKit`.
- Move hard-coded tuning values from `AppController` and style constants from `CometMath` behind those profiles where variation is legitimate.
- Keep pure motion functions and a single renderer.
- Add invariants: positive widths/durations, bounded opacities, valid lap count, completion exactly once.

**Acceptance:**

- Current visual behavior is reproduced by a `classic` profile.
- Existing tests pass without weakening tolerances.
- Adding a second profile does not add branches throughout `CometAnimator`.

**Effort:** M.

### PS-107 — Fix multi-display identity and lifecycle handling

**Outcome:** Display hot-plug, detach, and transient screen state cannot strand debounce or leave an overlay orphaned.

**Implementation:**

- Make display ID optional; never treat `0` as a valid shared fallback.
- Key active animation sessions by validated display identity.
- Observe `NSApplication.didChangeScreenParametersNotification`.
- Close sessions whose displays disappear and update frames/scales if display configuration changes.
- Pass `screen.backingScaleFactor` explicitly into the animation session.
- Replace `activeWindows` + `animatingScreens` with one session dictionary.

**Acceptance:**

- Disconnecting a display mid-animation cleans up immediately.
- Reconnecting can animate again.
- Two transient screens cannot collide on an invalid identity.
- Mixed 1x/2x displays render at the correct scale.

**Effort:** M.

### PS-108 — Add structured diagnostics and a support bundle

**Outcome:** “It did not fire” and “it stuttered” reports become diagnosable without telemetry.

**Implementation:**

- Use `Logger` categories for power transition, display session, animation completion reason, login item, updater, and release version.
- Add signposts around animation build/travel/finale/teardown.
- Keep logs local and avoid user content.
- Add “Copy diagnostics” to About/Settings with app version, macOS version, screen IDs/scales, current power state, settings summary, and recent non-sensitive errors.

**Acceptance:**

- A missed-fire support report can distinguish no battery-to-AC edge, disabled effect, invalid display, and animator failure.
- Diagnostics contain no usernames, paths, or secrets.
- Signposts are visible in Instruments.

**Effort:** M.

### PS-109 — Add a safe update path

**Outcome:** Installed users can receive fixes without rediscovering the GitHub page.

**Implementation options:**

1. **Sparkle:** mature direct-distribution updater, more dependency/release work.
2. **Lightweight update check:** compare current version to GitHub latest and open the direct DMG page; simpler, less seamless.

**Recommendation:** Start with a manual “Check for Updates…” backed by the GitHub release API. Adopt Sparkle only after repeat users exist and signed update automation is stable.

**Acceptance:**

- No automatic download or install without user intent.
- Update check fails quietly/offline and reports actionable errors on demand.
- Version comparison is tested, including prereleases.

**Effort:** M for manual check; L for Sparkle
**Dependencies:** PS-001.

## P1 — Engineering quality and performance gates

### PS-110 — Establish animation performance acceptance tests

**Outcome:** Aesthetic changes cannot silently introduce jank or excessive energy use.

**Test matrix:**

- built-in Retina at 60 Hz;
- ProMotion at 120 Hz;
- one 5K external plus built-in display;
- mixed 1x/2x backing scale if available;
- 1, 2, and 5 laps;
- Reduce Motion profile;
- display detach during travel.

**Measure:**

- frame interval and dropped-frame count;
- main-thread frame work;
- allocations per frame;
- GPU/compositor utilization;
- process energy during effect;
- idle wakeups/CPU after completion;
- layer/window count before and after.

**Initial gates:**

- no visible hitch in a reference screen recording;
- no leaked overlay windows/layers/display links after completion;
- 99th-percentile main-thread animation work below the active display's frame budget on reference hardware;
- idle CPU/wakeups return to baseline after every run.

**Acceptance:** Baseline report and Instruments trace paths are stored as release artifacts or documented reproducible evidence.

**Effort:** M.

### PS-111 — Optimize only the measured bottleneck

**Candidate experiments, in order:**

1. Reuse dash-pattern number objects or update only phase where segment length is unchanged.
2. Reduce segment count adaptively for low-power/60 Hz devices.
3. Replace expensive blur filters with shadow/radial-gradient equivalents where visually indistinguishable.
4. Rasterize only static groups proven expensive and verify Retina sharpness.
5. Consider a shader/Metal renderer only if Core Animation cannot meet the measured gate.

**Acceptance:** Every optimization includes before/after traces and side-by-side visual capture. Revert if visual quality regresses without material performance gain.

**Effort:** S–L depending on measurement
**Dependencies:** PS-110.

### PS-112 — Expand test coverage at OS boundaries

**Outcome:** Pure logic remains strong while the fragile orchestration edges gain regression coverage.

**Implementation:**

- Inject a screen/session abstraction around `AppController` for display identity and lifecycle tests.
- Inject power-state reads into `PowerMonitor` so notification sequences can be tested.
- Test completion exactly once for degenerate paths and watchdog teardown.
- Test settings migration when profiles are introduced.
- Add release workflow contract tests for tag/version/asset presence.
- Add site tests for direct-download success and no-asset fallback.

**Acceptance:** Tests reproduce the historical release failure and the `displayID == 0` collision before fixes.

**Effort:** L spread across owning tasks.

### PS-113 — Broaden CI evidence without multiplying noise

**Outcome:** Supported platforms match what releases claim.

**Implementation:**

- Keep primary CI on latest stable Xcode.
- Add at least one macOS 14 compatibility lane if runner/tool availability supports it.
- Verify universal release architecture even if unit tests run only on Apple Silicon.
- Add site `npm ci`, typecheck, build, and audit policy to CI.
- Stop tracking mutable TypeScript build-info output.
- Resolve the current three high-severity npm audit findings by inspection; do not run a forced major upgrade blindly.

**Acceptance:** README support claims map to actual CI/release evidence.

**Effort:** M.

## P2 — Validate growth and expand value carefully

### PS-201 — Run a 30-user validation sprint

**Outcome:** Decide whether the charging-only wedge deserves more investment.

**Plan:**

- Recruit 30 Mac utility/customization users after PS-001 through PS-005.
- Ask each to install, preview, choose a style, enable launch-at-login, and use it for one week.
- Collect structured answers:
  - Did installation work?
  - Did the effect fire on real plug-in?
  - Did you keep it running?
  - Which style did you choose?
  - Was the menu-bar slot worth it?
  - What moment should it celebrate next?
- Use aggregate site/download data as context, not a substitute for interviews.

**Go/no-go gates:**

- ≥80% complete install without help.
- ≥70% see a real plug-in event during the week.
- ≥40% choose to keep launch-at-login enabled at the end.
- Repeated spontaneous demand clusters around at most one or two next moments.

**Effort:** M operational
**Dependencies:** P0, PS-103 preferred.

### PS-202 — Package for Homebrew after the direct release is reliable

**Outcome:** Technical Mac users can install/update through a trusted familiar path.

**Implementation:**

- Create a cask backed by immutable signed/notarized versioned assets and checksum.
- Automate cask updates only after release verification passes.
- Add the command as a secondary install route, not the hero CTA.

**Acceptance:** Clean install, upgrade, uninstall, and checksum verification pass.

**Effort:** M
**Dependencies:** PS-001, PS-002, PS-109.

### PS-203 — Build a repeatable launch kit

**Outcome:** Promotion is a reproducible product operation rather than an improvised post.

**Assets:**

- 5-second native hero clip;
- 15-second vertical clip;
- two stills showing notch and external display;
- concise privacy/trust card;
- install link with campaign attribution;
- launch copy for relevant Mac utility communities;
- feedback form and issue template.

**Note:** Publishing/posting remains a separate explicit decision. This task only prepares assets and measurement.

**Acceptance:** Every asset points to the working direct download and uses consistent brand tokens.

**Effort:** M.

### PS-204 — Test a more useful charging finale

**Outcome:** Determine whether utility can deepen retention without becoming a dashboard.

**Experiment:** Show one compact, transient fact at the landing point—such as battery percentage or “Charging”—for less than one second after the visual finale. Keep it optional and local.

**Why this bet:** Adjacent notch utilities already use charging state as part of a larger persistent surface.[4][5] PowerSnek can offer the useful confirmation while preserving its full-border, one-shot, no-permission identity.

**Acceptance:**

- User can choose pure visual or visual + status.
- Text remains readable across notch/no-notch displays and accessibility modes.
- No persistent HUD or polling is introduced.
- Validation users prefer it over pure visual before it becomes default.

**Effort:** M
**Dependencies:** PS-201 evidence.

### PS-205 — Add at most one validated additional celebration moment

**Candidate moments:** full charge / optimized-charge threshold, external display connected, or selected Bluetooth device connected.

**Decision rule:** Implement only the highest-demand moment from PS-201 that preserves the no-permission, event-driven, one-shot model.

**Architecture:** Add a small `CelebrationTrigger` protocol only when a second implementation exists. Until then, keep `PowerMonitor` concrete.

**Acceptance:**

- Trigger is event-driven, not polled.
- User can enable each trigger independently.
- Duplicate system notifications debounce to one celebration.
- Idle performance contract still passes.

**Effort:** L
**Dependencies:** PS-201.

## P3 — Optional bets, not commitments

### PS-301 — Community theme packs

Start with built-in profiles. Consider import/export only after users create and share configurations manually. Avoid arbitrary executable plugins.

### PS-302 — Optional sound design

A subtle synchronized sound may increase delight but can also make the app socially hostile. Test muted-by-default previews before implementing system-event audio.

### PS-303 — Per-display routing

Allow built-in only / all displays / selected displays if multi-display users request it. Current all-display behavior is a distinctive strength and should remain the default.

### PS-304 — Mac App Store evaluation

Evaluate sandboxing, IOKit/AppKit behavior, updater implications, review risk, and economics only after direct distribution proves demand.

### PS-305 — Metal renderer

Do not schedule unless PS-110 proves Core Animation cannot meet frame/energy gates after smaller optimizations.

## Explicitly rejected for now

- Becoming a Boring Notch/NotchNook clone with media, calendar, file shelf, and HUD replacement.
- Persistent border lighting or continuous ambient animation.
- Mandatory account, cloud sync, subscriptions, or user-level analytics.
- Global keyboard shortcut without repeated user demand.
- Generic plugin/event-bus architecture before a second trigger or renderer exists.
- Full SwiftUI/AppKit rewrite.
- Optimizing collection complexity where cardinality is only a few displays.
- Shipping more effects before the release funnel works.

## Recommended delivery sequence

### Sprint 0 — Restore reality (2–4 days)

1. PS-001 repair release publication.
2. PS-002 publish `v0.2.1`.
3. PS-003 direct-download flow.
4. PS-004 aggregate funnel baseline.

**Exit:** A stranger can install the current app, and we can observe the funnel.

### Sprint 1 — Make the promise credible (1 week)

1. PS-005 real recording.
2. PS-101 visual system.
3. PS-102 status icon/menu.
4. PS-105 Reduce Motion/accessibility.
5. PS-108 diagnostics.

**Exit:** Website, app, and menu surface feel like one trustworthy product.

### Sprint 2 — Make the aesthetic ownable (1–2 weeks)

1. PS-106 profile model.
2. PS-103 three tuned styles.
3. PS-104 onboarding revision.
4. PS-107 display lifecycle reliability.
5. PS-109 manual update check.

**Exit:** New users can choose a style, reliably experience it, and receive fixes.

### Sprint 3 — Prove the wedge (1–2 weeks elapsed)

1. PS-110 performance baseline.
2. PS-111 only if evidence requires it.
3. PS-201 30-user validation.
4. PS-203 launch kit.

**Exit:** Evidence supports either continuing, narrowing, or stopping.

### After validation

- If retention and enthusiasm are strong: PS-202, PS-204, then one PS-205 trigger.
- If acquisition is strong but retention weak: test PS-204 before adding broad triggers.
- If acquisition remains weak with a working funnel and real demo: reposition or stop. Do not bury the result under more features.

## Success metrics

### Funnel

- Landing → download click conversion.
- Download click → GitHub asset download ratio.
- Install success in moderated/unmoderated validation.
- Release asset availability and direct-link uptime.

### Activation

- First-session preview completion in user testing.
- Real plug-in event observed during validation week.
- Launch-at-login retained after one week.

### Product quality

- Crash-free validation sessions.
- No orphan overlay/display-link sessions.
- Reduced Motion compliance.
- Performance gates from PS-110.
- Support reports diagnosable from local logs.

### Growth

- Organic direct visits and attributed campaign visits.
- GitHub asset downloads by version.
- Qualitative shares/mentions using the real effect.
- Homebrew installs only after a cask exists.

## First decision

Approve Sprint 0 before discussing new animation features. The current highest-value engineering work is to make the signed/notarized app the workflow already built actually appear on the release users are sent to.

## Sources

[1] https://api.github.com/repos/funsaized/PowerSnek/releases/latest — GitHub API: PowerSnek latest release
[2] https://api.github.com/repos/funsaized/PowerSnek — GitHub API: PowerSnek repository
[4] https://github.com/TheBoredTeam/boring.notch — Boring Notch repository
[5] https://theboring.name — Boring Notch website
[7] https://developer.apple.com/documentation/appkit/nsview/displaylink%28target%3Aselector%3A%29 — Apple Developer: NSView displayLink
