import AppKit
import PowerSnekKit
import QuartzCore

/// Drives the Comet 2.0 animation: a CADisplayLink ticks the reference
/// per-frame math — an eased sweep that launches from the bottom-left,
/// laps the screen clockwise, and decelerates into a landing on the
/// notch — then a flash / rim-glow / breathing-pulse finale.
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
    private let palette: CometPalette
    private let segments: [TrailSegment]
    private let travel: Double
    private let totalDistance: Double
    private var completion: (@MainActor () -> Void)?

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval?

    // Layers, bottom to top (matching the reference stacking order).
    private var trailHalos: [CAShapeLayer] = []
    private let trailHaloGroup = CALayer()
    private var trailCores: [CAShapeLayer] = []
    private let headGlowGroup = CALayer()
    private var headGlow = CAShapeLayer()
    private var headCore = CAShapeLayer()
    private let breathA = CALayer()
    private let rimHaloGroup = CALayer()
    private var rimHalo: CAShapeLayer?
    private var rimCore: CAShapeLayer?
    private let flash = CALayer()
    private let glint = CALayer()

    private init(host: CALayer, view: NSView, outline: ScreenOutline, color: NSColor,
                 laps: Int, lapDuration: Double,
                 completion: @escaping @MainActor () -> Void) {
        self.host = host
        self.view = view
        self.outline = outline
        self.scale = CometMath.scale(forScreenWidth: view.bounds.width)
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
            if let f = CIFilter(name: "CIGaussianBlur") {
                f.setValue(radius, forKey: kCIInputRadiusKey)
                layer.filters = [f]
            }
        }

        trailHaloGroup.frame = host.bounds
        blur(trailHaloGroup, radius: CometMath.trailHaloBlur * scale)
        for seg in segments {
            let halo = makeStroke(outline.path, palette.base,
                                  width: seg.width * CometMath.trailHaloWidthRatio * scale)
            trailHaloGroup.addSublayer(halo)
            trailHalos.append(halo)
        }
        host.addSublayer(trailHaloGroup)

        for seg in segments {
            let core = makeStroke(outline.path, seg.color, width: seg.width * scale)
            host.addSublayer(core)
            trailCores.append(core)
        }

        headGlowGroup.frame = host.bounds
        blur(headGlowGroup, radius: CometMath.headGlowBlur * scale)
        headGlow = makeStroke(outline.path, palette.bright,
                              width: CometMath.headGlowWidth * scale, cap: .round)
        headGlowGroup.addSublayer(headGlow)
        host.addSublayer(headGlowGroup)

        headCore = makeStroke(outline.path, .white,
                              width: CometMath.headCoreWidth * scale, cap: .round)
        host.addSublayer(headCore)

        breathA.backgroundColor = palette.base.cgColor
        breathA.cornerRadius = 30 * scale
        breathA.opacity = 0
        blur(breathA, radius: CometMath.breathABlur * scale)
        host.addSublayer(breathA)

        if let rim = outline.rimPath {
            rimHaloGroup.frame = host.bounds
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

        flash.backgroundColor = NSColor.white.cgColor
        flash.opacity = 0
        blur(flash, radius: CometMath.flashBlur * scale)
        host.addSublayer(flash)

        glint.backgroundColor = NSColor.white.cgColor
        glint.opacity = 0
        host.addSublayer(glint)
    }

    // MARK: - Per-frame rendering

    private func wrap(_ x: Double) -> Double {
        (x.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
    }

    /// Shows a dash segment covering [start, start+length] (perimeter
    /// fractions; wraps across the path start automatically).
    private func setDash(_ layer: CAShapeLayer, start: Double, length: Double,
                         width: CGFloat, opacity: Float) {
        let total = Double(outline.totalLength)
        let len = max(length, 1e-5) * total
        layer.lineDashPattern = [NSNumber(value: len), NSNumber(value: total - len)]
        layer.lineDashPhase = -CGFloat(wrap(start) * total)
        layer.lineWidth = width
        layer.opacity = opacity
    }

    private func setCircle(_ layer: CALayer, center: CGPoint, radius: CGFloat) {
        layer.frame = CGRect(x: center.x - radius, y: center.y - radius,
                             width: radius * 2, height: radius * 2)
        layer.cornerRadius = radius
    }

    private func renderTravel(_ t: Double) {
        let e = totalDistance * CometMath.easedProgress(t / travel)
        let head = wrap(e)
        let trail = CometMath.trailLength(progress: e, total: totalDistance)
        let throb = CGFloat(CometMath.throb(at: t))
        let n = segments.count

        for i in 0..<n {
            let far = Double(i + 1) / Double(n) * trail
            let near = Double(i) / Double(n) * trail
            let seg = segments[i]
            setDash(trailCores[i], start: head - far, length: far - near,
                    width: seg.width * scale, opacity: Float(seg.alpha))
            setDash(trailHalos[i], start: head - far, length: far - near,
                    width: seg.width * CometMath.trailHaloWidthRatio * scale,
                    opacity: Float(seg.alpha * CometMath.trailHaloAlphaRatio))
        }
        setDash(headGlow, start: head - CometMath.headDashFraction,
                length: CometMath.headDashFraction,
                width: CometMath.headGlowWidth * scale * throb, opacity: 0.85)
        setDash(headCore, start: head - CometMath.headDashFraction,
                length: CometMath.headDashFraction,
                width: CometMath.headCoreWidth * scale * throb, opacity: 1)
        setFinaleHidden()
    }

    private func renderFinale(_ u: Double) {
        setTravelHidden()
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
        // Peak opacity raised from the reference (0.6) alongside the tighter
        // bloom blurs for a more pronounced landing pulse.
        breathA.opacity = Float(0.72 * o * f.fade)
        // The reference's second, tighter breath glow is intentionally
        // omitted: it read as a stray green dot at the pulse's center
        // (user feedback during visual verification).

        setCircle(glint, center: outline.landingPoint, radius: f.glintRadius * scale)
        glint.opacity = Float(f.glintOpacity)
    }

    private func setTravelHidden() {
        (trailCores + trailHalos + [headCore, headGlow]).forEach { $0.opacity = 0 }
    }

    private func setFinaleHidden() {
        var layers: [CALayer] = [flash, glint, breathA]
        rimHalo.map { layers.append($0) }
        rimCore.map { layers.append($0) }
        layers.forEach { $0.opacity = 0 }
    }
}
