# vox

A focused macOS menu-bar app for quick voice capture and transcription, powered by OpenAI.

## Features

- **One-tap recording** — click the menu-bar icon or press `⌘⇧R`
- **Live waveform** — the floating status pill renders your real audio level, not a fake animation
- **Quick accept / cancel** — `Enter` to transcribe, `Esc` to cancel
- **Auto-copy** — transcribed text lands in your clipboard
- **Keychain-backed API key** — credentials never touch UserDefaults
- **Configurable model** — `gpt-4o-transcribe`, `gpt-4o-mini-transcribe` (default), or `whisper-1`
- **Auto-detect language** by default, with manual override for ten common languages

## Requirements

- macOS 13.0 or later
- Swift 5.9+
- An OpenAI API key (`sk-…`) — get one at <https://platform.openai.com/api-keys>

## Quick start

```bash
./launch.sh
```

Or:

```bash
make run
```

On first launch, paste your API key in **Settings**.

## Build & install

```bash
make build        # debug build
make build-app    # produce vox.app bundle
make install      # copy vox.app to ~/Applications
make uninstall    # remove vox.app
make clean        # clean build artifacts
make help         # all commands
```

## Usage

1. Launch vox — a microphone icon appears in the menu bar.
2. Press `⌘⇧R` (or click the icon → Start Recording).
3. Speak. The status pill shows a live waveform of your audio.
4. Press `Enter` to accept and transcribe, or `Esc` to cancel.
5. The transcribed text is copied to your clipboard. Paste with `⌘V`.

## Keyboard shortcuts

| Shortcut  | Action                          |
|-----------|---------------------------------|
| `⌘⇧R`    | Start / stop recording          |
| `Enter`   | Accept and transcribe           |
| `Esc`     | Cancel recording                |
| `⌘H`     | Open history                    |
| `⌘,`     | Open settings                   |
| `⌘Q`     | Quit                            |

Hotkeys use the Carbon Event API and do **not** require accessibility permission.

## Settings

Open with `⌘,` from the menu. You can configure:

- **API Key** (stored in Keychain, with a button to clear it)
- **Transcription Model** — accuracy/speed tradeoff
- **Language** — auto-detect or one of ten languages
- **Status Position** — where the floating pill appears (top-right by default)

## Permissions

vox requires **Microphone Access**, prompted on first record. No accessibility permission is needed.

## Architecture

```
vox/
├── voxApp.swift                  # Entry point
├── AppDelegate.swift             # Menu bar, hotkeys, recording flow
├── Services/
│   ├── AudioRecorder.swift       # AVAudioRecorder wrapper + level metering
│   ├── TranscriptionService.swift# OpenAI API client
│   ├── TranscriptionHistory.swift# Persistent history (UserDefaults)
│   ├── SettingsManager.swift     # User preferences (UserDefaults + Keychain)
│   ├── CredentialStore.swift     # Keychain abstraction (testable)
│   └── Logger.swift              # debugLog helper (no-op in release)
└── Views/
    ├── StatusWindow.swift        # Floating status pill controller
    ├── StatusIndicators.swift    # Waveform / shimmer / success / error views
    ├── SettingsWindow.swift      # Settings panel
    └── HistoryWindow.swift       # Transcription history browser
```

## Development

### Code quality

- **SwiftLint** for linting
- **swift-format** for formatting

```bash
brew install swiftlint swift-format

make lint
make format
make check         # lint + format-check
```

### Tests

Unit tests live in `vox/voxTests/` and use isolated UserDefaults suites + an in-memory credential store, so running them never touches your real settings.

> Note: `swift test` from the SwiftPM CLI is currently broken under Swift 6.3 because of an XCTest module-resolution issue specific to executable targets. Run tests through Xcode instead.

## API

vox calls `POST https://api.openai.com/v1/audio/transcriptions` with the configured model. Default is `gpt-4o-mini-transcribe` (faster and cheaper for short voice notes).

## Troubleshooting

**No menu-bar icon appears** — make sure the app is running. Check System Settings → Login Items & Extensions.

**Microphone not working** — grant permission in System Settings → Privacy & Security → Microphone.

**API errors** — verify your key is valid and you have an active billing setup at OpenAI.

## License

Private project — all rights reserved.

## Credits

- Swift & SwiftUI
- AVFoundation for audio capture
- Carbon Events for global hotkeys
- OpenAI Whisper API for transcription
