import SwiftUI
import PowerSnekKit

/// First-run welcome: see the real effect, pick a style, keep launch at
/// login on, and learn where PowerSnek lives. Side effects arrive as
/// callbacks (preview / customize / done); launch-at-login goes through the
/// shared `LoginItemModel`, like `SettingsView`.
struct WelcomeView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var loginItem: LoginItemModel
    let onPreview: @MainActor () -> Void
    let onCustomize: @MainActor () -> Void
    let onDone: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAutoPreview = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("PowerSnek")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("A jolt of light around your screen every time you plug in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 26)
            .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pick a style").font(.headline)
                    Spacer()
                    Button {
                        onPreview()
                    } label: {
                        Label("Replay preview", systemImage: "play.circle")
                    }
                    .buttonStyle(.link)
                }
                StylePicker(settings: settings, compact: true) { _ in onPreview() }
                if reduceMotion {
                    Text("Reduce Motion is on, so PowerSnek glows in place instead of racing around.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 22)

            Spacer(minLength: 16)

            Divider().padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 14) {
                LaunchAtLoginToggle(model: loginItem,
                                    caption: "PowerSnek has to be running to notice your charger.")
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image("MenuBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Brand.accent)
                        .accessibilityHidden(true)
                    Text("You're all set: PowerSnek is ready in your menu bar. Click its icon to preview, pause, or switch styles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.top, 16)

            HStack {
                Button("More Settings…") { onCustomize() }
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(width: 500, height: 560)
        .tint(Brand.accent)
        .onAppear {
            loginItem.refresh()
            guard !didAutoPreview else { return }
            didAutoPreview = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onPreview()
            }
        }
    }
}
