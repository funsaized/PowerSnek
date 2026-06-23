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
