import AppKit
import os
import PowerSnekKit
import QuartzCore

/// Everything one celebration needs: the style, the user's (possibly
/// customized) color/laps/speed, and optional extras.
struct CelebrationSpec {
    var profile: CelebrationProfile
    var color: NSColor
    var laps: Int
    var lapDuration: Double
    /// Battery readout text shown under the notch after landing, or nil.
    var readout: String?
    /// Honor the system Reduce Motion setting: glow in place, no travel.
    var reduceMotion: Bool
}

/// Drives the Comet 2.0 animation: a CADisplayLink ticks a launch, steady
/// cruise, and magnetic-capture sweep around the display, followed by a
/// seamless flash / rim-glow / breathing-pulse finale. Styles vary widths,
/// glow, trail length, colors, and finale; Reduce Motion replaces travel
/// with a single in-place glow.
@MainActor
final class CometAnimator {

    // MARK: - State

    private let host: CALayer
    private let view: NSView
    private let outline: ScreenOutline
    private let spec: CelebrationSpec
    private let finale: CelebrationProfile.Finale
    /// Geometry/blur scale for this display.
    private let scale: CGFloat
    /// Stroke-width scale: `scale` times the style's stroke multiplier.
    private let strokeUnit: CGFloat
    private let glow: CGFloat
    private let contentsScale: CGFloat
    private let palette: CometPalette
    private let segments: [TrailSegment]
    /// Travel time; 0 under Reduce Motion.
    private let travel: Double
    private let totalDistance: Double
    private let finaleDuration: Double
    private let readoutStart: Double
    private let totalDuration: Double
    private var completion: (@MainActor () -> Void)?

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?
    private var hasEnteredFinale = false
    private var hasHiddenImpactHead = false

    private let signposter = OSSignposter(subsystem: "com.powersnek.app", category: "Animation")
    private var signpostState: OSSignpostIntervalState?

    // Layers, bottom to top (matching the reference stacking order).
    private var trailHalos: [CAShapeLayer] = []
    private let trailHaloGroup = CALayer()
    private var trailCores: [CAShapeLayer] = []
    private let headGlowGroup = CALayer()
    private var headGlow = CAShapeLayer()
    private var headCore = CAShapeLayer()
    private let breathA = CAGradientLayer()
    private let rimHaloGroup = CALayer()
    private var rimHalo: CAShapeLayer?
    private var rimCore: CAShapeLayer?
    private let flash = CAGradientLayer()
    private let glint = CALayer()
    private var tongue: CAShapeLayer?
    // Reduce Motion
    private var outlineHalo: CAShapeLayer?
    private var outlineCore: CAShapeLayer?
    // Battery readout
    private var readout: CALayer?

    /// Prepares one celebration for `host`; nothing is drawn until `start`.
    /// `contentsScale` is the target display's backing scale, passed
    /// explicitly so mixed 1x/2x setups render each display at its own scale.
    init(host: CALayer, view: NSView, outline: ScreenOutline, spec: CelebrationSpec,
         contentsScale: CGFloat) {
        self.host = host
        self.view = view
        self.outline = outline
        self.spec = spec
        self.finale = spec.profile.finale
        self.scale = CometMath.visualScale(forScreenWidth: view.bounds.width)
        self.strokeUnit = scale * spec.profile.strokeScale
        self.glow = spec.profile.glowScale
        self.contentsScale = contentsScale
        self.palette = CometPalette(base: spec.color, tailHueShift: spec.profile.tailHueShift)
        self.segments = palette.trailProfile()
        let frac = Double(outline.landingFraction)
        self.totalDistance = CometMath.totalDistance(laps: spec.laps, landingFraction: frac)
        if spec.reduceMotion {
            self.travel = 0
            self.finaleDuration = ReducedMotionGlow.duration
            self.readoutStart = ReducedMotionGlow.fadeIn
        } else {
            self.travel = CometMath.travelDuration(lapDuration: spec.lapDuration,
                                                   laps: spec.laps, landingFraction: frac)
            self.finaleDuration = spec.profile.finaleDuration
            self.readoutStart = travel + ChargeReadout.delayAfterLanding
        }
        let readoutEnd = spec.readout == nil ? 0 : readoutStart + ChargeReadout.duration
        self.totalDuration = max(travel + finaleDuration, readoutEnd)
    }

    /// Runs the celebration. Calls `completion` exactly once: when it ends,
    /// on `cancel()`, from the watchdog if the display link never ticks, or
    /// immediately when the path is degenerate.
    func start(completion: @escaping @MainActor () -> Void) {
        self.completion = completion
        guard outline.totalLength > 1 else { finish(); return }
        signpostState = signposter.beginInterval("Celebration", id: signposter.makeSignpostID())
        if spec.reduceMotion {
            buildReducedMotionLayers()
        } else {
            buildLayers()
        }
        buildReadoutIfNeeded()
        // The display link retains its target, keeping this animator alive
        // until finish() invalidates it.
        let dl = view.displayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
        // Watchdog: if the link stalls (display sleep/detach), still finish
        // so AppController's per-screen debounce is never stranded.
        let deadline = totalDuration + 2
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(deadline))
            self?.finish()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let start = startTime ?? now
        startTime = start
        let t = now - start

        guard t <= totalDuration else {
            finish()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if spec.reduceMotion {
            renderReducedMotion(t)
        } else if t <= travel {
            renderTravel(t)
        } else {
            enterFinaleIfNeeded()
            let impactTime = t - travel
            if impactTime < CometMath.impactOverlapDuration {
                let fade = 1 - CometMath.easeOutQuad(impactTime / CometMath.impactOverlapDuration)
                renderImpactHead(opacity: fade)
            } else {
                hideImpactHeadIfNeeded()
            }
            renderFinale(min(1, impactTime / finaleDuration), impactTime: impactTime)
        }
        renderReadout(t - readoutStart)
        CATransaction.commit()
    }

    /// Tears the celebration down now (display removed or reconfigured, or a
    /// preview restarting). Safe to call at any time, any number of times.
    func cancel() {
        finish()
    }

    private func finish() {
        guard let done = completion else { return }   // already finished
        completion = nil
        link?.invalidate()
        link = nil
        // The host layer belongs to this celebration's overlay window alone.
        host.sublayers?.forEach { $0.removeFromSuperlayer() }
        if let signpostState {
            signposter.endInterval("Celebration", signpostState)
            self.signpostState = nil
        }
        done()
    }

    // MARK: - Layer construction

    private func makeStroke(_ path: CGPath, _ color: NSColor, width: CGFloat,
                            cap: CAShapeLayerLineCap = .butt) -> CAShapeLayer {
        let s = CAShapeLayer()
        s.frame = host.bounds
        s.contentsScale = contentsScale
        s.allowsEdgeAntialiasing = true
        s.path = path
        s.fillColor = nil
        s.strokeColor = color.cgColor
        s.lineWidth = width
        s.lineCap = cap
        s.lineJoin = .round
        s.opacity = 0
        return s
    }

    private func blur(_ layer: CALayer, radius: CGFloat) {
        layer.masksToBounds = false
        layer.contentsScale = contentsScale
        if let f = CIFilter(name: "CIGaussianBlur") {
            f.setValue(radius, forKey: kCIInputRadiusKey)
            layer.filters = [f]
        }
    }

    private func buildLayers() {
        trailHaloGroup.frame = host.bounds
        trailHaloGroup.compositingFilter = "screenBlendMode"
        blur(trailHaloGroup, radius: CometMath.trailHaloBlur * scale * glow)
        for seg in segments {
            let halo = makeStroke(outline.path, palette.base,
                                  width: seg.width * CometMath.trailHaloWidthRatio * strokeUnit)
            halo.opacity = Float(min(1, seg.alpha * CometMath.trailHaloAlphaRatio * glow))
            trailHaloGroup.addSublayer(halo)
            trailHalos.append(halo)
        }
        host.addSublayer(trailHaloGroup)

        for seg in segments {
            let core = makeStroke(outline.path, seg.color, width: seg.width * strokeUnit)
            core.opacity = Float(seg.alpha)
            host.addSublayer(core)
            trailCores.append(core)
        }

        headGlowGroup.frame = host.bounds
        headGlowGroup.compositingFilter = "screenBlendMode"
        blur(headGlowGroup, radius: CometMath.headGlowBlur * scale * glow)
        headGlow = makeStroke(outline.path, palette.bright,
                              width: CometMath.headGlowWidth * strokeUnit, cap: .round)
        headGlowGroup.addSublayer(headGlow)
        host.addSublayer(headGlowGroup)

        headCore = makeStroke(outline.path, .white,
                              width: CometMath.headCoreWidth * strokeUnit, cap: .round)
        host.addSublayer(headCore)

        breathA.type = .radial
        breathA.startPoint = CGPoint(x: 0.5, y: 0.5)
        breathA.endPoint = CGPoint(x: 1, y: 1)
        breathA.colors = [
            palette.bright.withAlphaComponent(0.08).cgColor,
            palette.bright.withAlphaComponent(0.3).cgColor,
            palette.base.withAlphaComponent(0.14).cgColor,
            palette.base.withAlphaComponent(0).cgColor,
        ]
        breathA.locations = [0, 0.24, 0.62, 1]
        breathA.contentsScale = contentsScale
        breathA.compositingFilter = "screenBlendMode"
        breathA.opacity = 0
        host.addSublayer(breathA)

        if let rim = outline.rimPath {
            rimHaloGroup.frame = host.bounds
            rimHaloGroup.compositingFilter = "screenBlendMode"
            blur(rimHaloGroup, radius: CometMath.rimHaloBlur * scale * glow)
            let halo = makeStroke(rim, palette.bright,
                                  width: CometMath.rimHaloWidth * strokeUnit, cap: .round)
            rimHaloGroup.addSublayer(halo)
            host.addSublayer(rimHaloGroup)
            rimHalo = halo
            let rcore = makeStroke(rim, palette.rimCore,
                                   width: CometMath.rimCoreWidth * strokeUnit, cap: .round)
            host.addSublayer(rcore)
            rimCore = rcore
        }

        flash.type = .radial
        flash.startPoint = CGPoint(x: 0.5, y: 0.5)
        flash.endPoint = CGPoint(x: 1, y: 1)
        flash.colors = [
            NSColor.white.cgColor,
            NSColor.white.withAlphaComponent(0.5).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ]
        flash.locations = [0, 0.28, 1]
        flash.contentsScale = contentsScale
        flash.compositingFilter = "screenBlendMode"
        flash.opacity = 0
        host.addSublayer(flash)

        glint.backgroundColor = NSColor.white.cgColor
        glint.contentsScale = contentsScale
        glint.compositingFilter = "screenBlendMode"
        glint.opacity = 0
        host.addSublayer(glint)

        if finale.showsTongue {
            let t = CAShapeLayer()
            t.frame = host.bounds
            t.contentsScale = contentsScale
            t.fillColor = nil
            t.strokeColor = (HexColor.nsColor(fromHex: TongueFlick.colorHex) ?? .systemRed).cgColor
            t.lineWidth = TongueFlick.width * scale
            t.lineCap = .round
            t.lineJoin = .round
            t.opacity = 0
            host.addSublayer(t)
            tongue = t
        }

        // Prime the travel layers before the first display-link tick so no
        // full-path flash can occur between ordering the window front and the
        // first frame.
        renderTravel(0)
    }

    /// Reduce Motion: the whole outline (notch included) glows in and out
    /// in place, with no travel, pulsing, or flash.
    private func buildReducedMotionLayers() {
        let haloGroup = CALayer()
        haloGroup.frame = host.bounds
        haloGroup.compositingFilter = "screenBlendMode"
        blur(haloGroup, radius: CometMath.trailHaloBlur * scale * glow)
        let halo = makeStroke(outline.path, palette.bright, width: 14 * strokeUnit, cap: .round)
        haloGroup.addSublayer(halo)
        host.addSublayer(haloGroup)
        outlineHalo = halo

        let core = makeStroke(outline.path, palette.base, width: 4 * strokeUnit, cap: .round)
        host.addSublayer(core)
        outlineCore = core
    }

    /// A dark pill under the notch: bolt glyph + battery status.
    private func buildReadoutIfNeeded() {
        guard let text = spec.readout else { return }

        let fontSize = 14 * scale
        var font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        if let rounded = font.fontDescriptor.withDesign(.rounded),
           let roundedFont = NSFont(descriptor: rounded, size: fontSize) {
            font = roundedFont
        }
        let string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
        ])
        let textSize = string.size()
        let textWidth = ceil(textSize.width) + 1
        let textHeight = ceil(textSize.height)

        let boltWidth = 9 * scale, boltHeight = 13 * scale
        let gap = 6 * scale, padX = 13 * scale, padY = 6 * scale
        let width = padX * 2 + boltWidth + gap + textWidth
        let height = max(textHeight, boltHeight) + padY * 2
        let notch = outline.notchRect

        let pill = CALayer()
        pill.frame = CGRect(x: notch.midX - width / 2,
                            y: notch.minY - 10 * scale - height,
                            width: width, height: height)
        pill.cornerRadius = height / 2
        pill.backgroundColor = NSColor(white: 0.04, alpha: 0.78).cgColor
        pill.borderColor = palette.bright.withAlphaComponent(0.5).cgColor
        pill.borderWidth = 1
        pill.shadowColor = palette.base.cgColor
        pill.shadowOpacity = 0.55
        pill.shadowRadius = 10 * scale
        pill.shadowOffset = .zero
        pill.contentsScale = contentsScale
        pill.opacity = 0

        let bolt = CAShapeLayer()
        bolt.frame = CGRect(x: padX, y: (height - boltHeight) / 2, width: boltWidth, height: boltHeight)
        bolt.contentsScale = contentsScale
        let unitBolt: [CGPoint] = [
            CGPoint(x: 0.62, y: 1.0), CGPoint(x: 0.08, y: 0.44), CGPoint(x: 0.46, y: 0.44),
            CGPoint(x: 0.36, y: 0.0), CGPoint(x: 0.92, y: 0.58), CGPoint(x: 0.54, y: 0.58),
        ]
        let boltPath = CGMutablePath()
        boltPath.addLines(between: unitBolt.map { CGPoint(x: $0.x * boltWidth, y: $0.y * boltHeight) })
        boltPath.closeSubpath()
        bolt.path = boltPath
        bolt.fillColor = palette.bright.cgColor
        pill.addSublayer(bolt)

        let label = CATextLayer()
        label.string = string
        label.contentsScale = contentsScale
        label.alignmentMode = .left
        label.frame = CGRect(x: padX + boltWidth + gap, y: (height - textHeight) / 2,
                             width: textWidth, height: textHeight)
        pill.addSublayer(label)

        host.addSublayer(pill)
        readout = pill
    }

    // MARK: - Per-frame rendering

    private func wrap(_ x: Double) -> Double {
        (x.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
    }

    /// Shows a dash segment covering [start, start+length] (perimeter
    /// fractions; wraps across the path start automatically).
    private func setDash(_ layer: CAShapeLayer, start: Double, length: Double) {
        let total = Double(outline.totalLength)
        let len = max(length, 1e-5) * total
        layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
        layer.lineDashPhase = -CGFloat(wrap(start) * total)
    }

    private func setCircle(_ layer: CALayer, center: CGPoint, radius: CGFloat) {
        layer.frame = CGRect(x: center.x - radius, y: center.y - radius,
                             width: radius * 2, height: radius * 2)
        layer.cornerRadius = radius
    }

    private func renderTravel(_ t: Double) {
        let e = totalDistance * CometMath.travelProgress(elapsed: t, duration: travel)
        let head = wrap(e)
        let trail = CometMath.trailLength(progress: e, total: totalDistance,
                                          maxFraction: spec.profile.trailFraction)
        let throb = CGFloat(CometMath.throb(at: t))
        let n = segments.count

        for i in 0..<n {
            let far = Double(i + 1) / Double(n) * trail
            let near = Double(i) / Double(n) * trail
            let core = trailCores[i]
            setDash(core, start: head - far, length: far - near)

            let halo = trailHalos[i]
            setDash(halo, start: head - far, length: far - near)
        }
        setHead(at: head, throb: throb, opacity: 1)
    }

    private func setHead(at position: Double, throb: CGFloat, opacity: Double) {
        headGlow.lineWidth = CometMath.headGlowWidth * strokeUnit * throb
        headGlow.opacity = Float(0.85 * opacity)
        setDash(headGlow, start: position - CometMath.headDashFraction,
                length: CometMath.headDashFraction)
        headCore.lineWidth = CometMath.headCoreWidth * strokeUnit * throb
        headCore.opacity = Float(opacity)
        setDash(headCore, start: position - CometMath.headDashFraction,
                length: CometMath.headDashFraction)
    }

    private func renderImpactHead(opacity: Double) {
        setHead(at: wrap(totalDistance), throb: 1, opacity: opacity)
    }

    private func enterFinaleIfNeeded() {
        guard !hasEnteredFinale else { return }
        hasEnteredFinale = true
        signposter.emitEvent("Finale")
        (trailCores + trailHalos).forEach { $0.opacity = 0 }
    }

    private func hideImpactHeadIfNeeded() {
        guard !hasHiddenImpactHead else { return }
        hasHiddenImpactHead = true
        headCore.opacity = 0
        headGlow.opacity = 0
    }

    private func renderFinale(_ u: Double, impactTime: Double) {
        let f = FinaleState.at(u)

        setCircle(flash, center: outline.landingPoint, radius: f.flashRadius * scale)
        flash.opacity = Float(f.flashOpacity * finale.flashGain)

        if let rimHalo, let rimCore {
            let total = Double(outline.rimLength)
            let len = max(Double(f.rimFraction) * 2, 0.001) * total
            for layer in [rimHalo, rimCore] {
                layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
                layer.lineDashPhase = -CGFloat((0.5 - Double(f.rimFraction)) * total)
            }
            rimHalo.opacity = Float(min(1, 0.85 * f.fade * glow))
            rimCore.opacity = Float(f.fade)
        }

        let nr = outline.notchRect
        let o = f.breath
        let width = (nr.width + 60 * scale) * (1 + 0.2 * o)
        let height = (nr.height + 46 * scale) * (1 + 0.45 * o)
        // The reference centers the breath between the screen's top edge and
        // the notch floor, nudged 6 units toward the notch (mirrored: y-up).
        let centerY = (host.bounds.height + nr.minY) / 2 - 6 * scale
        breathA.frame = CGRect(x: nr.midX - width / 2, y: centerY - height / 2,
                               width: width, height: height)
        // The radial color stops form a hollow-hot halo instead of the flat
        // center produced by a solid layer plus Gaussian blur.
        breathA.opacity = Float(min(1, 0.9 * o * f.fade * finale.breathGain))

        setCircle(glint, center: outline.landingPoint, radius: f.glintRadius * scale)
        glint.opacity = Float(f.glintOpacity * finale.glintGain)

        if let tongue {
            let reach = TongueFlick.reach(at: impactTime)
            if reach > 0 {
                let s = TongueFlick.shape(origin: outline.landingPoint, reach: reach, scale: scale)
                let path = CGMutablePath()
                path.move(to: s.origin)
                path.addLine(to: s.stemEnd)
                path.move(to: s.stemEnd)
                path.addLine(to: s.leftTip)
                path.move(to: s.stemEnd)
                path.addLine(to: s.rightTip)
                tongue.path = path
                tongue.opacity = 1
            } else {
                tongue.opacity = 0
            }
        }
    }

    private func renderReducedMotion(_ t: Double) {
        let o = ReducedMotionGlow.opacity(at: t)
        outlineHalo?.opacity = Float(min(1, 0.8 * o * Double(glow)))
        outlineCore?.opacity = Float(o)
    }

    private func renderReadout(_ t: Double) {
        guard let readout else { return }
        readout.opacity = Float(ChargeReadout.opacity(at: t))
    }
}
