# vox

A simple macOS menu bar app for quick audio capture and transcription using OpenAI's Whisper API.

## Features

- **Quick Recording** - Click menu bar icon or use `Cmd+Shift+R` to toggle recording
- **Easy Cancel** - Press `Escape` anytime to cancel recording
- **Quick Accept** - Press `Enter` to stop recording and start transcription
- **AI Transcription** - Powered by OpenAI's `gpt-4o-transcribe` model
- **Auto-Copy** - Transcribed text automatically copied to clipboard
- **Polished UI** - Floating status window with spring-physics animations
- **Simple & Focused** - No bloat, just what you need

## Requirements

- macOS 13.0 or later
- Swift 5.9+
- OpenAI API key (already configured)

## Quick Start

**Easiest way to run:**

```bash
./launch.sh
```

**Or use Make:**

```bash
make run
```

## Building & Running

### Make Commands

```bash
make build   # Build the app
make run     # Build and run the app
make format  # Format Swift code
make lint    # Lint Swift code
make clean   # Clean build artifacts
make help    # Show all commands
```

### Manual Build

```bash
swift build                # Debug build
swift build -c release     # Release build
./.build/debug/vox         # Run debug
```

## Usage

1. **Start vox**: Run the app - a microphone icon will appear in your menu bar
2. **Start Recording**: Click the menu bar icon or press `Cmd+Shift+R`
3. **Stop Recording**: Press `Enter` to accept, or `Cmd+Shift+R` to toggle
4. **Cancel Recording**: Press `Escape` or click the X button to cancel without transcribing
5. **Get Transcription**: The app will automatically transcribe and copy to clipboard
6. **Paste Anywhere**: Use `Cmd+V` to paste the transcribed text

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+R` | Start/stop recording |
| `Enter` | Accept recording and transcribe |
| `Escape` | Cancel recording (only while recording) |
| `Cmd+H` | Open history |
| `Cmd+,` | Open settings |
| `Cmd+Q` | Quit |

All shortcuts use the Carbon Event API for reliable global hotkey registration without requiring accessibility permissions.

## Status Indicators

The floating status window shows:

- **Recording** - Red animated bars react to your voice with spring physics
- **Transcribing** - Blue wave sweep animation
- **Copied!** - Green success indicator
- **Error** - Orange error indicator

## Permissions

vox requires:

- **Microphone Access**: To record audio

Grant this when prompted on first run. No accessibility permissions needed.

## Architecture

```
vox/
├── voxApp.swift              # Main app entry point
├── AppDelegate.swift         # Menu bar & coordination logic
├── Services/
│   ├── AudioRecorder.swift   # Audio recording service
│   └── TranscriptionService.swift  # OpenAI API integration
└── Views/
    └── StatusWindow.swift    # Floating status UI
```

## Development

### Code Quality

The project uses:

- **SwiftLint**: For linting Swift code
- **swift-format**: For consistent code formatting

Install tools:

```bash
brew install swiftlint swift-format
```

### Project Structure

- `/vox` - Main app source code
- `/scratchpad` - Planning docs and notes
- `Package.swift` - Swift package configuration
- `Makefile` - Build and dev commands

## API

Uses OpenAI's Whisper API with the `gpt-4o-transcribe` model for state-of-the-art speech-to-text transcription.

**Endpoint**: `https://api.openai.com/v1/audio/transcriptions`

## License

Private project - all rights reserved.

## Troubleshooting

### No menu bar icon appears

- Ensure the app is running
- Check System Settings > Login Items & Extensions

### Microphone not working

- Grant microphone permission in System Settings > Privacy & Security

### API errors

- Check internet connection
- Verify API key is valid
- Check OpenAI service status

## Credits

Built with:

- Swift & SwiftUI
- AVFoundation for audio recording
- OpenAI Whisper API for transcription
- Carbon Events for global shortcuts
