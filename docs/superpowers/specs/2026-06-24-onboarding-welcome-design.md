# PowerSnek — First-Run Onboarding (Welcome Window) Design Spec

**Date:** 2026-06-24
**Status:** Approved for planning
**Target:** macOS 14+ (built/tested on macOS 26, Apple Silicon)

## 1. Summary

PowerSnek's effect only fires when a charger is connected — which a new user
may not do for hours. So on first launch they see a menu bar icon and nothing
else, and many uninstall before ever seeing the effect. This feature adds a
**single first-run welcome window** that previews the comet immediately,
explains the value, and offers **Launch at login** so the app survives past day
one. It is re-openable from the menu bar but shows automatically only once.

## 2. Goals & non-goals

### Goals
- On first launch, show one welcome window that **auto-previews** the effect
  (~0.5s after appearing) so the user gets an instant "aha".
- Explain what PowerSnek does (one-liner + the three value bullets).
- Offer **Launch at login** inline (the key day-one retention conversion).
- Provide a **Customize…** action that opens Settings, and a **Done** action.
- Show automatically only once; allow re-opening from the menu bar.

### Non-goals (YAGNI)
- No multi-step wizard; one window only.
- No inline color/preset customization (lives in Settings; presets are a
  separate future feature).
- No Reduce-Motion handling here (its own future feature — deliberately not
  half-built).
- No analytics/telemetry.

## 3. Architecture overview

A SwiftUI `WelcomeView` is hosted in an AppKit `NSWindow` managed by a
`WelcomeWindowController`. AppKit is used (rather than a SwiftUI `Window` scene)
because reliably centering, activating, and front-ordering a window from an
`LSUIElement` agent app is fiddly with SwiftUI scenes but straightforward with
an explicit window controller — and it matches the AppKit we already use for
the overlay windows.

```
AppDelegate.applicationDidFinishLaunching
        │  (after a short delay; if !hasCompletedOnboarding)
        ▼
WelcomeWindowController.show()
        │  creates centered NSWindow + NSHostingView(WelcomeView)
        │  NSApp.activate(ignoringOtherApps: true); makeKeyAndOrderFront
        ▼
WelcomeView
   ├─ .onAppear → after ~0.5s → onPreview()  ─────► AppController.runTestAnimation()
   ├─ "Replay"  → onPreview()                ─────► AppController.runTestAnimation()
   ├─ "Launch at login" toggle  ⇄  LoginItemManager (binding)
   ├─ "Customize…" → onCustomize()           ─────► open Settings
   └─ "Done" / window close → onDone()        ─────► hasCompletedOnboarding = true; close
```

## 4. Components

Each unit has one responsibility and a defined interface.

### 4.1 `SettingsStore.hasCompletedOnboarding`
- **Purpose:** Persist whether the welcome window has been shown/dismissed.
- **Interface:** `@Published var hasCompletedOnboarding: Bool` on the existing
  `SettingsStore`, backed by `UserDefaults` key `hasCompletedOnboarding`,
  registered default `false`. Written `true` when onboarding is dismissed.
- **Why on SettingsStore:** keeps all persisted prefs in one place, reuses the
  injectable-`UserDefaults` test pattern.

### 4.2 `WelcomeWindowController`
- **Purpose:** Own the welcome window's lifecycle.
- **Implementation:** A small `final class` holding an optional `NSWindow`.
  `show()`:
  - If a window already exists, just bring it front (re-open is idempotent).
  - Else create an `NSWindow` (styleMask `[.titled, .closable]`, not resizable,
    not miniaturizable), title "Welcome to PowerSnek", fixed content size
    ~460×540, `center()`, content view = `NSHostingView(rootView: WelcomeView(...))`.
  - `NSApp.activate(ignoringOtherApps: true)`, `makeKeyAndOrderFront(nil)`.
  - Acts as the window's delegate; on `windowWillClose`, invoke the dismissal
    path (mark complete) and release the window reference.
- **Interface:** `init(settings:controller:openSettings:)`, `show()`.
- **Depends on:** `SettingsStore` (flag), `AppController` (preview),
  `LoginItemManager` (toggle), an `openSettings` closure.

### 4.3 `WelcomeView`
- **Purpose:** Present the onboarding content; emit user intents via callbacks.
- **Interface (pure view — no singletons reached inside):**
  `WelcomeView(launchAtLogin: Binding<Bool>, onPreview: () -> Void,
  onCustomize: () -> Void, onDone: () -> Void)`.
- **Layout (top→bottom):** app icon, "PowerSnek", one-liner
  ("A jolt of green when you plug in."), the three value bullets (traces your
  notch / only when you plug in / zero battery cost), a "Launch at login"
  `Toggle` bound to `launchAtLogin`, a row with "Customize…" (secondary) and
  "Done" (prominent) buttons, and a small "Replay" control near the top/preview
  affordance.
- **Behavior:** `.onAppear` schedules `onPreview()` once after ~0.5s (guarded so
  it fires a single time per appearance). "Replay" calls `onPreview()`.

### 4.4 Wiring (`AppDelegate` / `AppEnvironment` / menu)
- **First run:** in `applicationDidFinishLaunching`, after a brief delay
  (so the menu bar extra and screens are ready), if
  `!settings.hasCompletedOnboarding` call `welcomeController.show()`.
- **Re-open:** add a menu item **"Welcome to PowerSnek"** in the `MenuBarExtra`
  menu that calls `welcomeController.show()` (does not reset the flag).
- **Ownership:** `AppEnvironment.shared` gains a `welcomeController`
  constructed with the shared `settings`, `controller`, and an `openSettings`
  closure.

### 4.5 Opening Settings from the welcome window
- The `onCustomize`/`openSettings` closure opens the SwiftUI `Settings` scene.
  Use the standard responder action on macOS 14+:
  `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`,
  with a fallback to `Selector(("showPreferencesWindow:"))`. Wrapped so a
  missing selector cannot crash. (Closing the welcome window is not required
  when opening Settings; both may be visible.)

## 5. Data flow (first run)

1. App launches as the menu bar agent; `AppDelegate` sees
   `hasCompletedOnboarding == false`.
2. After ~0.4s it calls `welcomeController.show()` → centered window appears,
   app activates.
3. `WelcomeView.onAppear` → after ~0.5s → `onPreview()` →
   `AppController.runTestAnimation()` → the comet sweeps every display's
   perimeter around the window. (Preview ignores `effectEnabled`.)
4. User optionally flips **Launch at login** (→ `LoginItemManager`), clicks
   **Customize…** (→ Settings) or **Replay** (→ preview again).
5. **Done** or the red close button → `hasCompletedOnboarding = true`; window
   closes. It never auto-shows again; the menu item can re-open it.

## 6. Edge cases & error handling

- **Close via red X** marks onboarding complete (no re-nag), same as Done.
- **Preview while effect disabled:** plays anyway (it is a demo, like Test
  Animation, which bypasses `effectEnabled`).
- **Re-open while already open:** `show()` is idempotent — front the existing
  window, don't create a second.
- **Multi-display:** preview fires on all displays (consistent with real
  behavior); the window is centered on the main display.
- **Settings selector unavailable:** the `openSettings` wrapper no-ops safely
  rather than crashing.
- **No special permissions** introduced.

## 7. Testing strategy

- **Unit (TDD):**
  - `SettingsStore.hasCompletedOnboarding` defaults to `false` and round-trips
    through an injected `UserDefaults` suite (extend `SettingsStoreTests`).
- **Manual:**
  - Reset the flag (`defaults delete com.powersnek.app hasCompletedOnboarding`)
    → relaunch → welcome window appears and auto-previews; toggle, Customize,
    Replay, Done all work; relaunch shows nothing; menu item re-opens it;
    closing via X also suppresses future auto-show.

## 8. Files (proposed)

```
Sources/PowerSnek/
  Onboarding/WelcomeWindowController.swift   # new — AppKit window lifecycle
  Onboarding/WelcomeView.swift               # new — SwiftUI content
  PowerSnekApp.swift                         # modify — AppEnvironment + menu item + first-run show
Sources/PowerSnekKit/
  SettingsStore.swift                        # modify — hasCompletedOnboarding
Tests/PowerSnekKitTests/
  SettingsStoreTests.swift                   # modify — flag default + persistence
```

## 9. Open risks

1. **Activating a window from an `LSUIElement` agent app** — mitigated by
   `NSApp.activate(ignoringOtherApps:)` + `makeKeyAndOrderFront`; verify it
   comes to the front on first run.
2. **`showSettingsWindow:` selector name** can vary by OS — guarded with a
   fallback and a safe no-op.
