#!/bin/bash

set -e

echo "🔨 Building vos.app..."

# Build in release mode
echo "  → Building release binary..."
swift build -c release

# Create app bundle structure
APP_DIR="vos.app"
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
cp .build/release/vos "$MACOS_DIR/vos"

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
	<string>vos</string>
	<key>CFBundleIdentifier</key>
	<string>com.vos.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>vos</string>
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
	<string>vos needs microphone access to record audio for transcription.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>vos uses global keyboard shortcuts for quick access.</string>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2025. All rights reserved.</string>
</dict>
</plist>
EOF

echo ""
echo "✅ vos.app created successfully!"
echo ""
echo "To install:"
echo "  make install"
echo ""
echo "Or manually:"
echo "  cp -r vos.app ~/Applications/"
