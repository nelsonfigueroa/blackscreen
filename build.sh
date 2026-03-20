#!/bin/bash
set -e

APP_NAME="BlackScreen"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME..."

# Create app bundle structure
mkdir -p "$MACOS" "$RESOURCES"

# Compile
swiftc "$APP_NAME.swift" -o "$MACOS/$APP_NAME" -framework AppKit -framework CoreGraphics

# Generate icon
echo "Generating app icon..."
swift generate-icon.swift
cp AppIcon.icns "$RESOURCES/AppIcon.icns"
rm -f AppIcon.icns

# Write Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BlackScreen</string>
    <key>CFBundleIdentifier</key>
    <string>com.displaytoggle.app</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>BlackScreen</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

echo "Done! Built $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To install: cp -r $APP_BUNDLE /Applications/"
