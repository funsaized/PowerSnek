import os

/// Local-only structured logging (Console.app, subsystem `com.powersnek.app`).
/// Nothing here leaves the machine; it exists so "it didn't fire" reports can
/// be diagnosed with `log show --predicate 'subsystem == "com.powersnek.app"'`.
enum Log {
    private static let subsystem = "com.powersnek.app"
    static var power: Logger { Logger(subsystem: subsystem, category: "power") }
    static var display: Logger { Logger(subsystem: subsystem, category: "display") }
    static var animation: Logger { Logger(subsystem: subsystem, category: "animation") }
    static var loginItem: Logger { Logger(subsystem: subsystem, category: "login-item") }
    static var updates: Logger { Logger(subsystem: subsystem, category: "updates") }
}
