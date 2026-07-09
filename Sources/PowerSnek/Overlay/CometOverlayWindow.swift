import AppKit

public final class CometOverlayWindow: NSWindow {
    public let hostLayer = CALayer()

    public init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // fully click-through
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel())) // over menu bar + fullscreen
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        setFrame(screen.frame, display: false)

        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        if let root = view.layer {
            root.contentsScale = screen.backingScaleFactor
            root.allowsEdgeAntialiasing = true
            hostLayer.frame = view.bounds
            hostLayer.contentsScale = screen.backingScaleFactor
            hostLayer.allowsEdgeAntialiasing = true
            root.addSublayer(hostLayer)
        }
        contentView = view
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}
