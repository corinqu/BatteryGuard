import AppKit

/// Menu bar status item controller.
final class StatusBarController {
    
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    
    // Dynamic menu items
    private var batteryInfoItem: NSMenuItem!
    private var chargingStatusItem: NSMenuItem!
    private var healthInfoItem: NSMenuItem!
    private var limitItem: NSMenuItem!
    private var autoStopItem: NSMenuItem!
    private var notifyItem: NSMenuItem!
    private var showPercentageItem: NSMenuItem!
    private var iconStyleSubmenuItem: NSMenuItem!
    private var dischargeItem: NSMenuItem!
    
    var onSetLimit: ((Int) -> Void)?
    var onToggleAutoStop: (() -> Void)?
    var onToggleNotify: (() -> Void)?
    var onToggleShowPercentage: (() -> Void)?
    var onSelectIconStyle: ((Settings.IconStyle) -> Void)?
    var onDischargeToTarget: (() -> Void)?
    var onUninstall: (() -> Void)?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        buildMenu()
        statusItem.menu = menu
    }
    
    func updateDisplay(state: BatteryMonitor.BatteryState, settings: Settings, isDischarging: Bool) {
        guard let button = statusItem.button else { return }
        
        // 关键逻辑：判断是否处于“真正充电”状态
        // 只有当前电池正在流入电流 (isCharging == true) 且未处于主动放电模式时，才属于真正充电
        // 如果插着适配器但电量已达到上限（处于暂停或未充电状态），isActuallyCharging 为 false
        let isActuallyCharging = state.isCharging && !isDischarging
        
        // 1. 更新状态栏图标与百分比显示
        if settings.iconStyle == .minimal {
            button.image = nil
            let prefix = isDischarging ? "⏬ " : (isActuallyCharging ? "⚡ " : "")
            button.title = "\(prefix)\(state.percentage)%"
        } else {
            let iconImage = makeSystemBatteryIcon(
                percentage: state.percentage,
                isActuallyCharging: isActuallyCharging
            )
            button.image = iconImage
            button.title = settings.showPercentage ? " \(state.percentage)%" : ""
        }
        
        // 2. 更新菜单内各项信息
        batteryInfoItem.title = "🔋 电量: \(state.percentage)%"
        
        if isDischarging {
            chargingStatusItem.title = "⏬ 状态: 正在放电至 \(settings.chargeLimit)%..."
        } else if isActuallyCharging {
            chargingStatusItem.title = "⚡ 状态: 正在充电"
        } else if state.isPluggedIn {
            chargingStatusItem.title = "🔌 状态: 已接电源 (未充电/处于上限保护)"
        } else {
            let timeStr = state.timeRemaining > 0 ? " (剩余 \(state.timeRemaining) 分钟)" : ""
            chargingStatusItem.title = "🔋 状态: 使用电池\(timeStr)"
        }
        
        healthInfoItem.title = "💚 健康度: \(state.health)%  循环: \(state.cycleCount) 次"
        limitItem.title = "⚙️ 充电上限: \(settings.chargeLimit)%"
        
        // 3. 更新设置勾选项
        autoStopItem.title = "\(settings.autoStopCharging ? "✅" : "❌") 自动停充"
        notifyItem.title = "\(settings.notifyOnLimit ? "✅" : "❌") 到限提醒"
        showPercentageItem.title = "\(settings.showPercentage ? "✅" : "❌") 状态栏显示百分比"
        
        // 4. 更新图标样式单选项 (仅原版图标与纯数字)
        if let submenu = iconStyleSubmenuItem.submenu {
            for item in submenu.items {
                if let style = item.representedObject as? Settings.IconStyle {
                    item.state = (style == settings.iconStyle) ? .on : .off
                }
            }
        }
        
        // 5. 更新主动放电按钮状态
        if isDischarging {
            dischargeItem.title = "⏹️ 停止放电"
            dischargeItem.isEnabled = true
        } else if state.percentage > settings.chargeLimit {
            dischargeItem.title = "⏬ 放电到 \(settings.chargeLimit)% (当前 \(state.percentage)%)"
            dischargeItem.isEnabled = true
        } else {
            dischargeItem.title = "✅ 电量已在目标范围内"
            dischargeItem.isEnabled = false
        }
    }
    
    // MARK: - macOS 15 原版电池图标绘制 (1:1 矢量精绘)
    
    /// 绘制严格匹配 macOS 15 系统原版样式的菜单栏电池图标
    /// - 比例：22x11 标准电池长宽比
    /// - 内部电量：按实际百分比平滑精确填充，非粗糙分级
    /// - 闪电标志：仅在真正充电时绘制在电池正中；不充电时不显示
    /// - isTemplate：自动根据系统浅色/深色主题适配颜色
    private func makeSystemBatteryIcon(percentage: Int, isActuallyCharging: Bool) -> NSImage {
        let size = NSSize(width: 24, height: 11.5)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            
            // 电池外壳主体 (圆角矩形，贴合系统原生弧度)
            let bodyRect = CGRect(x: 1.0, y: 0.75, width: 19.5, height: 10.0)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            
            // 电池右侧正极极耳
            let capRect = CGRect(x: 21.25, y: 3.5, width: 1.5, height: 4.5)
            let capPath = CGPath(roundedRect: capRect, cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
            
            // 绘制极耳 (实心)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.addPath(capPath)
            ctx.fillPath()
            
            // 绘制外框 (1.0pt 线宽)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.0)
            ctx.addPath(bodyPath)
            ctx.strokePath()
            
            // 内部电量平滑精准填充 (两端留 1.5pt 内边距)
            let fillPadding: CGFloat = 1.5
            let maxFillWidth = bodyRect.width - (fillPadding * 2)
            let clampedPercentage = max(0, min(100, percentage))
            let fillWidth = maxFillWidth * CGFloat(clampedPercentage) / 100.0
            
            if fillWidth > 0.5 {
                let fillRect = CGRect(
                    x: bodyRect.minX + fillPadding,
                    y: bodyRect.minY + fillPadding,
                    width: fillWidth,
                    height: bodyRect.height - (fillPadding * 2)
                )
                let fillPath = CGPath(roundedRect: fillRect, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                ctx.addPath(fillPath)
                ctx.fillPath()
            }
            
            // 真正充电时在中心绘制对比度分明的灰色闪电符号
            if isActuallyCharging {
                let cx = bodyRect.midX
                let cy = bodyRect.midY
                
                let bolt = CGMutablePath()
                bolt.move(to: CGPoint(x: cx + 0.5, y: cy + 4.2))
                bolt.addLine(to: CGPoint(x: cx - 2.5, y: cy - 0.2))
                bolt.addLine(to: CGPoint(x: cx - 0.2, y: cy - 0.2))
                bolt.addLine(to: CGPoint(x: cx - 0.7, y: cy - 4.2))
                bolt.addLine(to: CGPoint(x: cx + 2.5, y: cy + 0.2))
                bolt.addLine(to: CGPoint(x: cx + 0.2, y: cy + 0.2))
                bolt.closeSubpath()
                
                // 1. 先用透明隔离槽 (Clear Blend) 在白色电量条上裁切出防粘连的微隙边界
                ctx.saveGState()
                ctx.setBlendMode(.clear)
                ctx.setLineWidth(2.2)
                ctx.setLineJoin(.round)
                ctx.addPath(bolt)
                ctx.strokePath()
                ctx.addPath(bolt)
                ctx.fillPath()
                ctx.restoreGState()
                
                // 2. 居中填充细腻的半透明系统灰色闪电 (Alpha 0.48 灰度，消除白底白字冲突，层次清晰)
                ctx.saveGState()
                ctx.setFillColor(NSColor(white: 0, alpha: 0.48).cgColor)
                ctx.addPath(bolt)
                ctx.fillPath()
                ctx.restoreGState()
            }
            
            return true
        }
        image.isTemplate = true
        return image
    }
    
    // MARK: - Menu Construction
    
    private func buildMenu() {
        menu.autoenablesItems = false
        
        // 电池状态详情
        batteryInfoItem = NSMenuItem(title: "🔋 电量: --%", action: nil, keyEquivalent: "")
        batteryInfoItem.isEnabled = false
        menu.addItem(batteryInfoItem)
        
        chargingStatusItem = NSMenuItem(title: "⚡ 状态: 检测中...", action: nil, keyEquivalent: "")
        chargingStatusItem.isEnabled = false
        menu.addItem(chargingStatusItem)
        
        healthInfoItem = NSMenuItem(title: "💚 健康度: --%", action: nil, keyEquivalent: "")
        healthInfoItem.isEnabled = false
        menu.addItem(healthInfoItem)
        
        menu.addItem(.separator())
        
        // 主动自然放电
        dischargeItem = NSMenuItem(title: "⏬ 放电到目标值", action: #selector(dischargeToTarget), keyEquivalent: "")
        dischargeItem.target = self
        dischargeItem.isEnabled = true
        menu.addItem(dischargeItem)
        
        menu.addItem(.separator())
        
        // 预设充电上限
        limitItem = NSMenuItem(title: "⚙️ 充电上限: 80%", action: nil, keyEquivalent: "")
        limitItem.isEnabled = false
        menu.addItem(limitItem)
        
        let presets = [60, 70, 75, 80, 85, 90, 95, 100]
        for preset in presets {
            let label = preset == 100 ? "  设为 \(preset)% (不限制)" : "  设为 \(preset)%"
            let item = NSMenuItem(title: label, action: #selector(limitSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = preset
            item.isEnabled = true
            menu.addItem(item)
        }
        
        menu.addItem(.separator())
        
        // 显示样式偏好
        showPercentageItem = NSMenuItem(title: "✅ 状态栏显示百分比", action: #selector(toggleShowPercentage), keyEquivalent: "")
        showPercentageItem.target = self
        showPercentageItem.isEnabled = true
        menu.addItem(showPercentageItem)
        
        iconStyleSubmenuItem = NSMenuItem(title: "🎨 电池显示样式", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        for style in Settings.IconStyle.allCases {
            let item = NSMenuItem(title: style.displayName, action: #selector(iconStyleSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style
            styleSubmenu.addItem(item)
        }
        iconStyleSubmenuItem.submenu = styleSubmenu
        menu.addItem(iconStyleSubmenuItem)
        
        menu.addItem(.separator())
        
        // 行为开关
        autoStopItem = NSMenuItem(title: "✅ 自动停充", action: #selector(toggleAutoStop), keyEquivalent: "")
        autoStopItem.target = self
        autoStopItem.isEnabled = true
        menu.addItem(autoStopItem)
        
        notifyItem = NSMenuItem(title: "✅ 到限提醒", action: #selector(toggleNotify), keyEquivalent: "")
        notifyItem.target = self
        notifyItem.isEnabled = true
        menu.addItem(notifyItem)
        
        menu.addItem(.separator())
        
        // 卸载与退出
        let uninstallItem = NSMenuItem(title: "🗑️ 卸载 BatteryGuard...", action: #selector(uninstall), keyEquivalent: "")
        uninstallItem.target = self
        uninstallItem.isEnabled = true
        menu.addItem(uninstallItem)
        
        let quitItem = NSMenuItem(title: "退出 BatteryGuard", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
    }
    
    @objc private func limitSelected(_ sender: NSMenuItem) {
        onSetLimit?(sender.tag)
    }
    
    @objc private func toggleAutoStop() {
        onToggleAutoStop?()
    }
    
    @objc private func toggleNotify() {
        onToggleNotify?()
    }
    
    @objc private func toggleShowPercentage() {
        onToggleShowPercentage?()
    }
    
    @objc private func iconStyleSelected(_ sender: NSMenuItem) {
        if let style = sender.representedObject as? Settings.IconStyle {
            onSelectIconStyle?(style)
        }
    }
    
    @objc private func dischargeToTarget() {
        onDischargeToTarget?()
    }
    
    @objc private func uninstall() {
        onUninstall?()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
