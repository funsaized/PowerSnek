import SwiftUI
import PowerSnekKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    // Must be `var`, not `let`: SwiftUI forms a writable key path through this
    // for bindings such as `$env.settings.effectEnabled` in MenuBarExtra, which
    // does not compile if it is `let`. It is never reassigned.
    var settings = SettingsStore()
    lazy var controller = AppController(settings: settings)
    lazy var welcomeController = WelcomeWindowController(
        settings: settings,
        controller: controller,
        openSettings: AppEnvironment.openSettings
    )
    private init() {}

    /// Opens the SwiftUI `Settings` scene from non-SwiftUI (AppKit) contexts.
    static func openSettings() {
        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) { return }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.shared
        // Start listening for charger connect events.
        env.controller.start()
        // First launch: show the welcome window once the UI is ready.
        if !env.settings.hasCompletedOnboarding {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                env.welcomeController.show()
            }
        }
    }
}

@main
struct PowerSnekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra("PowerSnek", image: "MenuBarIcon") {
            Toggle("Enabled", isOn: $env.settings.effectEnabled)
            Button("Test Animation") { env.controller.runTestAnimation() }
            Divider()
            SettingsLink { Text("Settings…") }
            Button("Welcome to PowerSnek") { env.welcomeController.show() }
            Divider()
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(env.settings)
        }
    }
}
