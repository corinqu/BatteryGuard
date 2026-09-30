import Foundation
import IOKit.ps

/// Lightweight battery state monitor using IOKit.
/// Uses IOPSNotificationCreateRunLoopSource for event-driven updates (no polling, zero background CPU).
final class BatteryMonitor {
    
    struct BatteryState {
        let percentage: Int
        let isCharging: Bool
        let isPluggedIn: Bool
        let cycleCount: Int
        let health: Int
        let timeRemaining: Int
    }
    
    var onStateChange: ((BatteryState) -> Void)?
    
    private var runLoopSource: CFRunLoopSource?
    
    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            if let state = monitor.readBatteryState() {
                monitor.onStateChange?(state)
            }
        }, context).takeRetainedValue()
        
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        
        if let state = readBatteryState() {
            onStateChange?(state)
        }
    }
    
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }
    
    func readBatteryState() -> BatteryState? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else { return nil }
        
        let percentage = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
        let isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
        
        let (cycle, health) = readIORegistryBatteryInfo()
        
        return BatteryState(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            cycleCount: cycle,
            health: health,
            timeRemaining: timeRemaining
        )
    }
    
    private func readIORegistryBatteryInfo() -> (cycleCount: Int, health: Int) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return (0, 100) }
        defer { IOObjectRelease(service) }
        
        let cycleCount = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int ?? 0
        let maxCapacity = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int ?? 100
        
        return (cycleCount, maxCapacity)
    }
}
