import AppKit
import SwiftUI
import PowerSnekKit

/// Owns the first-run welcome window's lifecycle. Hosting the SwiftUI
/// `WelcomeView` in an AppKit `NSWindow` (rather than a SwiftUI `Window` scene)
/// makes centering + activation reliable from an `LSUIElement` agent app.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private let settings: SettingsStore
    private let loginItem: LoginItemModel
    private let controller: AppController
    private let openSettings: @MainActor () -> Void
    private var window: NSWindow?

    init(settings: SettingsStore,
         loginItem: LoginItemModel,
         controller: AppController,
         openSettings: @escaping @MainActor () -> Void) {
        self.settings = settings
        self.loginItem = loginItem
        self.controller = controller
        self.openSettings = openSettings
    }

    /// Show the window, or bring it front if already open (idempotent).
    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = WelcomeView(
            loginItem: loginItem,
            onPreview: { [weak self] in self?.controller.runTestAnimation() },
            onCustomize: { [weak self] in self?.openSettings() },
            onDone: { [weak self] in self?.dismiss() }
        )

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Welcome to PowerSnek"
        win.contentView = NSHostingView(rootView: root)
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.moveToActiveSpace]
        win.delegate = self
        win.center()
        window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        window?.close()   // windowWillClose marks onboarding complete
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Done or the red close button both complete onboarding (no re-nag).
        settings.hasCompletedOnboarding = true
        window = nil
    }
}
