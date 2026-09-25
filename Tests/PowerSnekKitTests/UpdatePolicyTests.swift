import XCTest
@testable import PowerSnekKit

final class SemanticVersionTests: XCTestCase {
    private func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    func test_parsesTagsAndShortForms() {
        XCTAssertEqual(v("v0.2.1").description, "0.2.1")
        XCTAssertEqual(v("1.2").description, "1.2.0")
        XCTAssertEqual(v("3").description, "3.0.0")
        XCTAssertEqual(v("1.0.0-beta.2+build.7").description, "1.0.0-beta.2")
    }

    func test_rejectsGarbage() {
        for s in ["", "v", "1..2", "1.2.3.4", "a.b.c", "1.2.x", "1.0.0-"] {
            XCTAssertNil(SemanticVersion(s), s)
        }
    }

    func test_ordersNumericallyNotLexically() {
        XCTAssertLessThan(v("0.2.1"), v("0.10.0"))
        XCTAssertLessThan(v("0.9.9"), v("1.0.0"))
        XCTAssertEqual(v("v1.2.0"), v("1.2"))
    }

    func test_prereleaseOrdering() {
        // From the SemVer spec's precedence example.
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
                       "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"].map(v)
        for i in 1..<ordered.count {
            XCTAssertLessThan(ordered[i - 1], ordered[i], "\(ordered[i - 1]) < \(ordered[i])")
        }
    }
}

final class UpdateCheckTests: XCTestCase {
    private func release(tag: String, draft: Bool = false, prerelease: Bool = false,
                         assets: [String] = ["PowerSnek-0.3.0.dmg", "PowerSnek-0.3.0.dmg.sha256"]) -> GitHubRelease {
        let base = "https://github.com/funsaized/PowerSnek/releases/download/\(tag)/"
        let assetJSON = assets.map { name in
            "{\"name\": \"\(name)\", \"browser_download_url\": \"\(base)\(name)\"}"
        }.joined(separator: ",")
        let json = """
            {"tag_name": "\(tag)", "html_url": "https://github.com/funsaized/PowerSnek/releases/tag/\(tag)",
             "draft": \(draft), "prerelease": \(prerelease), "assets": [\(assetJSON)], "body": "ignored"}
            """
        return try! JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
    }

    func test_newerRelease_isOfferedWithItsDMG() {
        let update = UpdateCheck.availableUpdate(current: "0.2.1", latest: release(tag: "v0.3.0"))
        XCTAssertEqual(update?.version.description, "0.3.0")
        XCTAssertEqual(update?.downloadURL.lastPathComponent, "PowerSnek-0.3.0.dmg")
        XCTAssertEqual(update?.releaseNotesURL.lastPathComponent, "v0.3.0")
    }

    func test_prefersVersionedDMGOverStableAlias() {
        let r = release(tag: "v0.3.0", assets: ["PowerSnek.dmg", "PowerSnek-0.3.0.dmg"])
        XCTAssertEqual(r.dmgURL?.lastPathComponent, "PowerSnek-0.3.0.dmg")
    }

    func test_releaseWithoutDMG_fallsBackToReleasePage() {
        let update = UpdateCheck.availableUpdate(current: "0.2.1", latest: release(tag: "v0.3.0", assets: []))
        XCTAssertEqual(update?.downloadURL.lastPathComponent, "v0.3.0")
    }

    func test_sameOrOlderRelease_isNotOffered() {
        XCTAssertNil(UpdateCheck.availableUpdate(current: "0.3.0", latest: release(tag: "v0.3.0")))
        XCTAssertNil(UpdateCheck.availableUpdate(current: "0.4.0", latest: release(tag: "v0.3.0")))
    }

    func test_draftsPrereleasesAndUnparseableTags_areIgnored() {
        XCTAssertNil(UpdateCheck.availableUpdate(current: "0.2.1", latest: release(tag: "v0.3.0", draft: true)))
        XCTAssertNil(UpdateCheck.availableUpdate(current: "0.2.1", latest: release(tag: "v0.3.0", prerelease: true)))
        XCTAssertNil(UpdateCheck.availableUpdate(current: "0.2.1", latest: release(tag: "nightly")))
    }

    func test_automaticCheckIsDueOncePerDay() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        XCTAssertTrue(UpdateCheck.isAutomaticCheckDue(lastCheck: nil, now: now))
        XCTAssertFalse(UpdateCheck.isAutomaticCheckDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(UpdateCheck.isAutomaticCheckDue(
            lastCheck: now.addingTimeInterval(-UpdateCheck.automaticInterval), now: now))
        // A clock set backwards shouldn't suppress checks forever.
        XCTAssertTrue(UpdateCheck.isAutomaticCheckDue(lastCheck: now.addingTimeInterval(86_400 * 30), now: now))
    }

    func test_settingsDefaultToAutomaticChecks() {
        let suite = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        let s = SettingsStore(defaults: d)
        XCTAssertTrue(s.checkForUpdatesAutomatically)
        XCTAssertNil(s.lastUpdateCheck)
        let now = Date(timeIntervalSinceReferenceDate: 12_345)
        s.lastUpdateCheck = now
        XCTAssertEqual(SettingsStore(defaults: d).lastUpdateCheck, now)
    }
}
