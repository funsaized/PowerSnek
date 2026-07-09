import AppKit
import PowerSnekKit
import QuartzCore

/// Drives the Comet 2.0 animation: a CADisplayLink ticks a launch, steady
/// cruise, and magnetic-capture sweep around the display, followed by a
/// seamless flash / rim-glow / breathing-pulse finale.
@MainActor
public final class CometAnimator {

    /// Runs one comet on `host`. Calls `completion` exactly once, even if
    /// the display link never ticks (watchdog) or the path is degenerate.
    public static func run(on host: CALayer,
                           displayLinkView view: NSView,
                           outline: ScreenOutline,
                           color: NSColor,
                           laps: Int,
                           lapDuration: Double,
                           completion: @escaping @MainActor () -> Void) {
        guard outline.totalLength > 1 else { completion(); return }
        CometAnimator(host: host, view: view, outline: outline, color: color,
                      laps: laps, lapDuration: lapDuration, completion: completion).start()
    }

    // MARK: - State

    private let host: CALayer
    private let view: NSView
    private let outline: ScreenOutline
    private let scale: CGFloat
    private let contentsScale: CGFloat
    private let palette: CometPalette
    private let segments: [TrailSegment]
    private let travel: Double
    private let totalDistance: Double
    private var completion: (@MainActor () -> Void)?

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?
    private var hasEnteredFinale = false
    private var hasHiddenImpactHead = false

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

    private init(host: CALayer, view: NSView, outline: ScreenOutline, color: NSColor,
                 laps: Int, lapDuration: Double,
                 completion: @escaping @MainActor () -> Void) {
        self.host = host
        self.view = view
        self.outline = outline
        self.scale = CometMath.visualScale(forScreenWidth: view.bounds.width)
        self.contentsScale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        self.palette = CometPalette(base: color)
        self.segments = palette.trailProfile()
        let frac = Double(outline.landingFraction)
        self.totalDistance = CometMath.totalDistance(laps: laps, landingFraction: frac)
        self.travel = CometMath.travelDuration(lapDuration: lapDuration,
                                               laps: laps, landingFraction: frac)
        self.completion = completion
    }

    private func start() {
        buildLayers()
        // The display link retains its target, keeping this animator alive
        // until finish() invalidates it.
        let dl = view.displayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        link = dl
        // Watchdog: if the link stalls (display sleep/detach), still finish
        // so AppController's per-screen debounce is never stranded.
        let deadline = travel + CometMath.finaleDuration + 2
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if t <= travel {
            renderTravel(t)
        } else if t <= travel + CometMath.finaleDuration {
            enterFinaleIfNeeded()
            let impactTime = t - travel
            if impactTime < CometMath.impactOverlapDuration {
                let fade = 1 - CometMath.easeOutQuad(impactTime / CometMath.impactOverlapDuration)
                renderImpactHead(opacity: fade)
            } else {
                hideImpactHeadIfNeeded()
            }
            renderFinale((t - travel) / CometMath.finaleDuration)
        } else {
            CATransaction.commit()
            finish()
            return
        }
        CATransaction.commit()
    }

    private func finish() {
        guard let done = completion else { return }   // already finished
        completion = nil
        link?.invalidate()
        link = nil
        ([trailHaloGroup, headGlowGroup, rimHaloGroup, flash, glint, breathA]
            + trailCores + [headCore]).forEach { $0.removeFromSuperlayer() }
        rimCore?.removeFromSuperlayer()
        done()
    }

    // MARK: - Layer construction

    private func buildLayers() {
        func makeStroke(_ path: CGPath, _ color: NSColor, width: CGFloat,
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
        func blur(_ layer: CALayer, radius: CGFloat) {
            layer.masksToBounds = false
            layer.contentsScale = contentsScale
            if let f = CIFilter(name: "CIGaussianBlur") {
                f.setValue(radius, forKey: kCIInputRadiusKey)
                layer.filters = [f]
            }
        }

        trailHaloGroup.frame = host.bounds
        trailHaloGroup.compositingFilter = "screenBlendMode"
        blur(trailHaloGroup, radius: CometMath.trailHaloBlur * scale)
        for seg in segments {
            let halo = makeStroke(outline.path, palette.base,
                                  width: seg.width * CometMath.trailHaloWidthRatio * scale)
            halo.opacity = Float(seg.alpha * CometMath.trailHaloAlphaRatio)
            trailHaloGroup.addSublayer(halo)
            trailHalos.append(halo)
        }
        host.addSublayer(trailHaloGroup)

        for seg in segments {
            let core = makeStroke(outline.path, seg.color, width: seg.width * scale)
            core.opacity = Float(seg.alpha)
            host.addSublayer(core)
            trailCores.append(core)
        }

        headGlowGroup.frame = host.bounds
        headGlowGroup.compositingFilter = "screenBlendMode"
        blur(headGlowGroup, radius: CometMath.headGlowBlur * scale)
        headGlow = makeStroke(outline.path, palette.bright,
                              width: CometMath.headGlowWidth * scale, cap: .round)
        headGlowGroup.addSublayer(headGlow)
        host.addSublayer(headGlowGroup)

        headCore = makeStroke(outline.path, .white,
                              width: CometMath.headCoreWidth * scale, cap: .round)
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
            blur(rimHaloGroup, radius: CometMath.rimHaloBlur * scale)
            let halo = makeStroke(rim, palette.bright,
                                  width: CometMath.rimHaloWidth * scale, cap: .round)
            rimHaloGroup.addSublayer(halo)
            host.addSublayer(rimHaloGroup)
            rimHalo = halo
            let rcore = makeStroke(rim, palette.rimCore,
                                   width: CometMath.rimCoreWidth * scale, cap: .round)
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

        // Prime the travel layers before the first display-link tick so no
        // full-path flash can occur between ordering the window front and the
        // first frame.
        renderTravel(0)
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
        let trail = CometMath.trailLength(progress: e, total: totalDistance)
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
        headGlow.lineWidth = CometMath.headGlowWidth * scale * throb
        headGlow.opacity = Float(0.85 * opacity)
        setDash(headGlow, start: position - CometMath.headDashFraction,
                length: CometMath.headDashFraction)
        headCore.lineWidth = CometMath.headCoreWidth * scale * throb
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
        (trailCores + trailHalos).forEach { $0.opacity = 0 }
    }

    private func hideImpactHeadIfNeeded() {
        guard !hasHiddenImpactHead else { return }
        hasHiddenImpactHead = true
        headCore.opacity = 0
        headGlow.opacity = 0
    }

    private func renderFinale(_ u: Double) {
        let f = FinaleState.at(u)

        setCircle(flash, center: outline.landingPoint, radius: f.flashRadius * scale)
        flash.opacity = Float(f.flashOpacity)

        if let rimHalo, let rimCore {
            let total = Double(outline.rimLength)
            let len = max(Double(f.rimFraction) * 2, 0.001) * total
            for layer in [rimHalo, rimCore] {
                layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
                layer.lineDashPhase = -CGFloat((0.5 - Double(f.rimFraction)) * total)
            }
            rimHalo.opacity = Float(0.85 * f.fade)
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
        breathA.opacity = Float(0.9 * o * f.fade)

        setCircle(glint, center: outline.landingPoint, radius: f.glintRadius * scale)
        glint.opacity = Float(f.glintOpacity)
    }
}
