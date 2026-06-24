import AppKit
import QuartzCore

public enum CometAnimator {

    @MainActor
    public static func run(on host: CALayer,
                           path: CGPath,
                           color: NSColor,
                           lapDuration: Double,
                           lapCount: Int,
                           completion: @escaping @MainActor () -> Void) {
        let length = pathLength(path)
        guard length > 1 else { completion(); return }

        let laps = Float(max(1, lapCount))
        let dur = max(0.1, lapDuration)
        let base = color.usingColorSpace(.sRGB) ?? color
        let cg = base.cgColor

        // --- Tunable look ---
        let headWidth: CGFloat = 14             // bar thickness at the head
        let headDiameter = headWidth * 1.8      // bright circular head
        let cometLen = max(160, length * 0.20)  // length of the comet + tail
        let tailSegments = 16                   // stacked strokes that fade to the tail
        let tailHueShift: CGFloat = 0.07        // gentle hue drift toward the tail

        let headLen: CGFloat = 1
        let headDash: [NSNumber] = [NSNumber(value: Double(headLen)),
                                    NSNumber(value: Double(length - headLen))]

        func phaseAnim(from f: CGFloat, to t: CGFloat) -> CABasicAnimation {
            let a = CABasicAnimation(keyPath: "lineDashPhase")
            a.fromValue = f
            a.toValue = t
            a.duration = dur
            a.repeatCount = laps
            a.timingFunction = CAMediaTimingFunction(name: .linear)
            a.isRemovedOnCompletion = false
            a.fillMode = .forwards
            return a
        }

        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        base.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        sat = min(1, max(0.7, sat))
        bri = min(1, max(0.9, bri))

        // Tapering, hue-shifting tail: stacked strokes that all share the head's
        // leading edge but reach progressively further back. Each is a single
        // CAShapeLayer in the host's coordinate space, so nothing can drift
        // apart. Longest (tail) is added first/bottom, shortest (head) on top —
        // overlap near the head builds brightness; the tail thins and fades.
        for i in stride(from: tailSegments, through: 1, by: -1) {
            let frac = CGFloat(i) / CGFloat(tailSegments)     // 1 = full tail … small = head
            let segLen = cometLen * frac
            let seg = CAShapeLayer()
            seg.path = path
            seg.fillColor = nil
            seg.lineCap = .round
            seg.lineJoin = .round
            seg.lineWidth = headWidth * (1 - 0.30 * frac)     // thinner toward the tail
            let h = (hue + tailHueShift * frac).truncatingRemainder(dividingBy: 1)
            let col = NSColor(hue: h < 0 ? h + 1 : h, saturation: sat, brightness: bri, alpha: 1)
            // Alpha 1/i makes the stacked transparencies telescope to an exactly
            // LINEAR fade (uniform steps) instead of an exponential one that bands.
            seg.strokeColor = col.withAlphaComponent(1.0 / CGFloat(i)).cgColor
            seg.lineDashPattern = [NSNumber(value: Double(segLen)),
                                   NSNumber(value: Double(length - segLen))]
            if i <= 2 {                                       // soft halo on the bright front
                seg.shadowColor = cg
                seg.shadowRadius = 13
                seg.shadowOpacity = 0.8
                seg.shadowOffset = .zero
            }
            host.addSublayer(seg)
            let phi0 = segLen - cometLen                      // anchor every leading edge at the head
            seg.add(phaseAnim(from: phi0, to: phi0 - length), forKey: "phase")
        }

        // Bright circular head leading the tail, with a stronger glow.
        let headGlow = CAShapeLayer()
        headGlow.path = path
        headGlow.fillColor = nil
        headGlow.strokeColor = cg
        headGlow.lineWidth = headDiameter
        headGlow.lineCap = .round
        headGlow.lineDashPattern = headDash
        headGlow.shadowColor = cg
        headGlow.shadowRadius = 28
        headGlow.shadowOpacity = 1
        headGlow.shadowOffset = .zero
        host.addSublayer(headGlow)

        let headCore = CAShapeLayer()
        headCore.path = path
        headCore.fillColor = nil
        headCore.strokeColor = (NSColor.white.blended(withFraction: 0.55, of: base) ?? base).cgColor
        headCore.lineWidth = headDiameter * 0.55
        headCore.lineCap = .round
        headCore.lineDashPattern = headDash
        host.addSublayer(headCore)

        let headAnim = phaseAnim(from: -cometLen, to: -(length + cometLen))  // head at the front edge

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.4
            fade.isRemovedOnCompletion = false
            fade.fillMode = .forwards
            CATransaction.begin()
            CATransaction.setCompletionBlock { completion() }
            host.opacity = 0
            host.add(fade, forKey: "fade")
            CATransaction.commit()
        }
        headGlow.add(headAnim, forKey: "phase")
        headCore.add(headAnim, forKey: "phase")
        CATransaction.commit()
    }

    /// Approximate length of a CGPath by flattening curves.
    private static func pathLength(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var current = CGPoint.zero
        var start = CGPoint.zero
        path.applyWithBlock { elementPtr in
            let e = elementPtr.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]; start = current
            case .addLineToPoint:
                length += dist(current, e.points[0]); current = e.points[0]
            case .addQuadCurveToPoint:
                length += quadLength(current, e.points[0], e.points[1]); current = e.points[1]
            case .addCurveToPoint:
                length += cubicLength(current, e.points[0], e.points[1], e.points[2]); current = e.points[2]
            case .closeSubpath:
                length += dist(current, start); current = start
            @unknown default:
                break
            }
        }
        return length
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private static func quadLength(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, samples: Int = 16) -> CGFloat {
        var prev = p0, total: CGFloat = 0
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let mt = 1 - t
            let x = mt*mt*p0.x + 2*mt*t*c.x + t*t*p1.x
            let y = mt*mt*p0.y + 2*mt*t*c.y + t*t*p1.y
            let pt = CGPoint(x: x, y: y)
            total += dist(prev, pt); prev = pt
        }
        return total
    }

    private static func cubicLength(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, samples: Int = 16) -> CGFloat {
        var prev = p0, total: CGFloat = 0
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let mt = 1 - t
            let x = mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p1.x
            let y = mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p1.y
            let pt = CGPoint(x: x, y: y)
            total += dist(prev, pt); prev = pt
        }
        return total
    }
}
