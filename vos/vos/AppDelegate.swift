import Carbon.HIToolbox
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var statusWindow: StatusWindowController?
  private var settingsWindow: SettingsWindowController?
  private let audioRecorder = AudioRecorder()
  private let transcriptionService = TranscriptionService()
  private var hotKeyRef: EventHotKeyRef?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide from Dock
    NSApp.setActivationPolicy(.accessory)

    // Setup menu bar
    setupMenuBar()

    // Setup global shortcut
    setupGlobalShortcut()

    // Setup windows
    statusWindow = StatusWindowController()
    settingsWindow = SettingsWindowController()

    // Show welcome if no API key
    if !SettingsManager.shared.hasAPIKey() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.showWelcome()
      }
    }
  }

  private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "vos")
    }

    // Create menu
    let menu = NSMenu()

    let recordingItem = NSMenuItem(
      title: "Start Recording",
      action: #selector(toggleRecording),
      keyEquivalent: "r"
    )
    recordingItem.keyEquivalentModifierMask = [.command, .shift]
    menu.addItem(recordingItem)

    menu.addItem(NSMenuItem.separator())

    menu.addItem(
      NSMenuItem(
        title: "Settings...",
        action: #selector(openSettings),
        keyEquivalent: ","
      ))

    menu.addItem(NSMenuItem.separator())

    menu.addItem(
      NSMenuItem(
        title: "About vos",
        action: #selector(showAbout),
        keyEquivalent: ""
      ))

    menu.addItem(
      NSMenuItem(
        title: "Quit vos",
        action: #selector(quitApp),
        keyEquivalent: "q"
      ))

    statusItem?.menu = menu
  }

  private func setupGlobalShortcut() {
    // Register Cmd+Shift+R
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x766F_7378)  // 'vosx' in hex
    hotKeyID.id = 1

    var eventType = EventTypeSpec()
    eventType.eventClass = OSType(kEventClassKeyboard)
    eventType.eventKind = OSType(kEventHotKeyPressed)

    InstallEventHandler(
      GetApplicationEventTarget(),
      { (_, _, userData) -> OSStatus in
        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
        appDelegate.toggleRecording()
        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      nil
    )

    RegisterEventHotKey(
      UInt32(kVK_ANSI_R),
      UInt32(cmdKey | shiftKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }

  @objc private func toggleRecording() {
    // Check if API key is configured
    guard SettingsManager.shared.hasAPIKey() else {
      statusWindow?.show(message: "Please configure API key in Settings", state: .error)
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        self.statusWindow?.hide()
      }
      return
    }

    if audioRecorder.isRecording {
      stopRecording()
      updateMenuItemTitle(recording: false)
    } else {
      startRecording()
      updateMenuItemTitle(recording: true)
    }
  }

  @objc private func openSettings() {
    settingsWindow?.show()
  }

  @objc private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "vos"
    alert.informativeText = """
      A simple audio transcription app.

      Version 1.0
      Powered by OpenAI Whisper API (gpt-4o-transcribe)
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  private func showWelcome() {
    let alert = NSAlert()
    alert.messageText = "Welcome to vos!"
    alert.informativeText = """
      To get started, add your OpenAI API key in Settings.

      You can get one from platform.openai.com
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Later")

    if alert.runModal() == .alertFirstButtonReturn {
      openSettings()
    }
  }

  private func updateMenuItemTitle(recording: Bool) {
    if let menu = statusItem?.menu, let recordItem = menu.item(at: 0) {
      recordItem.title = recording ? "Stop Recording" : "Start Recording"
    }
  }

  private func startRecording() {
    statusWindow?.show(message: "Recording...", state: .recording)

    audioRecorder.startRecording { [weak self] result in
      // Recording started successfully or failed
      switch result {
      case .success:
        print("Recording started")
      case .failure(let error):
        DispatchQueue.main.async {
          self?.statusWindow?.show(message: "Error: \(error.localizedDescription)", state: .error)
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self?.statusWindow?.hide()
          }
        }
      }
    }
  }

  private func stopRecording() {
    audioRecorder.stopRecording { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success(let audioURL):
        DispatchQueue.main.async {
          self.statusWindow?.show(message: "Transcribing...", state: .transcribing)
          self.transcribe(audioURL: audioURL)
        }
      case .failure(let error):
        DispatchQueue.main.async {
          self.statusWindow?.show(message: "Error: \(error.localizedDescription)", state: .error)
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusWindow?.hide()
          }
        }
      }
    }
  }

  private func transcribe(audioURL: URL) {
    transcriptionService.transcribe(audioURL: audioURL) { [weak self] result in
      guard let self = self else { return }

      DispatchQueue.main.async {
        switch result {
        case .success(let text):
          // Copy to clipboard
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(text, forType: .string)

          self.statusWindow?.show(message: "Copied!", state: .success)

          // Hide after 1.5 seconds
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.statusWindow?.hide()
          }

        case .failure(let error):
          self.statusWindow?.show(message: "Error: \(error.localizedDescription)", state: .error)
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusWindow?.hide()
          }
        }

        // Clean up audio file
        try? FileManager.default.removeItem(at: audioURL)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Cleanup
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
  }
}
