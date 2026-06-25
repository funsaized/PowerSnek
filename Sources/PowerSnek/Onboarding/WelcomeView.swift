import SwiftUI
import PowerSnekKit

/// First-run welcome content. Pure view: all side effects arrive as callbacks
/// (preview / customize / done); launch-at-login is handled locally via
/// `LoginItemManager`, mirroring `SettingsView`.
struct WelcomeView: View {
    let onPreview: @MainActor () -> Void
    let onCustomize: @MainActor () -> Void
    let onDone: @MainActor () -> Void

    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var didAutoPreview = false

    private let accent = Color(red: 0.20, green: 1.0, blue: 0.42)   // brand green ≈ #34FF6A

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 76, height: 76)
                Text("PowerSnek")
                    .font(.system(size: 26, weight: .bold))
                Text("A jolt of green when you plug in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button { onPreview() } label: {
                    Label("Replay preview", systemImage: "play.circle")
                }
                .buttonStyle(.link)
                .padding(.top, 2)
            }
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 16) {
                bullet("sparkles", "It traces your notch",
                       "The comet hugs your display's exact contour — notch and all.")
                bullet("bolt.fill", "Only when you plug in",
                       "Fires the instant the charger connects, then fades on its own.")
                bullet("gauge.medium", "Zero battery cost",
                       "A one-shot flourish, not a running animation.")
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)

            Spacer(minLength: 18)

            Divider().padding(.horizontal, 30)

            Toggle("Launch PowerSnek at login", isOn: $launchAtLogin)
                .padding(.horizontal, 30)
                .padding(.top, 16)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }

            HStack {
                Button("Customize…") { onCustomize() }
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.top, 16)
            .padding(.bottom, 26)
        }
        .frame(width: 460, height: 540)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
            guard !didAutoPreview else { return }
            didAutoPreview = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onPreview()
            }
        }
    }

    private func bullet(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
