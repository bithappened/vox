#!/bin/bash

set -e

echo "🔨 Building vox.app..."

# Build in release mode
echo "  → Building release binary..."
swift build -c release

# Create app bundle structure
APP_DIR="vox.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean existing bundle
rm -rf "$APP_DIR"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
echo "  → Copying binary..."
cp .build/release/vox "$MACOS_DIR/vox"

# Copy icon if it exists
if [ -f "resources/AppIcon.icns" ]; then
    echo "  → Copying app icon..."
    cp resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
echo "  → Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>vox</string>
	<key>CFBundleIdentifier</key>
	<string>com.vox.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleName</key>
	<string>vox</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>vox needs microphone access to record audio for transcription.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>vox uses global keyboard shortcuts for quick access.</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2025. All rights reserved.</string>
</dict>
</plist>
EOF

echo ""
echo "✅ vox.app created successfully!"
echo ""
echo "To install:"
echo "  make install"
echo ""
echo "Or manually:"
echo "  cp -r vox.app ~/Applications/"
