import Foundation

/// The login-item state PowerSnek shows to the user, mapped from
/// `SMAppService.Status` in the app target.
public enum LaunchAtLoginState: Equatable, Sendable {
    case enabled
    /// Registered, but macOS is waiting for the user to allow it in
    /// System Settings > General > Login Items.
    case requiresApproval
    case disabled
    /// The service could not be found (e.g. a malformed bundle).
    case unavailable

    /// What the toggle shows: approval-pending counts as "on" because the
    /// user already asked for it; the UI explains the remaining step.
    public var isOn: Bool { self == .enabled || self == .requiresApproval }
}

public enum LaunchAtLoginPolicy {
    /// PowerSnek is useless unless it is running when the charger connects,
    /// so first-run onboarding turns launch-at-login on (visibly, with the
    /// toggle in the welcome window). Never re-enables after onboarding, and
    /// never registers a copy running from a disk image or App Translocation,
    /// which would leave a login item pointing at a path that disappears.
    public static func shouldEnableByDefault(hasCompletedOnboarding: Bool,
                                             state: LaunchAtLoginState,
                                             bundlePath: String) -> Bool {
        !hasCompletedOnboarding
            && state == .disabled
            && !isTransientLocation(bundlePath)
    }

    /// True when the app runs from a mounted volume or a translocated
    /// (quarantined, not yet moved) location.
    public static func isTransientLocation(_ bundlePath: String) -> Bool {
        bundlePath.hasPrefix("/Volumes/") || bundlePath.contains("/AppTranslocation/")
    }
}
