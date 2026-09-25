import Foundation
import Combine

public final class SettingsStore: ObservableObject {
    public static let defaultColorHex = "#34FF6A"

    private enum Key {
        static let enabled = "effectEnabled"
        static let color = "cometColorHex"
        static let laps = "lapCount"
        static let duration = "lapDuration"
        static let onboarded = "hasCompletedOnboarding"
        static let pauseOverFullScreen = "pauseOverFullScreen"
        static let hideFromCapture = "hideFromScreenCapture"
        static let style = "styleID"
        static let batteryReadout = "showBatteryReadout"
        static let autoUpdateCheck = "checkForUpdatesAutomatically"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    private let defaults: UserDefaults

    @Published public var effectEnabled: Bool { didSet { defaults.set(effectEnabled, forKey: Key.enabled) } }
    /// Always stored brightened to `VisibleColor`'s floor, so a dark pick
    /// can't produce an invisible comet.
    @Published public var cometColorHex: String {
        didSet {
            // Assigning inside didSet does not re-trigger observers.
            let visible = VisibleColor.clampedHex(cometColorHex)
            if visible != cometColorHex { cometColorHex = visible }
            defaults.set(cometColorHex, forKey: Key.color)
        }
    }
    @Published public var lapCount: Int { didSet { defaults.set(lapCount, forKey: Key.laps) } }
    @Published public var lapDuration: Double { didSet { defaults.set(lapDuration, forKey: Key.duration) } }
    /// Whether the first-run welcome window has been shown and dismissed.
    @Published public var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarded) } }
    /// Skip displays showing a full-screen app, video, or presentation.
    @Published public var pauseOverFullScreen: Bool { didSet { defaults.set(pauseOverFullScreen, forKey: Key.pauseOverFullScreen) } }
    /// Exclude the overlay from screenshots, recordings, and screen sharing.
    @Published public var hideFromScreenCapture: Bool { didSet { defaults.set(hideFromScreenCapture, forKey: Key.hideFromCapture) } }

    /// The selected `CelebrationProfile`. Color, laps, and speed start from
    /// its presets but can be customized independently.
    @Published public var styleID: String { didSet { defaults.set(styleID, forKey: Key.style) } }
    /// Show the battery level under the notch after the comet lands.
    @Published public var showBatteryReadout: Bool { didSet { defaults.set(showBatteryReadout, forKey: Key.batteryReadout) } }

    /// Look for a newer release on GitHub at most once a day.
    @Published public var checkForUpdatesAutomatically: Bool {
        didSet { defaults.set(checkForUpdatesAutomatically, forKey: Key.autoUpdateCheck) }
    }
    /// When the last update check (automatic or manual) succeeded.
    public var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }

    public var activeProfile: CelebrationProfile { CelebrationProfile.named(styleID) }

    /// Color, laps, or speed differ from the selected style's presets.
    public var isCustomized: Bool {
        !activeProfile.matches(colorHex: cometColorHex, laps: lapCount, lapDuration: lapDuration)
    }

    /// Selects a style and resets color, laps, and speed to its presets.
    public func apply(_ profile: CelebrationProfile) {
        styleID = profile.id
        cometColorHex = profile.colorHex
        lapCount = profile.laps
        lapDuration = profile.lapDuration
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.color: SettingsStore.defaultColorHex,
            Key.laps: 2,
            Key.duration: 3.1,
            Key.onboarded: false,
            Key.pauseOverFullScreen: true,
            Key.hideFromCapture: true,
            // Existing installs have no style yet: they keep their stored
            // color/laps/speed under the original style.
            Key.style: CelebrationProfile.defaultID,
            Key.batteryReadout: true,
            Key.autoUpdateCheck: true,
        ])
        self.effectEnabled = defaults.bool(forKey: Key.enabled)
        self.cometColorHex = VisibleColor.clampedHex(defaults.string(forKey: Key.color) ?? SettingsStore.defaultColorHex)
        self.lapCount = defaults.integer(forKey: Key.laps)
        self.lapDuration = defaults.double(forKey: Key.duration)
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded)
        self.pauseOverFullScreen = defaults.bool(forKey: Key.pauseOverFullScreen)
        self.hideFromScreenCapture = defaults.bool(forKey: Key.hideFromCapture)
        self.styleID = CelebrationProfile.named(defaults.string(forKey: Key.style) ?? CelebrationProfile.defaultID).id
        self.showBatteryReadout = defaults.bool(forKey: Key.batteryReadout)
        self.checkForUpdatesAutomatically = defaults.bool(forKey: Key.autoUpdateCheck)
    }
}
