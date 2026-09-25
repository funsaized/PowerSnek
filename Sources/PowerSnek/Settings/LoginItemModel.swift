import AppKit
import Combine
import ServiceManagement
import SwiftUI
import PowerSnekKit

/// Single source of truth for launch-at-login, shared by onboarding, Settings,
/// and the menu. Re-reads `SMAppService` whenever the app becomes active,
/// because the user can approve or remove the item in System Settings.
@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var state: LaunchAtLoginState = .disabled
    @Published private(set) var lastError: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        refresh()
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    /// True when this copy runs from a disk image or App Translocation, where
    /// registering a login item would point at a path that goes away.
    var isRunningFromTransientLocation: Bool {
        LaunchAtLoginPolicy.isTransientLocation(Bundle.main.bundlePath)
    }

    func refresh() {
        state = LaunchAtLoginState(SMAppService.mainApp.status)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            Log.loginItem.error("login item \(enabled ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    /// First-run default: see `LaunchAtLoginPolicy.shouldEnableByDefault`.
    func applyFirstRunDefault(hasCompletedOnboarding: Bool) {
        refresh()
        guard LaunchAtLoginPolicy.shouldEnableByDefault(hasCompletedOnboarding: hasCompletedOnboarding,
                                                        state: state,
                                                        bundlePath: Bundle.main.bundlePath) else { return }
        setEnabled(true)
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

extension LaunchAtLoginState {
    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled: self = .enabled
        case .requiresApproval: self = .requiresApproval
        case .notRegistered: self = .disabled
        case .notFound: self = .unavailable
        @unknown default: self = .disabled
        }
    }
}

/// The launch-at-login toggle plus whatever the user needs to know about it:
/// pending approval, a registration error, or an explanatory caption.
struct LaunchAtLoginToggle: View {
    @ObservedObject var model: LoginItemModel
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch PowerSnek at login", isOn: Binding(
                get: { model.state.isOn },
                set: { model.setEnabled($0) }
            ))
                .disabled(model.state == .unavailable)
            Group {
                if model.state == .requiresApproval {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)
                        Text("Waiting for your approval in System Settings.")
                        Button("Open Login Items…") { model.openLoginItemsSettings() }
                            .buttonStyle(.link)
                    }
                } else if let error = model.lastError {
                    Text("Couldn't change the login item: \(error)")
                        .foregroundStyle(.red)
                } else if model.isRunningFromTransientLocation {
                    Text("Move PowerSnek to your Applications folder so it can start at login.")
                        .foregroundStyle(.orange)
                } else if let caption {
                    Text(caption).foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
