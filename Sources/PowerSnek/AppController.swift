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

    /// Real charger-connect handler: fires on every display when the effect is enabled.
    public func fireAll() {
        guard settings.effectEnabled else { return }
        fireOnAllScreens()
    }

    /// Preview/test command: fires on every display regardless of `effectEnabled`.
    public func runTestAnimation() {
        fireOnAllScreens()
    }

    private func fireOnAllScreens() {
        for screen in NSScreen.screens {
            fire(on: screen)
        }
    }

    private func fire(on screen: NSScreen) {
        let id = screen.displayID
        guard !animatingScreens.contains(id) else { return }   // debounce
        // Invariant: CometAnimator.run MUST eventually call its completion (it
        // does, including its early-return guard). The completion removes `id`
        // here; if it were ever skipped, this screen would stay "animating" and
        // never fire again until relaunch.
        animatingScreens.insert(id)

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
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
    }
}
