import Foundation
import IOKit.ps
import PowerSnekKit

public final class PowerMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var previous: PowerState = .unknown
    private var onPlugIn: (() -> Void)?

    public init() {}

    deinit { stop() }

    public static func currentState() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return .unknown }
        guard let typeCF = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else { return .unknown }
        let type = typeCF as String
        switch type {
        case kIOPMACPowerKey: return .ac
        case kIOPMBatteryPowerKey: return .battery
        default: return .unknown
        }
    }

    public func start(onPlugIn: @escaping () -> Void) {
        stop()
        self.onPlugIn = onPlugIn
        self.previous = PowerMonitor.currentState()   // seed silently; never fires on launch

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handleChange()
        }, context)?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func handleChange() {
        let current = PowerMonitor.currentState()
        if PowerState.shouldFire(previous: previous, current: current) {
            onPlugIn?()
        }
        previous = current
    }

    public func stop() {
        if let s = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .defaultMode)
            runLoopSource = nil
        }
    }
}
