import SwiftUI
import PowerSnekKit

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var loginItem: LoginItemModel
    @EnvironmentObject private var updater: UpdateChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Previews the celebration on the display showing Settings.
    let onPreview: @MainActor () -> Void

    @State private var showAdvanced = false
    @State private var pendingPreview: Task<Void, Never>?

    private var profile: CelebrationProfile { settings.activeProfile }

    private var totalSeconds: String {
        String(format: "%.1f", profile.totalDuration(laps: settings.lapCount, lapDuration: settings.lapDuration))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    StylePicker(settings: settings)
                        .padding(.vertical, 4)
                    HStack(spacing: 8) {
                        Text("\(settings.lapCount) \(settings.lapCount == 1 ? "lap" : "laps") · about \(totalSeconds) s")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if settings.isCustomized {
                            Text("Customized")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                            Button("Reset to \(profile.name)") { settings.apply(profile) }
                                .buttonStyle(.link)
                        }
                    }
                    .font(.callout)
                } header: {
                    Text("Style")
                }

                Section("Celebration") {
                    Toggle("Celebrate when I plug in", isOn: $settings.effectEnabled)
                    Toggle(isOn: $settings.showBatteryReadout) {
                        Text("Show battery level after landing")
                        Text("A short “47% · Charging” under the notch.")
                    }
                    Toggle(isOn: $settings.pauseOverFullScreen) {
                        Text("Pause over full-screen apps")
                        Text("Skips displays showing a full-screen app, video, or presentation.")
                    }
                    Toggle(isOn: $settings.hideFromScreenCapture) {
                        Text("Hide from screen recordings & sharing")
                        Text("Keeps the celebration out of screenshots, recordings, and calls.")
                    }
                }

                Section {
                    DisclosureGroup("Color & timing", isExpanded: $showAdvanced) {
                        ColorSwatchRow(settings: settings)
                        Stepper(value: $settings.lapCount, in: 1...5) {
                            Text("Laps: \(settings.lapCount)")
                        }
                        LabeledContent("Speed") {
                            HStack {
                                Text("slower").font(.caption).foregroundStyle(.secondary)
                                // Higher lapDuration = slower; invert so right = faster.
                                // Range 2.0...6.0 s (sum 8.0); even "fastest" is gentle.
                                Slider(value: Binding(
                                    get: { 8.0 - settings.lapDuration },
                                    set: { settings.lapDuration = 8.0 - $0 }
                                ), in: 2.0...6.0)
                                Text("faster").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("General") {
                    LaunchAtLoginToggle(model: loginItem,
                                        caption: "PowerSnek has to be running to notice your charger.")
                    Toggle("Check for updates automatically", isOn: $settings.checkForUpdatesAutomatically)
                    LabeledContent("Version \(UpdateChecker.currentVersion)") {
                        if let update = updater.available {
                            Button("Download \(update.version.description)…") {
                                NSWorkspace.shared.open(update.downloadURL)
                            }
                        } else {
                            Button(updater.isChecking ? "Checking…" : "Check Now") { updater.checkNow() }
                                .disabled(updater.isChecking)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                if reduceMotion {
                    Label("Reduce Motion is on: celebrations glow in place.", systemImage: "figure.walk.motion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onPreview()
                } label: {
                    Label("Preview", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500, height: 660)
        .tint(Brand.accent)
        .onAppear { loginItem.refresh() }
        // Changing how it looks previews it (debounced, on this display).
        .onChange(of: settings.styleID) { schedulePreview() }
        .onChange(of: settings.cometColorHex) { schedulePreview() }
        .onChange(of: settings.lapCount) { schedulePreview() }
        .onChange(of: settings.lapDuration) { schedulePreview() }
    }

    private func schedulePreview() {
        pendingPreview?.cancel()
        pendingPreview = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            onPreview()
        }
    }
}

/// Style colors plus a couple of extras, and a custom color well.
private struct ColorSwatchRow: View {
    @ObservedObject var settings: SettingsStore

    private struct Preset: Identifiable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    private static let presets = [
        Preset(name: "Electric green", hex: "#34FF6A"),
        Preset(name: "Chartreuse", hex: "#C3FB1C"),
        Preset(name: "Aqua", hex: "#3CE6D2"),
        Preset(name: "Volt yellow", hex: "#F5FF3B"),
        Preset(name: "Ice", hex: "#E8ECFF"),
        Preset(name: "Hot pink", hex: "#FF5AC8"),
        Preset(name: "Ember", hex: "#FF8A3D"),
    ]

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: HexColor.nsColor(fromHex: settings.cometColorHex) ?? .systemGreen) },
            set: { settings.cometColorHex = HexColor.hex(from: NSColor($0)) }
        )
    }

    var body: some View {
        LabeledContent("Color") {
            HStack(spacing: 7) {
                ForEach(Self.presets) { preset in
                    let isCurrent = settings.cometColorHex.uppercased() == preset.hex
                    Button {
                        settings.cometColorHex = preset.hex
                    } label: {
                        Circle()
                            .fill(Color(nsColor: HexColor.nsColor(fromHex: preset.hex) ?? .systemGreen))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(isCurrent ? 0.85 : 0.15),
                                                           lineWidth: isCurrent ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : [.isButton])
                }
                ColorPicker("Custom color", selection: customColor, supportsOpacity: false)
                    .labelsHidden()
                    .help("Very dark colors are brightened so the comet stays visible.")
            }
        }
    }
}
