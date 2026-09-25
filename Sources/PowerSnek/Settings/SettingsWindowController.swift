import AppKit
import SwiftUI

/// Owns the Settings window. PowerSnek is an `LSUIElement` agent, where the
/// SwiftUI `Settings` scene is unreliable: the private `showSettingsWindow:`
/// action is ignored on macOS 14+, and the window can open behind the
/// frontmost app. Hosting the view in our own `NSWindow` (like onboarding)
/// makes opening, focusing, and moving to the current Space deterministic.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let makeContent: @MainActor () -> AnyView
    private var window: NSWindow?

    init(makeContent: @escaping @MainActor () -> AnyView) {
        self.makeContent = makeContent
    }

    /// The display showing the Settings window, if it is open.
    var screen: NSScreen? { window?.screen }

    /// Settings is on screen (and auto-previews its own changes).
    var isOpen: Bool { window?.isVisible == true }

    /// Show the window, or bring it front if already open (idempotent).
    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let win = NSWindow(contentViewController: NSHostingController(rootView: makeContent()))
        win.styleMask = [.titled, .closable]
        win.title = "PowerSnek Settings"
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.moveToActiveSpace]
        win.delegate = self
        win.center()
        window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
