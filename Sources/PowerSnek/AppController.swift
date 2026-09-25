import AppKit
import PowerSnekKit

@MainActor
public final class AppController {
    private let settings: SettingsStore
    private let monitor = PowerMonitor()
    private let presentation = PresentationMonitor()
    private var gate = CelebrationGate()
    private var sessions = SessionRegistry<CGDirectDisplayID, DisplaySession>()
    private var screenObserver: NSObjectProtocol?

    /// Everything one display's celebration owns, torn down together.
    private struct DisplaySession {
        let window: CometOverlayWindow
        let animator: CometAnimator
        /// The screen frame the outline was built for; a change means the
        /// display was reconfigured and the session is stale.
        let frame: CGRect
    }

    // Geometry tuning constants
    private let inset: CGFloat = 2
    private let builtInFallbackRadius: CGFloat = 12
    private let notchInnerRadius: CGFloat = 6

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func start() {
        monitor.start { [weak self] in
            Task { @MainActor in self?.chargerConnected() }
        }
        presentation.start { [weak self] in
            self?.userMayBeBack()
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    /// Real charger-connect handler: celebrates on every visible display, or
    /// defers until the user can see the screen (see `CelebrationGate`).
    public func chargerConnected() {
        guard settings.effectEnabled else {
            Log.power.info("charger connected; effect disabled")
            return
        }
        switch gate.chargerConnected(at: Date(), presentable: ScreenProbe.isAnythingPresentable()) {
        case .fireNow:
            Log.power.info("charger connected; celebrating")
            celebrate(on: NSScreen.screens, isPreview: false)
        case .deferred:
            Log.power.info("charger connected while the screen isn't visible; deferring")
        }
    }

    /// Preview/test command: runs regardless of `effectEnabled` and of the
    /// full-screen pause (the user asked for it), restarting any celebration
    /// already on screen. `screen == nil` previews on every display.
    public func preview(on screen: NSScreen? = nil) {
        celebrate(on: screen.map { [$0] } ?? NSScreen.screens, isPreview: true)
    }

    private func userMayBeBack() {
        guard ScreenProbe.isAnythingPresentable() else { return }
        let onAC = PowerMonitor.currentState() == .ac
        guard gate.becamePresentable(at: Date(), stillOnAC: onAC) else { return }
        guard settings.effectEnabled else { return }
        Log.power.info("screen visible again; playing deferred celebration")
        celebrate(on: NSScreen.screens, isPreview: false)
    }

    private func celebrate(on screens: [NSScreen], isPreview: Bool) {
        let spec = makeSpec()
        for screen in screens {
            guard let id = screen.displayID else {
                Log.display.error("screen without a display ID; skipping")
                continue
            }
            if ScreenProbe.isAsleep(id) {
                Log.display.info("display \(id) is asleep; skipping")
                continue
            }
            if !isPreview, settings.pauseOverFullScreen,
               ScreenProbe.isFullScreenAppShowing(on: screen, displayID: id) {
                Log.display.info("display \(id) is showing a full-screen app; skipping")
                continue
            }
            if sessions.isActive(id) {
                guard isPreview else { continue }   // per-display debounce
                // Completes synchronously, which ends the session.
                let running = sessions.sessions[id]?.animator
                running?.cancel()
            }
            startSession(on: screen, id: id, spec: spec)
        }
    }

    /// Resolves the style, the user's overrides, Reduce Motion, and the
    /// battery readout (read once, shared by every display).
    private func makeSpec() -> CelebrationSpec {
        let color = HexColor.nsColor(fromHex: VisibleColor.clampedHex(settings.cometColorHex))
            ?? NSColor.systemGreen
        let readout = settings.showBatteryReadout ? ChargeInfoReader.snapshot().map(ChargeReadout.text(for:)) : nil
        return CelebrationSpec(profile: settings.activeProfile,
                               color: color,
                               laps: settings.lapCount,
                               lapDuration: settings.lapDuration,
                               readout: readout,
                               reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func startSession(on screen: NSScreen, id: CGDirectDisplayID, spec: CelebrationSpec) {
        let input = ScreenGeometry.outlineInput(for: screen,
                                                inset: inset,
                                                builtInFallbackRadius: builtInFallbackRadius,
                                                notchInnerRadius: notchInnerRadius)
        let outline = PerimeterPathBuilder.buildOutline(input)

        let window = CometOverlayWindow(screen: screen)
        window.sharingType = settings.hideFromScreenCapture ? .none : .readOnly
        window.orderFrontRegardless()

        let animator = CometAnimator(host: window.hostLayer,
                                     view: window.contentView!,   // set in CometOverlayWindow.init
                                     outline: outline,
                                     spec: spec,
                                     contentsScale: screen.backingScaleFactor)
        sessions.begin(id, DisplaySession(window: window, animator: animator, frame: screen.frame))

        // Invariant: CometAnimator.start calls completion exactly once
        // (finale end, cancel, watchdog, or degenerate path), which ends the
        // session so the display can celebrate again.
        animator.start { [weak self, weak window] in
            window?.orderOut(nil)
            guard let self, let current = self.sessions.sessions[id], current.window === window else { return }
            self.sessions.end(id)
        }
    }

    /// Displays were added, removed, or reconfigured: end sessions whose
    /// display is gone or whose frame no longer matches their outline.
    private func screensChanged() {
        var liveFrames: [CGDirectDisplayID: CGRect] = [:]
        for screen in NSScreen.screens {
            if let id = screen.displayID { liveFrames[id] = screen.frame }
        }
        let stale = sessions.keys { id, session in liveFrames[id] != session.frame }
        for id in stale {
            Log.display.info("display \(id) changed mid-celebration; ending it")
            let running = sessions.sessions[id]?.animator
            running?.cancel()
        }
    }
}
