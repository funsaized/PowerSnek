import SwiftUI
import PowerSnekKit

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()
    let settings = SettingsStore()
    let loginItem = LoginItemModel()
    lazy var controller = AppController(settings: settings)
    lazy var updater = UpdateChecker(settings: settings)
    lazy var settingsController = SettingsWindowController { [unowned self] in
        AnyView(SettingsView(onPreview: { [unowned self] in
                    self.controller.preview(on: self.settingsController.screen)
                })
                .environmentObject(self.settings)
                .environmentObject(self.loginItem)
                .environmentObject(self.updater))
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
        env.updater.startAutomaticChecks()
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
    private let env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra("PowerSnek", image: "MenuBarIcon") {
            MenuContent(env: env,
                        settings: env.settings,
                        loginItem: env.loginItem,
                        updater: env.updater)
        }
    }
}

/// The menu bar menu: status, the everyday actions, and the app's version.
private struct MenuContent: View {
    let env: AppEnvironment
    @ObservedObject var settings: SettingsStore
    @ObservedObject var loginItem: LoginItemModel
    @ObservedObject var updater: UpdateChecker

    private var status: String {
        if !settings.effectEnabled { return "Paused" }
        if !loginItem.state.isOn { return "Ready (won't start at login)" }
        return "Ready for the next charge"
    }

    var body: some View {
        Text(status)
        Toggle("Celebrate When Plugged In", isOn: $settings.effectEnabled)
        Button("Preview Celebration") { env.controller.preview() }
            .keyboardShortcut("p")
        Picker("Style", selection: Binding(
            get: { settings.styleID },
            set: { id in
                settings.apply(CelebrationProfile.named(id))
                env.controller.preview()
            }
        )) {
            ForEach(CelebrationProfile.all) { Text($0.name).tag($0.id) }
        }
        Divider()
        if let update = updater.available {
            Button("Update Available: PowerSnek \(update.version.description)…") {
                NSWorkspace.shared.open(update.downloadURL)
            }
        }
        Button("Settings…") { env.settingsController.show() }
            .keyboardShortcut(",")
        Button("Welcome to PowerSnek") { env.welcomeController.show() }
        Button("Check for Updates…") { updater.checkNow() }
            .disabled(updater.isChecking)
        Divider()
        Text("PowerSnek \(UpdateChecker.currentVersion)")
        Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
