#!/bin/bash
# ============================================
#  BatteryGuard — 构建 DMG 安装包
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BatteryGuard"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="$PROJECT_DIR/.build-dmg"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 BatteryGuard DMG Builder"
echo "=========================="
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

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

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

# 4. Readme instructions
cat > "$DMG_TEMP/使用说明.txt" << 'README'
BatteryGuard 安装与卸载说明
========================

【安装方法】
1. 将 BatteryGuard 拖拽到右侧 Applications 文件夹。
2. 从启动台或访达的「应用程序」中启动 BatteryGuard。
3. 首次启动根据提示授权即可，菜单栏右上角将出现电池图标。

【卸载方法（两种方式任选）】
• 方式一（推荐）：直接点击菜单栏电池图标，选择「🗑️ 卸载 BatteryGuard...」，按提示操作即可自动恢复全部默认设置并彻底卸载。
• 方式二：双击本 DMG 中的「卸载 BatteryGuard.command」脚本，一键清理并恢复所有状态。
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
