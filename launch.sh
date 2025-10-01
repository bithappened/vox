#!/bin/bash

# vos Launch Script

echo "🎤 vos - Audio Transcription App"
echo ""

# Build if needed
if [ ! -f "./.build/debug/vos" ]; then
    echo "Building vos..."
    swift build
    echo ""
fi

# Check for required permissions
echo "📋 Pre-flight checks:"
echo "  ✓ Make sure to grant Microphone permission when prompted"
echo "  ✓ For global shortcuts, grant Accessibility permission if needed"
echo ""

echo "🚀 Launching vos..."
echo "  • Click the microphone icon in menu bar for options"
echo "  • Or use Cmd+Shift+R keyboard shortcut to start/stop recording"
echo ""

# Launch the app
./.build/debug/vos
