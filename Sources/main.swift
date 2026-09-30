import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let batteryMonitor = BatteryMonitor()
    private let chargeController = ChargeController()
    private let statusBar = StatusBarController()
    private let settings = Settings.shared
    
    private var hasNotifiedLimit = false
    private var chargingWasStopped = false
    private var isDischarging = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        // First-run setup: ensure dependencies are ready
        if !performFirstRunSetup() {
            NSApp.terminate(nil)
            return
        }
        
        // Setup LaunchAgent for auto-start
        setupLaunchAgent()
        
        // Setup menu bar
        statusBar.setup()
        wireUpMenuActions()
        
        // Apply saved charge limit
        if settings.chargeLimit < 100 {
            chargeController.setChargeLimit(settings.chargeLimit)
        }
        
        // Start battery monitoring (event-driven, zero polling)
        batteryMonitor.onStateChange = { [weak self] state in
            self?.handleBatteryUpdate(state)
        }
        batteryMonitor.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        batteryMonitor.stop()
        if chargingWasStopped || isDischarging {
            chargeController.enableAdapter()
        }
    }
    
    // MARK: - First Run Setup
    
    // MARK: - First Run Setup (Zero Homebrew Dependency, 100% Self-Contained)
    
    private func performFirstRunSetup() -> Bool {
        // 1. If daemon is already running and accessible, proceed immediately
        if chargeController.isDaemonRunning() {
            return true
        }
        
        // 2. Prompt user to authorize the privileged helper (one-time setup)
        let alert = NSAlert()
        alert.messageText = "启用电池健康守护服务"
        alert.informativeText = """
        BatteryGuard 需要安装后台核心守护服务，以实现芯片级精准控制充电阈值。
        
        点击「授权并启用」后，系统将弹出密码窗口，请输入你的 Mac 登录密码完成一次性授权。
        
        此操作完全基于 Apple 官方电源管理规范，不影响硬件保修与系统安全。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "授权并启用")
        alert.addButton(withTitle: "退出")
        
        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }
        
        guard let helperSource = chargeController.bundledBattPath else {
            showError("安装失败", message: "未找到内置的 helper 核心组件，请重新下载安装 BatteryGuard。")
            return false
        }
        
        let success = installPrivilegedHelper(from: helperSource)
        if !success {
            showError("服务启用失败", message: "未能成功注册后台守护服务。请确保在弹出窗口中正确输入了 Mac 登录密码。")
            return false
        }
        
        // Wait briefly for daemon socket initialization
        for _ in 0..<10 {
            if chargeController.isDaemonRunning() {
                break
            }
            Thread.sleep(forTimeInterval: 0.3)
        }
        
        return true
    }
    
    private func installPrivilegedHelper(from sourcePath: String) -> Bool {
        let escapedSource = sourcePath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        do shell script "
        /bin/mkdir -p /Library/PrivilegedHelperTools
        /bin/cp '\(escapedSource)' /Library/PrivilegedHelperTools/com.batteryguard.helper
        /bin/chmod 755 /Library/PrivilegedHelperTools/com.batteryguard.helper
        /usr/sbin/chown root:wheel /Library/PrivilegedHelperTools/com.batteryguard.helper

        /bin/cat << 'PLIST' > /Library/LaunchDaemons/com.batteryguard.daemon.plist
        <?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>
        <!DOCTYPE plist PUBLIC \\"-//Apple//DTD PLIST 1.0//EN\\" \\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\\">
        <plist version=\\"1.0\\">
        <dict>
            <key>KeepAlive</key>
            <true/>
            <key>Label</key>
            <string>com.batteryguard.daemon</string>
            <key>ProcessType</key>
            <string>Interactive</string>
            <key>ProgramArguments</key>
            <array>
                <string>/Library/PrivilegedHelperTools/com.batteryguard.helper</string>
                <string>daemon</string>
                <string>--always-allow-non-root-access</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        PLIST

        /bin/launchctl load -w /Library/LaunchDaemons/com.batteryguard.daemon.plist 2>/dev/null || /bin/launchctl bootstrap system /Library/LaunchDaemons/com.batteryguard.daemon.plist 2>/dev/null
        " with administrator privileges
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func showError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
    
    // MARK: - LaunchAgent Auto-Start
    
    private func setupLaunchAgent() {
        let launchAgentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentDir.appendingPathComponent("com.batteryguard.app.plist")
        
        if FileManager.default.fileExists(atPath: plistPath.path) { return }
        
        guard let executableURL = Bundle.main.executableURL else { return }
        
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.batteryguard.app</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executableURL.path)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>ProcessType</key>
            <string>Background</string>
            <key>LowPriorityBackgroundIO</key>
            <true/>
        </dict>
        </plist>
        """
        
        try? FileManager.default.createDirectory(at: launchAgentDir, withIntermediateDirectories: true)
        try? plist.write(to: plistPath, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Menu Actions
    
    private func wireUpMenuActions() {
        statusBar.onSetLimit = { [weak self] limit in
            self?.setChargeLimit(limit)
        }
        statusBar.onToggleAutoStop = { [weak self] in
            guard let self = self else { return }
            self.settings.autoStopCharging.toggle()
            if let state = self.batteryMonitor.readBatteryState() {
                self.statusBar.updateDisplay(state: state, settings: self.settings, isDischarging: self.isDischarging)
            }
            if !self.settings.autoStopCharging && self.chargingWasStopped {
                self.chargeController.enableAdapter()
                self.chargingWasStopped = false
            }
        }
        statusBar.onToggleNotify = { [weak self] in
            guard let self = self else { return }
            self.settings.notifyOnLimit.toggle()
            if let state = self.batteryMonitor.readBatteryState() {
                self.statusBar.updateDisplay(state: state, settings: self.settings, isDischarging: self.isDischarging)
            }
        }
        statusBar.onToggleShowPercentage = { [weak self] in
            guard let self = self else { return }
            self.settings.showPercentage.toggle()
            if let state = self.batteryMonitor.readBatteryState() {
                self.statusBar.updateDisplay(state: state, settings: self.settings, isDischarging: self.isDischarging)
            }
        }
        statusBar.onSelectIconStyle = { [weak self] style in
            guard let self = self else { return }
            self.settings.iconStyle = style
            if let state = self.batteryMonitor.readBatteryState() {
                self.statusBar.updateDisplay(state: state, settings: self.settings, isDischarging: self.isDischarging)
            }
        }
        statusBar.onDischargeToTarget = { [weak self] in
            self?.toggleDischarge()
        }
        statusBar.onUninstall = {
            Uninstaller.shared.performInteractiveUninstall()
        }
    }
    
    // MARK: - Discharge to Target
    
    private func toggleDischarge() {
        if isDischarging {
            stopDischarge(reason: "用户手动停止")
        } else {
            startDischarge()
        }
    }
    
    private func startDischarge() {
        guard let state = batteryMonitor.readBatteryState() else { return }
        let target = settings.chargeLimit
        
        if state.percentage <= target {
            NotificationManager.shared.sendNotification(
                title: "✅ 无需放电",
                body: "当前电量 \(state.percentage)% 已在设定阈值 \(target)% 范围内",
                critical: false
            )
            return
        }
        
        isDischarging = true
        chargeController.disableAdapter()
        
        NotificationManager.shared.sendNotification(
            title: "⏬ 开始放电",
            body: "正在从 \(state.percentage)% 放电至目标 \(target)%，适配器已暂停供电",
            critical: false
        )
        statusBar.updateDisplay(state: state, settings: settings, isDischarging: isDischarging)
    }
    
    private func stopDischarge(reason: String) {
        isDischarging = false
        chargeController.enableAdapter()
        chargeController.setChargeLimit(settings.chargeLimit)
        
        if let state = batteryMonitor.readBatteryState() {
            NotificationManager.shared.sendNotification(
                title: "⏹️ 放电结束",
                body: "\(reason)，当前电量 \(state.percentage)%，适配器已恢复正常供电",
                critical: true
            )
            statusBar.updateDisplay(state: state, settings: settings, isDischarging: false)
        }
    }
    
    // MARK: - Core Logic
    
    private func handleBatteryUpdate(_ state: BatteryMonitor.BatteryState) {
        statusBar.updateDisplay(state: state, settings: settings, isDischarging: isDischarging)
        
        let limit = settings.chargeLimit
        
        if isDischarging {
            if state.percentage <= limit {
                stopDischarge(reason: "已达到设定目标电量 \(limit)%")
            }
            return
        }
        
        if state.percentage >= limit && state.isCharging {
            if settings.notifyOnLimit && !hasNotifiedLimit {
                NotificationManager.shared.sendNotification(
                    title: "⚡ 电量已达上限",
                    body: "当前电量 \(state.percentage)%，已达到设定上限 \(limit)%",
                    critical: true
                )
                hasNotifiedLimit = true
            }
            
            if settings.autoStopCharging && !chargingWasStopped {
                let success = chargeController.setChargeLimit(limit)
                if success {
                    chargingWasStopped = true
                    NotificationManager.shared.sendNotification(
                        title: "🔋 已自动停止充电",
                        body: "电量达到 \(state.percentage)%，充电已自动暂停",
                        critical: false
                    )
                }
            }
        }
        
        if state.percentage < limit - 3 {
            hasNotifiedLimit = false
            if chargingWasStopped { chargingWasStopped = false }
        }
        
        if !state.isPluggedIn && state.percentage <= settings.lowBatteryWarning && state.percentage > 0 {
            NotificationManager.shared.sendNotification(
                title: "🪫 电量不足",
                body: "当前电量 \(state.percentage)%，请连接充电器",
                critical: true
            )
        }
    }
    
    private func setChargeLimit(_ limit: Int) {
        if isDischarging { stopDischarge(reason: "充电上限已更改") }
        
        settings.chargeLimit = limit
        chargeController.setChargeLimit(limit)
        
        NotificationManager.shared.sendNotification(
            title: "⚙️ 充电上限已更新",
            body: limit == 100 ? "已取消限制，恢复默认充电" : "充电上限已设为 \(limit)%",
            critical: false
        )
        
        hasNotifiedLimit = false
        if limit == 100 && chargingWasStopped {
            chargeController.enableAdapter()
            chargingWasStopped = false
        }
        
        if let state = batteryMonitor.readBatteryState() {
            statusBar.updateDisplay(state: state, settings: settings, isDischarging: isDischarging)
        }
    }
}

// MARK: - Application Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
