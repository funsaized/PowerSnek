import Foundation
import Combine

public final class SettingsStore: ObservableObject {
    public static let defaultColorHex = "#34FF6A"

    private enum Key {
        static let enabled = "effectEnabled"
        static let color = "cometColorHex"
        static let laps = "lapCount"
        static let duration = "lapDuration"
    }

    private let defaults: UserDefaults

    @Published public var effectEnabled: Bool { didSet { defaults.set(effectEnabled, forKey: Key.enabled) } }
    @Published public var cometColorHex: String { didSet { defaults.set(cometColorHex, forKey: Key.color) } }
    @Published public var lapCount: Int { didSet { defaults.set(lapCount, forKey: Key.laps) } }
    @Published public var lapDuration: Double { didSet { defaults.set(lapDuration, forKey: Key.duration) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.color: SettingsStore.defaultColorHex,
            Key.laps: 2,
            Key.duration: 1.2,
        ])
        self.effectEnabled = defaults.bool(forKey: Key.enabled)
        self.cometColorHex = defaults.string(forKey: Key.color) ?? SettingsStore.defaultColorHex
        self.lapCount = defaults.integer(forKey: Key.laps)
        self.lapDuration = defaults.double(forKey: Key.duration)
    }
}
