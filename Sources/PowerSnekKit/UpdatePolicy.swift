import Foundation

/// A semantic version ("0.2.1", "v1.0.0-beta.2"). Build metadata is ignored.
public struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init?(_ string: String) {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let plus = s.firstIndex(of: "+") { s = String(s[..<plus]) }
        let parts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = parts.first else { return nil }
        let numbers = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(numbers.count) else { return nil }
        var values: [Int] = []
        for n in numbers {
            guard !n.isEmpty, n.allSatisfy(\.isNumber), let v = Int(n) else { return nil }
            values.append(v)
        }
        while values.count < 3 { values.append(0) }
        major = values[0]; minor = values[1]; patch = values[2]
        prerelease = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
        if parts.count > 1 && prerelease.isEmpty { return nil }
    }

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        return prerelease.isEmpty ? core : core + "-" + prerelease.joined(separator: ".")
    }

    public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        if (a.major, a.minor, a.patch) != (b.major, b.minor, b.patch) {
            return (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
        }
        // A release outranks any of its prereleases.
        switch (a.prerelease.isEmpty, b.prerelease.isEmpty) {
        case (true, true): return false
        case (true, false): return false
        case (false, true): return true
        case (false, false): break
        }
        for (x, y) in zip(a.prerelease, b.prerelease) where x != y {
            switch (Int(x), Int(y)) {
            case let (nx?, ny?): return nx < ny
            case (.some, nil): return true    // numeric identifiers sort first
            case (nil, .some): return false
            case (nil, nil): return x < y
            }
        }
        return a.prerelease.count < b.prerelease.count
    }

    public static func == (a: SemanticVersion, b: SemanticVersion) -> Bool {
        !(a < b) && !(b < a)
    }
}

/// The fields PowerSnek reads from GitHub's "latest release" API.
public struct GitHubRelease: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let htmlURL: URL
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft, prerelease, assets
    }

    /// The DMG to download, preferring the versioned file over the alias.
    public var dmgURL: URL? {
        let dmgs = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }
        return (dmgs.first { $0.name != "PowerSnek.dmg" } ?? dmgs.first)?.browserDownloadURL
    }
}

public enum UpdateCheck {
    public struct Available: Equatable, Sendable {
        public let version: SemanticVersion
        /// The DMG when the release has one, otherwise the release page.
        public let downloadURL: URL
        public let releaseNotesURL: URL
    }

    /// Minimum time between automatic (background) checks.
    public static let automaticInterval: TimeInterval = 24 * 60 * 60

    /// nil when the running version is current (or the release is unusable).
    public static func availableUpdate(current: String, latest: GitHubRelease) -> Available? {
        guard !latest.draft, !latest.prerelease,
              let latestVersion = SemanticVersion(latest.tagName),
              let currentVersion = SemanticVersion(current),
              currentVersion < latestVersion else { return nil }
        return Available(version: latestVersion,
                         downloadURL: latest.dmgURL ?? latest.htmlURL,
                         releaseNotesURL: latest.htmlURL)
    }

    public static func isAutomaticCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= automaticInterval || now < lastCheck
    }
}
