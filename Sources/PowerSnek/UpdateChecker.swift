import AppKit
import PowerSnekKit

/// Checks GitHub for a newer release. Never downloads or installs anything
/// by itself: automatic checks only light up a menu item; "Check for
/// Updates…" reports the result and offers to open the download.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var available: UpdateCheck.Available?
    @Published private(set) var isChecking = false

    private let settings: SettingsStore
    private var scheduler: Task<Void, Never>?
    private static let latestReleaseURL =
        URL(string: "https://api.github.com/repos/funsaized/PowerSnek/releases/latest")!

    init(settings: SettingsStore) {
        self.settings = settings
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// Background checks: shortly after launch, then at most once a day
    /// (re-evaluated every few hours, so a sleeping Mac catches up).
    func startAutomaticChecks() {
        scheduler?.cancel()
        scheduler = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            while !Task.isCancelled {
                await self?.checkIfDue()
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    /// User-initiated: always checks and always reports the outcome.
    func checkNow() {
        guard !isChecking else { return }
        Task {
            do {
                let update = try await check()
                if let update {
                    presentAvailable(update)
                } else {
                    presentUpToDate()
                }
            } catch {
                presentFailure(error)
            }
        }
    }

    private func checkIfDue() async {
        guard settings.checkForUpdatesAutomatically,
              UpdateCheck.isAutomaticCheckDue(lastCheck: settings.lastUpdateCheck, now: Date()) else { return }
        do {
            _ = try await check()
        } catch {
            // Offline or rate-limited: stay quiet and try again later.
            Log.updates.info("automatic update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func check() async throws -> UpdateCheck.Available? {
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PowerSnek/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateCheckError.unexpectedStatus(status) }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        settings.lastUpdateCheck = Date()
        available = UpdateCheck.availableUpdate(current: Self.currentVersion, latest: release)
        Log.updates.info("latest release \(release.tagName, privacy: .public); update available: \(self.available != nil)")
        return available
    }

    // MARK: - Alerts

    private func presentAvailable(_ update: UpdateCheck.Available) {
        let alert = NSAlert()
        alert.messageText = "PowerSnek \(update.version) is available"
        alert.informativeText = """
            You have version \(Self.currentVersion). Download the new version, quit PowerSnek, \
            then drag the new app into Applications.
            """
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(update.downloadURL)
        case .alertSecondButtonReturn: NSWorkspace.shared.open(update.releaseNotesURL)
        default: break
        }
    }

    private func presentUpToDate() {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "PowerSnek \(Self.currentVersion) is the latest version."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

enum UpdateCheckError: LocalizedError {
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "GitHub answered with HTTP \(status). Please try again later."
        }
    }
}
