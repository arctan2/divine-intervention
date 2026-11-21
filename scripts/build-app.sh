#!/bin/bash
# Builds DivineIntervention.app in ./build
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal binary (Apple Silicon + Intel) without needing full Xcode
swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0
mkdir -p build
BIN=build/DivineIntervention-universal
lipo -create -output "$BIN" \
  .build/arm64-apple-macosx/release/DivineIntervention \
  .build/x86_64-apple-macosx/release/DivineIntervention

APP=build/DivineIntervention.app
rm -rf "$APP" build/DivineIntervention.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DivineIntervention"
cp Resources/jesus.png "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Divine Intervention</string>
    <key>CFBundleDisplayName</key><string>Divine Intervention</string>
    <key>CFBundleIdentifier</key><string>local.divine-intervention</string>
    <key>CFBundleExecutable</key><string>DivineIntervention</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

# Zip for distribution (ditto keeps the bundle structure + signature intact)
ditto -c -k --keepParent "$APP" build/DivineIntervention.zip
echo "Zipped build/DivineIntervention.zip"
