#!/bin/bash
# ============================================
#  BatteryGuard — 构建 DMG 安装包 (v1.1.1)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BatteryGuard"
VERSION="1.1.1"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="$PROJECT_DIR/.build-dmg"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 BatteryGuard DMG Builder (v${VERSION})"
echo "=========================================="
echo ""

# ─── Clean ───
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── Build Release Binary ───
echo "📦 编译 Release 版本..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -3
BINARY="$PROJECT_DIR/.build/release/$APP_NAME"
echo "   ✅ 编译完成 ($(du -h "$BINARY" | cut -f1 | xargs))"

# ─── Create App Bundle ───
echo "📁 创建 App Bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Helpers"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy bundled helper binary (Zero Homebrew dependency)
BATT_SRC="$PROJECT_DIR/Assets/bin/batt"
if [ -f "$BATT_SRC" ]; then
    echo "   📦 嵌入内置充电守护核心组件及开源许可..."
    cp "$BATT_SRC" "$APP_BUNDLE/Contents/Resources/batt"
    cp "$BATT_SRC" "$APP_BUNDLE/Contents/Helpers/batt"
    chmod 755 "$APP_BUNDLE/Contents/Resources/batt"
    chmod 755 "$APP_BUNDLE/Contents/Helpers/batt"
    if [ -f "$PROJECT_DIR/Assets/bin/LICENSE_batt.txt" ]; then
        cp "$PROJECT_DIR/Assets/bin/LICENSE_batt.txt" "$APP_BUNDLE/Contents/Resources/LICENSE_batt.txt"
    fi
else
    echo "   ⚠️ 未找到 Assets/bin/batt，跳过内置"
fi

# Copy icon
ICON_FILE="$PROJECT_DIR/Assets/AppIcon.icns"
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    ICON_ENTRY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
else
    ICON_ENTRY=""
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.batteryguard.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
${ICON_ENTRY}
</dict>
</plist>
PLIST

echo "   ✅ App Bundle 创建完成"

# ─── Create DMG Staging Area ───
echo "💿 准备 DMG 内容..."

DMG_TEMP="$BUILD_DIR/dmg-temp"
mkdir -p "$DMG_TEMP"

# 1. App Bundle
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# 2. Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# 3. Uninstaller command inside DMG
cp "$PROJECT_DIR/scripts/uninstall.sh" "$DMG_TEMP/卸载 BatteryGuard.command"
chmod +x "$DMG_TEMP/卸载 BatteryGuard.command"

# 4. Licenses
cp "$PROJECT_DIR/LICENSE" "$DMG_TEMP/LICENSE.txt"
if [ -f "$PROJECT_DIR/Assets/bin/LICENSE_batt.txt" ]; then
    cp "$PROJECT_DIR/Assets/bin/LICENSE_batt.txt" "$DMG_TEMP/LICENSE_batt.txt"
fi

# 5. Bilingual Readme instructions
cat > "$DMG_TEMP/Instructions & 说明.txt" << 'README'
BatteryGuard (v1.1.1)
=====================

【English】
1. Drag BatteryGuard to the Applications folder.
2. Launch BatteryGuard from Applications.
3. On first launch, enter your Mac administrator password once to authorize the background service.
4. The battery icon will appear on your menu bar!

* Uninstall: Click the menu bar icon -> "🗑️ 卸载 BatteryGuard..." to cleanly restore all default settings. Or double-click "卸载 BatteryGuard.command".
* Open Source: BatteryGuard is MIT-licensed. Built-in daemon batt is licensed under GPL-2.0 by charlie0129 (see LICENSE_batt.txt).

【中文说明】
1. 将左侧 BatteryGuard 拖拽到右侧 Applications 文件夹。
2. 从启动台或「应用程序」中启动 BatteryGuard。
3. 首次启动根据提示输入一次 Mac 密码授权后台服务即可，菜单栏右上角将出现电池图标。

* 卸载：直接点击菜单栏图标选择「🗑️ 卸载 BatteryGuard...」自动恢复系统默认充电设置；或双击本 DMG 中的「卸载 BatteryGuard.command」。
* 开源合规：BatteryGuard 基于 MIT 协议开源；内置底层组件 batt 基于 GPL-2.0 协议开源（作者 charlie0129），详见 DMG 内 LICENSE.txt 及 LICENSE_batt.txt。
README

# ─── Package into DMG ───
DMG_OUTPUT="$PROJECT_DIR/${DMG_NAME}.dmg"
rm -f "$DMG_OUTPUT"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT" 2>/dev/null

echo "   ✅ DMG 打包完成"

# ─── Clean up temporary build artifacts ───
rm -rf "$BUILD_DIR"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║         ✅ 构建与打包完成！          ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  📦 输出位置: $DMG_OUTPUT"
echo "  📏 文件大小: $(du -h "$DMG_OUTPUT" | cut -f1 | xargs)"
echo ""
