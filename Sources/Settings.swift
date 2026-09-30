import Foundation

/// Lightweight settings manager with atomic JSON persistence.
final class Settings {
    
    static let shared = Settings()
    
    enum IconStyle: String, Codable, CaseIterable {
        case system = "system"       // 经典电池 (macOS 15 系统原生样式)
        case minimal = "minimal"     // 纯数字样式 (无图标)
        
        var displayName: String {
            switch self {
            case .system: return "🔋 原版电池图标 (系统原生)"
            case .minimal: return "🔢 纯数字样式"
            }
        }
    }
    
    var chargeLimit: Int {
        didSet {
            chargeLimit = max(10, min(100, chargeLimit))
            save()
        }
    }
    
    var notifyOnLimit: Bool {
        didSet { save() }
    }
    
    var autoStopCharging: Bool {
        didSet { save() }
    }
    
    var lowBatteryWarning: Int {
        didSet {
            lowBatteryWarning = max(5, min(50, lowBatteryWarning))
            save()
        }
    }
    
    var showPercentage: Bool {
        didSet { save() }
    }
    
    var iconStyle: IconStyle {
        didSet { save() }
    }
    
    private let configDirectory: URL
    private let configURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("BatteryGuard")
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        configURL = configDirectory.appendingPathComponent("config.json")
        
        chargeLimit = 80
        notifyOnLimit = true
        autoStopCharging = true
        lowBatteryWarning = 20
        showPercentage = true
        iconStyle = .system
        
        load()
    }
    
    private struct SettingsData: Codable {
        var chargeLimit: Int
        var notifyOnLimit: Bool
        var autoStopCharging: Bool
        var lowBatteryWarning: Int
        var showPercentage: Bool?
        var iconStyle: IconStyle?
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              let s = try? JSONDecoder().decode(SettingsData.self, from: data) else { return }
        chargeLimit = max(10, min(100, s.chargeLimit))
        notifyOnLimit = s.notifyOnLimit
        autoStopCharging = s.autoStopCharging
        lowBatteryWarning = max(5, min(50, s.lowBatteryWarning))
        showPercentage = s.showPercentage ?? true
        iconStyle = (s.iconStyle == .minimal) ? .minimal : .system
    }
    
    private func save() {
        let s = SettingsData(
            chargeLimit: chargeLimit,
            notifyOnLimit: notifyOnLimit,
            autoStopCharging: autoStopCharging,
            lowBatteryWarning: lowBatteryWarning,
            showPercentage: showPercentage,
            iconStyle: iconStyle
        )
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
    
    /// Delete configuration files from Application Support.
    func removeConfiguration() {
        try? FileManager.default.removeItem(at: configDirectory)
    }
}
