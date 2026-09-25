import XCTest
@testable import PowerSnekKit

final class CelebrationProfileTests: XCTestCase {
    func test_electric_reproducesOriginalTuning() {
        let p = CelebrationProfile.electric
        XCTAssertEqual(p.colorHex, SettingsStore.defaultColorHex)
        XCTAssertEqual(p.laps, 2)
        XCTAssertEqual(p.lapDuration, 3.1, accuracy: 1e-9)
        XCTAssertEqual(p.strokeScale, 1)
        XCTAssertEqual(p.glowScale, 1)
        XCTAssertEqual(p.trailFraction, CometMath.trailMaxFraction)
        XCTAssertEqual(p.tailHueShift, 0)
        XCTAssertEqual(p.finale, .burst)
        XCTAssertEqual(p.finaleDuration, CometMath.finaleDuration)
    }

    func test_allProfiles_haveUniqueIDsAndSaneValues() {
        let ids = CelebrationProfile.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for p in CelebrationProfile.all {
            XCTAssertNotNil(HexColor.nsColor(fromHex: p.colorHex), p.id)
            XCTAssertFalse(VisibleColor.isTooDark(HexColor.nsColor(fromHex: p.colorHex)!), p.id)
            XCTAssertTrue((1...5).contains(p.laps), p.id)
            // Within the Settings speed slider's range.
            XCTAssertTrue((2.0...6.0).contains(p.lapDuration), p.id)
            XCTAssertGreaterThan(p.strokeScale, 0, p.id)
            XCTAssertGreaterThan(p.glowScale, 0, p.id)
            XCTAssertTrue((0.05...0.4).contains(p.trailFraction), p.id)
            XCTAssertGreaterThan(p.finaleDuration, 0, p.id)
            let total = p.totalDuration(laps: p.laps, lapDuration: p.lapDuration)
            XCTAssertTrue((1.0...6.0).contains(total), "\(p.id) runs \(total)s")
        }
    }

    func test_snekFinale_outlastsTongueFlick() {
        XCTAssertGreaterThanOrEqual(CelebrationProfile.snek.finaleDuration, TongueFlick.duration)
        XCTAssertTrue(CelebrationProfile.snek.finale.showsTongue)
        XCTAssertFalse(CelebrationProfile.electric.finale.showsTongue)
    }

    func test_minimalFinale_hasNoFlashBreathOrGlint() {
        let f = CelebrationProfile.Finale.minimal
        XCTAssertEqual(f.flashGain, 0)
        XCTAssertEqual(f.breathGain, 0)
        XCTAssertEqual(f.glintGain, 0)
    }

    func test_named_fallsBackToDefault() {
        XCTAssertEqual(CelebrationProfile.named("aurora"), .aurora)
        XCTAssertEqual(CelebrationProfile.named("does-not-exist"), .electric)
    }

    func test_matches_isCaseInsensitiveAndTolerant() {
        let p = CelebrationProfile.electric
        XCTAssertTrue(p.matches(colorHex: "#34ff6a", laps: 2, lapDuration: 3.1001))
        XCTAssertFalse(p.matches(colorHex: "#34FF6A", laps: 3, lapDuration: 3.1))
        XCTAssertFalse(p.matches(colorHex: "#FF0000", laps: 2, lapDuration: 3.1))
    }

    func test_totalDuration_isTravelPlusFinale() {
        let p = CelebrationProfile.electric
        let travel = CometMath.travelDuration(lapDuration: 3.1, laps: 2, landingFraction: 0.35)
        XCTAssertEqual(p.totalDuration(laps: 2, lapDuration: 3.1, landingFraction: 0.35),
                       travel + CometMath.finaleDuration, accuracy: 1e-9)
    }
}

final class StyleSettingsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func test_defaults_areElectricWithReadout() {
        let s = SettingsStore(defaults: makeDefaults())
        XCTAssertEqual(s.styleID, CelebrationProfile.electric.id)
        XCTAssertTrue(s.showBatteryReadout)
        XCTAssertFalse(s.isCustomized)
    }

    func test_apply_setsPresetsAndPersists() {
        let d = makeDefaults()
        let s = SettingsStore(defaults: d)
        s.apply(.aurora)
        XCTAssertEqual(s.styleID, "aurora")
        XCTAssertEqual(s.cometColorHex, CelebrationProfile.aurora.colorHex)
        XCTAssertEqual(s.lapCount, 1)
        XCTAssertFalse(s.isCustomized)

        let reloaded = SettingsStore(defaults: d)
        XCTAssertEqual(reloaded.activeProfile, .aurora)
        XCTAssertFalse(reloaded.isCustomized)
    }

    func test_overridingAPreset_marksCustomized() {
        let s = SettingsStore(defaults: makeDefaults())
        s.apply(.hyperbolt)
        s.lapCount = 3
        XCTAssertTrue(s.isCustomized)
        XCTAssertEqual(s.styleID, "hyperbolt")
    }

    func test_existingUser_keepsCustomValuesUnderDefaultStyle() {
        let d = makeDefaults()
        d.set("#FF00AA", forKey: "cometColorHex")
        d.set(4, forKey: "lapCount")
        let s = SettingsStore(defaults: d)
        XCTAssertEqual(s.styleID, CelebrationProfile.defaultID)
        XCTAssertEqual(s.cometColorHex, "#FF00AA")
        XCTAssertEqual(s.lapCount, 4)
        XCTAssertTrue(s.isCustomized)
    }

    func test_unknownStoredStyle_fallsBackToDefault() {
        let d = makeDefaults()
        d.set("retired-style", forKey: "styleID")
        XCTAssertEqual(SettingsStore(defaults: d).styleID, CelebrationProfile.defaultID)
    }
}

final class ChargeReadoutTests: XCTestCase {
    private func snap(_ percent: Int, charging: Bool = true, charged: Bool = false,
                      minutes: Int? = nil) -> ChargeSnapshot {
        ChargeSnapshot(percent: percent, isCharging: charging, isFullyCharged: charged, minutesToFull: minutes)
    }

    func test_text_variants() {
        XCTAssertEqual(ChargeReadout.text(for: snap(47)), "47% · Charging")
        XCTAssertEqual(ChargeReadout.text(for: snap(47, minutes: 72)), "47% · full in 1h 12m")
        XCTAssertEqual(ChargeReadout.text(for: snap(80, charging: false)), "80% · On power")
        XCTAssertEqual(ChargeReadout.text(for: snap(100, charging: false)), "Fully charged")
        XCTAssertEqual(ChargeReadout.text(for: snap(99, charged: true)), "Fully charged")
    }

    func test_formatMinutes() {
        XCTAssertEqual(ChargeReadout.format(minutes: 45), "45m")
        XCTAssertEqual(ChargeReadout.format(minutes: 60), "1h")
        XCTAssertEqual(ChargeReadout.format(minutes: 125), "2h 5m")
    }

    func test_snapshotFromIOKitValues() {
        let s = ChargeSnapshot(currentCapacity: 4700, maxCapacity: 10000, isCharging: true,
                               isCharged: nil, timeToFullMinutes: -1)
        XCTAssertEqual(s, snap(47))   // -1 means "still estimating"
        XCTAssertNil(ChargeSnapshot(currentCapacity: 50, maxCapacity: 0, isCharging: true,
                                    isCharged: false, timeToFullMinutes: nil))
        XCTAssertNil(ChargeSnapshot(currentCapacity: nil, maxCapacity: 100, isCharging: true,
                                    isCharged: false, timeToFullMinutes: nil))
        XCTAssertEqual(ChargeSnapshot(currentCapacity: 101, maxCapacity: 100, isCharging: nil,
                                      isCharged: nil, timeToFullMinutes: nil)?.percent, 100)
    }

    func test_opacityEnvelope() {
        XCTAssertEqual(ChargeReadout.opacity(at: -0.1), 0)
        XCTAssertEqual(ChargeReadout.opacity(at: ChargeReadout.fadeIn + 0.5), 1)
        XCTAssertEqual(ChargeReadout.opacity(at: ChargeReadout.duration + 0.01), 0)
        let mid = ChargeReadout.opacity(at: ChargeReadout.fadeIn / 2)
        XCTAssertGreaterThan(mid, 0)
        XCTAssertLessThan(mid, 1)
    }
}

final class EnvelopeAndTongueTests: XCTestCase {
    func test_trapezoid_isContinuousAndBounded() {
        var previous = Envelope.trapezoid(0, fadeIn: 0.3, hold: 0.5, fadeOut: 0.7)
        var t = 0.0
        while t < 1.6 {
            t += 0.001
            let v = Envelope.trapezoid(t, fadeIn: 0.3, hold: 0.5, fadeOut: 0.7)
            XCTAssertTrue((0...1).contains(v))
            XCTAssertLessThan(abs(v - previous), 0.01, "jump at t=\(t)")
            previous = v
        }
        XCTAssertEqual(Envelope.trapezoid(1.6, fadeIn: 0.3, hold: 0.5, fadeOut: 0.7), 0)
    }

    func test_reducedMotionGlow_hasNoTravelAndEnds() {
        XCTAssertEqual(ReducedMotionGlow.opacity(at: 0), 0)
        XCTAssertEqual(ReducedMotionGlow.opacity(at: ReducedMotionGlow.fadeIn + 0.1), 1)
        XCTAssertEqual(ReducedMotionGlow.opacity(at: ReducedMotionGlow.duration), 0, accuracy: 1e-9)
    }

    func test_tongue_flicksTwiceAndRetracts() {
        XCTAssertEqual(TongueFlick.reach(at: 0), 0)
        XCTAssertEqual(TongueFlick.reach(at: 0.1 + 0.14), 1, accuracy: 1e-9)
        XCTAssertEqual(TongueFlick.reach(at: 0.40), 0)          // between flicks
        XCTAssertGreaterThan(TongueFlick.reach(at: 0.60), 0.9)  // second flick
        XCTAssertEqual(TongueFlick.reach(at: TongueFlick.duration + 0.01), 0)
    }

    func test_tongueShape_hangsDownAndForksSymmetrically() {
        let origin = CGPoint(x: 100, y: 500)
        let s = TongueFlick.shape(origin: origin, reach: 1, scale: 1)
        XCTAssertEqual(s.stemEnd.x, origin.x)
        XCTAssertEqual(s.stemEnd.y, origin.y - TongueFlick.length, accuracy: 1e-9)
        XCTAssertLessThan(s.leftTip.y, s.stemEnd.y)
        XCTAssertEqual(s.leftTip.y, s.rightTip.y, accuracy: 1e-9)
        XCTAssertEqual(origin.x - s.leftTip.x, s.rightTip.x - origin.x, accuracy: 1e-9)

        let half = TongueFlick.shape(origin: origin, reach: 0.5, scale: 1)
        XCTAssertEqual(half.leftTip, half.stemEnd)   // fork opens only past halfway
    }

    func test_paletteHueShift_changesOnlyTheTail() {
        let base = HexColor.nsColor(fromHex: "#3CE6D2")!
        let plain = CometPalette(base: base)
        let shifted = CometPalette(base: base, tailHueShift: 0.14)
        XCTAssertEqual(HexColor.hex(from: plain.bright), HexColor.hex(from: shifted.bright))
        XCTAssertNotEqual(HexColor.hex(from: plain.tail), HexColor.hex(from: shifted.tail))
        XCTAssertEqual(shifted.tail.usingColorSpace(.sRGB)!.hueComponent,
                       (plain.tail.usingColorSpace(.sRGB)!.hueComponent + 0.14).truncatingRemainder(dividingBy: 1),
                       accuracy: 0.02)
    }

    func test_trailLength_respectsProfileMaximum() {
        XCTAssertEqual(CometMath.trailLength(progress: 1, total: 3, maxFraction: 0.26), 0.26, accuracy: 1e-9)
        XCTAssertEqual(CometMath.trailLength(progress: 1, total: 3), CometMath.trailMaxFraction, accuracy: 1e-9)
    }
}
