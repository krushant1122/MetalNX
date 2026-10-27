#!/bin/bash
set -e

# MetalNX Control Center Build & Package Script
# Compiles the Swift/SwiftUI Control Center into a native macOS .app bundle and DMG installer.

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/launcher"
APP_NAME="MetalNX.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"
INSTALL_DIR="/Applications/$APP_NAME"
VERSION="2.0.4"

echo "=== Building MetalNX Control Center v$VERSION ==="
mkdir -p "$BUILD_DIR"

echo "-> Generating minimal MetalNX application icon..."
python3 "$DIR/make_icon.py"

echo "-> Compiling nxnative 72-game compatibility & recipe database..."
python3 "$DIR/generate_games_db.py"

echo "-> Compiling Swift binary with optimizations..."
swiftc -parse-as-library -O \
    -target arm64-apple-macos13.0 \
    "$DIR/LauncherApp.swift" \
    -o "$BUILD_DIR/MetalNX"

echo "-> Creating application bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/MetalNX" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/MetalNX"

# Copy installer helper
cp "$DIR/install_nsp.py" "$APP_BUNDLE/Contents/Resources/"
chmod +x "$APP_BUNDLE/Contents/Resources/install_nsp.py"

# Copy application icon
cp "$DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Copy game compatibility and recipes database
cp "$DIR/games_db.json" "$APP_BUNDLE/Contents/Resources/games_db.json"

# Bundle engine scripts so the app always carries the latest build pipeline
echo "-> Bundling latest engine scripts..."
mkdir -p "$APP_BUNDLE/Contents/Resources/scripts"
cp -R "$REPO_ROOT/scripts/"* "$APP_BUNDLE/Contents/Resources/scripts/"

# Bundle self-contained nx_extract if built (zero .NET runtime required by user)
if [ -f "$REPO_ROOT/tools/bin/nx_extract" ]; then
    echo "-> Bundling self-contained nx_extract (zero .NET required by user)..."
    cp "$REPO_ROOT/tools/bin/nx_extract" "$APP_BUNDLE/Contents/Resources/nx_extract"
    chmod +x "$APP_BUNDLE/Contents/Resources/nx_extract"
fi

# Write Info.plist
cat << EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>MetalNX</string>
    <key>CFBundleExecutable</key>
    <string>MetalNX</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>org.nxnative.metalnx</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MetalNX</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "-> Code signing bundle (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✓ Build complete: $APP_BUNDLE"

# Build DMG Installer
DMG_PATH="$BUILD_DIR/MetalNX-$VERSION.dmg"
echo "-> Creating macOS Drag-and-Drop DMG Installer: $DMG_PATH..."
DMG_STAGE="$BUILD_DIR/dmg_stage"
rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "MetalNX" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH" -quiet
rm -rf "$DMG_STAGE"
echo "✓ DMG Installer ready: $DMG_PATH"

if [ "$1" == "--install" ] || [ "$1" == "-i" ] || [ "$2" == "--install" ] || [ "$2" == "-i" ]; then
    echo "-> Installing MetalNX to /Applications..."
    # Clean up legacy launcher if present
    rm -rf "/Applications/Nintendo Silicon Launcher.app"
    rm -rf "$INSTALL_DIR"
    cp -R "$APP_BUNDLE" "/Applications/"
    touch "$INSTALL_DIR"
    echo "✓ Successfully installed to $INSTALL_DIR"
fi
