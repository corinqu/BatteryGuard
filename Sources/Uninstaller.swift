import AppKit

/// Handles clean, one-click uninstallation with settings restoration and optional dependency cleanup.
final class Uninstaller {
    
    static let shared = Uninstaller()
    
    private init() {}
    
    /// Launches the complete interactive uninstallation wizard.
    func performInteractiveUninstall() {
        // Step 1: Confirmation Alert
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "确定要卸载 BatteryGuard 吗？"
        confirmAlert.informativeText = """
        卸载程序将自动执行以下操作：
        
        1. 恢复充电上限为 macOS 系统默认（100% 不限制）
        2. 恢复电源适配器正常供电
        3. 移除开机自启动配置 (LaunchAgent)
        4. 清除本地配置文件与用户数据
        5. 从应用程序中移除 BatteryGuard
        """
        confirmAlert.alertStyle = .warning
        confirmAlert.addButton(withTitle: "继续卸载")
        confirmAlert.addButton(withTitle: "取消")
        
        guard confirmAlert.runModal() == .alertFirstButtonReturn else {
            return
        }
        
        // Step 2: Choice regarding `batt`
        let battAlert = NSAlert()
        battAlert.messageText = "是否保留底层充电控制组件 (batt)？"
        battAlert.informativeText = """
        batt 是与 Apple Silicon SMC 芯片通信的开源后台服务。
        
        • 【保留 batt（推荐）】：保留该组件，若以后重新安装 BatteryGuard 无需再次配置系统权限。
        • 【彻底卸载 batt】：停止后台服务并彻底卸载 batt（需要输入一次管理员密码以撤销系统服务）。
        """
        battAlert.alertStyle = .informational
        battAlert.addButton(withTitle: "保留 batt (推荐)")
        battAlert.addButton(withTitle: "彻底卸载 batt")
        battAlert.addButton(withTitle: "取消")
        
        let battChoice = battAlert.runModal()
        if battChoice == .alertThirdButtonReturn {
            return
        }
        let shouldRemoveBatt = (battChoice == .alertSecondButtonReturn)
        
        // Step 3: Execute Restoration & Uninstallation
        executeUninstall(removeBatt: shouldRemoveBatt)
    }
    
    private func executeUninstall(removeBatt: Bool) {
        // 1. Restore factory defaults (limit 100%, adapter enabled)
        let chargeController = ChargeController()
        chargeController.restoreFactoryDefaults()
        
        // 2. Remove LaunchAgent
        let launchAgentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistURL = launchAgentDir.appendingPathComponent("com.batteryguard.app.plist")
        if FileManager.default.fileExists(atPath: plistURL.path) {
            let unloadProcess = Process()
            unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadProcess.arguments = ["unload", plistURL.path]
            try? unloadProcess.run()
            unloadProcess.waitUntilExit()
            try? FileManager.default.removeItem(at: plistURL)
        }
        
        // 3. Clear Configuration
        Settings.shared.removeConfiguration()
        
        // 4. Optionally remove privileged helper service
        if removeBatt {
            let script = """
            do shell script "
            /bin/launchctl unload -w /Library/LaunchDaemons/com.batteryguard.daemon.plist 2>/dev/null
            /bin/launchctl bootout system/com.batteryguard.daemon 2>/dev/null
            /bin/rm -f /Library/LaunchDaemons/com.batteryguard.daemon.plist 2>/dev/null
            /bin/rm -f /Library/PrivilegedHelperTools/com.batteryguard.helper 2>/dev/null
            /opt/homebrew/bin/brew services stop batt 2>/dev/null
            /bin/launchctl bootout system/sh.brew.batt 2>/dev/null
            /bin/rm -f /Library/LaunchDaemons/sh.brew.batt.plist 2>/dev/null
            " with administrator privileges
            """
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
        }
        
        // 5. Remove App Bundle (self-deletion via delayed script)
        let appBundleURL = Bundle.main.bundleURL
        if appBundleURL.pathExtension == "app" {
            let escapedPath = appBundleURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let deleteScript = "sleep 1; /bin/rm -rf \"\(escapedPath)\""
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", deleteScript]
            try? proc.run()
        }
        
        // 6. Completion Notification / Alert
        let doneAlert = NSAlert()
        doneAlert.messageText = "卸载已完成"
        doneAlert.informativeText = "BatteryGuard 已完全卸载。\n充电限制已还原为系统默认状态（100%），电源适配器正常供电。"
        doneAlert.alertStyle = .informational
        doneAlert.addButton(withTitle: "完成")
        doneAlert.runModal()
        
        // 7. Terminate
        NSApplication.shared.terminate(nil)
    }
}
