import Foundation
import IOKit.ps
import PowerSnekKit

/// Reads the internal battery's state once, at celebration time. No polling.
enum ChargeInfoReader {
    /// nil on Macs without an internal battery.
    static func snapshot() -> ChargeSnapshot? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() else { return nil }
        for source in list as NSArray as [AnyObject] {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as NSDictionary? as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            return ChargeSnapshot(
                currentCapacity: (description[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue,
                maxCapacity: (description[kIOPSMaxCapacityKey] as? NSNumber)?.intValue,
                isCharging: (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue,
                isCharged: (description[kIOPSIsChargedKey] as? NSNumber)?.boolValue,
                timeToFullMinutes: (description[kIOPSTimeToFullChargeKey] as? NSNumber)?.intValue)
        }
        return nil
    }
}
