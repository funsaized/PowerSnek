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
    private init() {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start listening for charger connect events.
        AppEnvironment.shared.controller.start()
    }
}

@main
struct PowerSnekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra("PowerSnek", systemImage: "bolt.fill") {
            Toggle("Enabled", isOn: $env.settings.effectEnabled)
            Button("Test Animation") { env.controller.runTestAnimation() }
            Divider()
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(env.settings)
        }
    }
}
