#!/bin/bash
set -euo pipefail

APP_NAME="BlackScreen"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
BUILD_DIR=".build"
MIN_MACOS="13.0"

# So that Finder > Get Info shows the same version as the git tag
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
VERSION=${VERSION#v}

echo "Building $APP_NAME $VERSION..."

rm -rf "$APP_BUNDLE" "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD_DIR"

# Compile a universal binary (Apple silicon + Intel). An explicit -target is
# required: without it, swiftc targets the build machine's macOS version and
# the app refuses to launch on anything older, regardless of Info.plist.
for arch in arm64 x86_64; do
    swiftc "$APP_NAME.swift" -swift-version 6 \
        -target "$arch-apple-macos$MIN_MACOS" \
        -o "$BUILD_DIR/$APP_NAME-$arch"
done
lipo -create "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64" \
    -output "$MACOS/$APP_NAME"

# Compile the Icon Composer icon. actool ships with Xcode, not the Command Line
# Tools, so fall back to the pre-rendered Icon/AppIcon.icns when it's missing.
# After editing Icon/AppIcon.icon, refresh the fallback with:
#   cp .build/icon/AppIcon.icns Icon/AppIcon.icns
if xcrun --find actool >/dev/null 2>&1; then
    echo "Compiling app icon..."
    mkdir -p "$BUILD_DIR/icon"
    xcrun actool Icon/AppIcon.icon --compile "$BUILD_DIR/icon" \
        --platform macosx --minimum-deployment-target "$MIN_MACOS" \
        --app-icon AppIcon \
        --output-partial-info-plist "$BUILD_DIR/icon/partial.plist" >/dev/null
    cp "$BUILD_DIR/icon/Assets.car" "$BUILD_DIR/icon/AppIcon.icns" "$RESOURCES/"
else
    echo "actool not found (needs Xcode), using pre-rendered icon..."
    cp Icon/AppIcon.icns "$RESOURCES/"
fi

# Write Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BlackScreen</string>
    <key>CFBundleIdentifier</key>
    <string>com.blackscreen.app</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>BlackScreen</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
</dict>
</plist>
EOF

# Ad-hoc code sign so macOS shows "unverified developer" instead of "damaged".
# Without this, Gatekeeper completely blocks unsigned downloaded apps with no
# way to open them from the GUI. Ad-hoc signing (the "-" identity) is free and
# doesn't require an Apple Developer account.
codesign --force --sign - "$APP_BUNDLE"

echo "Done! Built $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To install: cp -r $APP_BUNDLE /Applications/"
