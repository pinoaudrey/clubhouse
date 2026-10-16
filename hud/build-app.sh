#!/bin/bash
# Build Clubhouse into a double-clickable .app bundle.
#
#   ./build-app.sh            build ./Clubhouse.app
#   ./build-app.sh --install  build it and copy it into /Applications, or into
#                             ~/Applications when this account cannot write there
#
# It's a normal menu-bar app: double-click it, or add it to
# System Settings > General > Login Items to start at login. It launches the
# Python snapshot daemon itself. The daemon lives in this repo (main.py, standard
# library only); the app finds it either relative to its own location or via the
# AHDaemonRoot path baked in below, so it keeps working even from /Applications
# as long as this repo checkout stays put.
set -euo pipefail

cd "$(dirname "$0")"
APP="Clubhouse.app"
CONTENTS="$APP/Contents"
REPO_ROOT="$(cd .. && pwd)"   # holds main.py (the daemon)

echo "Building release binary..."
swift build -c release

echo "Assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp ".build/release/agenthud-hud" "$CONTENTS/MacOS/agenthud-hud"
cp "assets/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

# Unquoted heredoc so ${REPO_ROOT} expands into AHDaemonRoot.
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Clubhouse</string>
    <key>CFBundleDisplayName</key><string>Clubhouse</string>
    <key>CFBundleIdentifier</key><string>com.agenthud.hud</string>
    <key>CFBundleExecutable</key><string>agenthud-hud</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Menu-bar-only: no Dock icon, no app menu. -->
    <key>LSUIElement</key><true/>
    <!-- Shown in the one-time Automation prompt the first time a NEEDS YOU
         row brings a Terminal tab forward. Without it macOS refuses the
         Apple Event and never asks. -->
    <key>NSAppleEventsUsageDescription</key><string>Clubhouse selects the Terminal tab of the session you click.</string>
    <!-- Where the Python daemon (main.py) lives, so the app can start
         it even when installed outside the repo (e.g. /Applications). -->
    <key>AHDaemonRoot</key><string>${REPO_ROOT}</string>
</dict>
</plist>
PLIST

# Adding or removing an app in /Applications needs an admin account. Checking
# first matters: rm -rf on a bundle you own empties it before it fails to
# remove the folder, and leaves a broken app behind.
if [ "${1:-}" = "--install" ]; then
    if [ -w /Applications ]; then
        DEST="/Applications"
    else
        DEST="$HOME/Applications"
        mkdir -p "$DEST"
    fi
    echo "Installing to $DEST..."
    rm -rf "$DEST/$APP"
    cp -R "$APP" "$DEST/$APP"
    touch "$DEST/$APP"   # nudge Finder/Dock to pick up the icon
    echo "Installed: $DEST/$APP"
    if [ "$DEST" != /Applications ] && [ -e "/Applications/$APP" ]; then
        echo "An older /Applications/$APP is still there. An admin must delete it."
    fi
    echo "Open it from Spotlight (\"Clubhouse\")."
    echo "To start at login: System Settings > General > Login Items > +."
else
    echo "Built: $(pwd)/$APP"
    echo "Install it with:  ./build-app.sh --install   (copies to /Applications or ~/Applications)"
fi
