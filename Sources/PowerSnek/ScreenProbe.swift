import AppKit
import CoreGraphics
import PowerSnekKit

/// Read-only system probes used to decide whether, and where, to celebrate.
/// None of these need Accessibility or Screen Recording permission.
@MainActor
enum ScreenProbe {
    /// False on the lock screen, while another user's session is frontmost
    /// (fast user switching), or when this session isn't on the console.
    static func isSessionPresentable() -> Bool {
        guard let info = CGSessionCopyCurrentDictionary() as NSDictionary? as? [String: Any] else {
            return true
        }
        if let onConsole = info["kCGSSessionOnConsoleKey"] as? Bool, !onConsole { return false }
        if let locked = info["CGSSessionScreenIsLocked"] as? Bool, locked { return false }
        return true
    }

    static func isAsleep(_ displayID: CGDirectDisplayID) -> Bool {
        CGDisplayIsAsleep(displayID) != 0
    }

    /// Someone can see at least one display right now.
    static func isAnythingPresentable() -> Bool {
        isSessionPresentable()
            && NSScreen.screens.contains { screen in
                guard let id = screen.displayID else { return false }
                return !isAsleep(id)
            }
    }

    /// Whether `screen` is showing a full-screen app, video, or presentation.
    static func isFullScreenAppShowing(on screen: NSScreen, displayID: CGDirectDisplayID) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let windows = raw.compactMap { entry -> WindowSnapshot? in
            guard let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                return nil
            }
            return WindowSnapshot(bounds: bounds,
                                  layer: (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                                  alpha: (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1,
                                  ownerPID: (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0)
        }
        return FullScreenCoverage.isFullScreenAppShowing(
            on: CGDisplayBounds(displayID),
            topInset: screen.safeAreaInsets.top,
            windows: windows,
            excludingPID: ProcessInfo.processInfo.processIdentifier)
    }
}

extension NSScreen {
    /// The display's Core Graphics ID, or nil when AppKit doesn't report a
    /// valid one. Never falls back to a shared placeholder, which would make
    /// two transient screens collide on the same per-display debounce.
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let id = CGDirectDisplayID(number.uint32Value)
        return id == 0 ? nil : id   // 0 is kCGNullDirectDisplay
    }
}

/// Tells the controller when the user may be able to see the screen again:
/// displays woke, the system woke, the screen unlocked, or this session
/// became active. Each signal is delayed briefly so NSScreen state settles.
@MainActor
final class PresentationMonitor {
    private var onPossiblyPresentable: (@MainActor () -> Void)?
    private var tokens: [NSObjectProtocol] = []
    private var pendingCheck: Task<Void, Never>?

    func start(onPossiblyPresentable: @escaping @MainActor () -> Void) {
        self.onPossiblyPresentable = onPossiblyPresentable
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            tokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleCheck() }
            })
        }
        tokens.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        })
    }

    private func scheduleCheck() {
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.onPossiblyPresentable?()
        }
    }
}
