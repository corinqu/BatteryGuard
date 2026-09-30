#!/bin/bash
# ========================================================
#  BatteryGuard 一键卸载与设置还原脚本
# ========================================================

set -e

clear
echo ""
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║         🗑️  BatteryGuard 卸载与清理助手        ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo ""

APP_NAME="BatteryGuard"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.batteryguard.app.plist"
CONFIG_DIR="$HOME/Library/Application Support/BatteryGuard"

# 1. 确认卸载
read -p "  是否确定卸载 BatteryGuard 并恢复充电设置为系统默认？[y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ""
    echo "  已取消卸载。"
    exit 0
fi

echo ""
# 2. 是否保留 batt
echo "  关于底层组件 batt (用于 Apple Silicon 充电管理):"
echo "  • 保留 batt: 以后重新安装 BatteryGuard 或其他电池工具无需再次输入管理员密码授权。"
echo "  • 移除 batt: 停止后台服务并卸载该命令行包。"
echo ""
read -p "  是否保留 batt 组件？(默认保留) [Y/n]: " keep_batt
keep_batt=${keep_batt:-Y}

echo ""
echo "  ─── 正在执行还原与卸载 ───"

# 3. 停止运行中的进程
echo "  [1/5] 停止 BatteryGuard 进程..."
pkill -f "$APP_NAME" 2>/dev/null || true
echo "  ✅ 进程已退出"

# 4. 恢复充电上限与电源适配器供电
echo "  [2/5] 恢复 macOS 充电设置为系统默认状态..."
if command -v /opt/homebrew/bin/batt &>/dev/null; then
    /opt/homebrew/bin/batt adapter enable 2>/dev/null || true
    /opt/homebrew/bin/batt limit 100 2>/dev/null || true
    echo "  ✅ 充电限制已还原为 100%（不限制），适配器已正常通电"
elif command -v batt &>/dev/null; then
    batt adapter enable 2>/dev/null || true
    batt limit 100 2>/dev/null || true
    echo "  ✅ 充电限制已还原为 100%（不限制），适配器已正常通电"
else
    echo "  ℹ️ 未检测到 batt，充电状态保持系统当前设置"
fi

# 5. 移除自启动配置
echo "  [3/5] 移除自启动项 (LaunchAgent)..."
if [ -f "$LAUNCH_AGENT" ]; then
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT"
    echo "  ✅ 自启动项已移除"
else
    echo "  ✅ 无残留自启动项"
fi

# 6. 删除应用本体与配置文件
echo "  [4/5] 清除应用程序及用户配置..."
rm -rf "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app" 2>/dev/null || true
rm -rf "$CONFIG_DIR" 2>/dev/null || true
echo "  ✅ 应用与配置已清除"

# 7. 根据选择处理 batt
echo "  [5/5] 处理 batt 核心组件..."
if [[ "$keep_batt" =~ ^[Nn]$ ]]; then
    echo "  正在停止并彻底移除 batt（可能需要输入管理员密码）..."
    sudo brew services stop batt 2>/dev/null || true
    sudo launchctl bootout system/sh.brew.batt 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/sh.brew.batt.plist 2>/dev/null || true
    brew uninstall batt 2>/dev/null || true
    echo "  ✅ batt 服务及软件包已完全移除"
else
    echo "  ✅ 已保留 batt 组件"
fi

echo ""
echo "  ╔═════════════════════════════════════════════════╗"
echo "  ║              ✅ 卸载完全成功！                  ║"
echo "  ║  Mac 电池充电行为已完全恢复为 macOS 原始状态   ║"
echo "  ╚═════════════════════════════════════════════════╝"
echo ""
