import SwiftUI
import PowerSnekKit

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var launchAtLogin = LoginItemManager.isEnabled

    private var cometColor: Binding<Color> {
        Binding(
            get: { Color(HexColor.nsColor(fromHex: settings.cometColorHex) ?? .systemGreen) },
            set: { settings.cometColorHex = HexColor.hex(from: NSColor($0)) }
        )
    }

    var body: some View {
        Form {
            Toggle("Enable effect", isOn: $settings.effectEnabled)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }

            ColorPicker("Comet color", selection: cometColor, supportsOpacity: false)

            Stepper("Laps: \(settings.lapCount)", value: $settings.lapCount, in: 1...5)

            VStack(alignment: .leading, spacing: 2) {
                Text("Speed")
                HStack {
                    Text("slower").font(.caption).foregroundStyle(.secondary)
                    // Higher lapDuration = slower; invert the slider so right = faster.
                    // Range 2.0..6.0 s/lap (sum 8.0); even "fastest" is gentle.
                    Slider(value: Binding(
                        get: { 8.0 - settings.lapDuration },     // maps 2.0..6.0 -> 6.0..2.0
                        set: { settings.lapDuration = 8.0 - $0 }
                    ), in: 2.0...6.0)
                    Text("faster").font(.caption).foregroundStyle(.secondary)
                }
            }

            Button("Preview") { AppEnvironment.shared.controller.runTestAnimation() }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { launchAtLogin = LoginItemManager.isEnabled }
    }
}
