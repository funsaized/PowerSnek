import SwiftUI

@main
struct PowerSnekApp: App {
    var body: some Scene {
        MenuBarExtra("PowerSnek", systemImage: "bolt.fill") {
            Button("Quit PowerSnek") { NSApplication.shared.terminate(nil) }
        }
    }
}
