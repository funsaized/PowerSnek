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
        let cg = color.cgColor
        let brightCG = (NSColor.white.blended(withFraction: 0.5, of: color) ?? color).cgColor
        let length = pathLength(path)
        guard length > 1 else { completion(); return }
        let comet = max(40, length * 0.10)         // visible comet length in points
        let dash: [NSNumber] = [NSNumber(value: Double(comet)),
                                NSNumber(value: Double(length - comet))]
        let laps = Float(max(1, lapCount))

        // Wide, dim glow layer
        let glow = CAShapeLayer()
        glow.path = path
        glow.fillColor = nil
        glow.strokeColor = cg
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.opacity = 0.55
        glow.lineDashPattern = dash
        glow.shadowColor = cg
        glow.shadowRadius = 14
        glow.shadowOpacity = 1
        glow.shadowOffset = .zero

        // Narrow, bright core layer
        let core = CAShapeLayer()
        core.path = path
        core.fillColor = nil
        core.strokeColor = brightCG
        core.lineWidth = 2.5
        core.lineCap = .round
        core.lineDashPattern = dash
        core.shadowColor = cg
        core.shadowRadius = 7
        core.shadowOpacity = 1
        core.shadowOffset = .zero

        host.addSublayer(glow)
        host.addSublayer(core)

        let phase = CABasicAnimation(keyPath: "lineDashPhase")
        phase.fromValue = 0
        phase.toValue = -length                    // negative advances forward along the path
        phase.duration = max(0.1, lapDuration)
        phase.repeatCount = laps
        phase.timingFunction = CAMediaTimingFunction(name: .linear)
        phase.isRemovedOnCompletion = false
        phase.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // Fade the whole host out, then report completion on the main queue.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.4
            fade.isRemovedOnCompletion = false
            fade.fillMode = .forwards
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                DispatchQueue.main.async {
                    completion()
                }
            }
            host.opacity = 0
            host.add(fade, forKey: "fade")
            CATransaction.commit()
        }
        glow.add(phase, forKey: "phase")
        core.add(phase, forKey: "phase")
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
