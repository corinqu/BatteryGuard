import Foundation
import UserNotifications

/// Manages system notifications with rate limiting and fallback.
final class NotificationManager {
    
    static let shared = NotificationManager()
    
    private var lastNotificationTime: Date?
    private let minimumInterval: TimeInterval = 300 // 5 minutes between non-critical notices
    
    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func sendNotification(title: String, body: String, critical: Bool = false) {
        if !critical, let last = lastNotificationTime, Date().timeIntervalSince(last) < minimumInterval {
            return
        }
        lastNotificationTime = Date()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "BatteryGuard-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                self.fallbackNotification(title: title, body: body)
            }
        }
    }
    
    private func fallbackNotification(title: String, body: String) {
        let t = title.replacingOccurrences(of: "\"", with: "\\\"")
        let b = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(b)\" with title \"\(t)\" sound name \"Glass\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
