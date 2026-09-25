import SwiftUI
import PowerSnekKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    // Must be `var`, not `let`: SwiftUI forms a writable key path through this
    // for bindings such as `$env.settings.effectEnabled` in MenuBarExtra, which
    // does not compile if it is `let`. It is never reassigned.
    var settings = SettingsStore()
    let loginItem = LoginItemModel()
    lazy var controller = AppController(settings: settings)
    lazy var settingsController = SettingsWindowController { [unowned self] in
        AnyView(SettingsView()
            .environmentObject(self.settings)
            .environmentObject(self.loginItem))
    }
    lazy var welcomeController = WelcomeWindowController(
        settings: settings,
        loginItem: loginItem,
        controller: controller,
        openSettings: { [unowned self] in self.settingsController.show() }
    )
    private init() {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let env = AppEnvironment.shared
        // Start listening for charger connect events.
        env.controller.start()
        // First launch: turn on launch-at-login (shown, and reversible, in the
        // welcome window), then show the welcome window once the UI is ready.
        if !env.settings.hasCompletedOnboarding {
            env.loginItem.applyFirstRunDefault(hasCompletedOnboarding: false)
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
            Button("Settings…") { env.settingsController.show() }
                .keyboardShortcut(",")
            Button("Welcome to PowerSnek") { env.welcomeController.show() }
            Divider()
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
