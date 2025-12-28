import Carbon.HIToolbox
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var statusWindow: StatusWindowController?
  private var settingsWindow: SettingsWindowController?
  private var historyWindow: HistoryWindowController?
  private let audioRecorder = AudioRecorder()
  private let transcriptionService = TranscriptionService()
  private var hotKeyRef: EventHotKeyRef?
  private var escHotKeyRef: EventHotKeyRef?
  private var enterHotKeyRef: EventHotKeyRef?

  // Recording state
  private var recordingStartTime: Date?
  private var durationTimer: Timer?
  private var currentAudioLevel: Float = 0.0

  // Debug mode flag - set to true to enable audio file saving and verbose logging
  private let debugMode = true

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
    historyWindow = HistoryWindowController()

    // Configure audio recorder
    audioRecorder.debugMode = debugMode
    audioRecorder.onAudioLevelChange = { [weak self] level in
      self?.currentAudioLevel = level
    }

    // Show welcome if no API key
    if !SettingsManager.shared.hasAPIKey() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.showWelcome()
      }
    }
  }

  // MARK: - Menu Bar Setup

  private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "vox")
    }

    rebuildMenu()
  }

  private func rebuildMenu() {
    let menu = NSMenu()
    menu.delegate = self

    // Recording control
    if audioRecorder.isRecording {
      let recordingItem = NSMenuItem(title: "● Recording...", action: nil, keyEquivalent: "")
      recordingItem.isEnabled = false
      menu.addItem(recordingItem)

      let cancelItem = NSMenuItem(
        title: "Cancel Recording",
        action: #selector(cancelRecording),
        keyEquivalent: "\u{1B}"  // ESC
      )
      cancelItem.keyEquivalentModifierMask = []
      menu.addItem(cancelItem)
    } else {
      let recordingItem = NSMenuItem(
        title: "Start Recording",
        action: #selector(toggleRecording),
        keyEquivalent: "r"
      )
      recordingItem.keyEquivalentModifierMask = [.command, .shift]
      menu.addItem(recordingItem)
    }

    menu.addItem(NSMenuItem.separator())

    // Recent transcriptions
    let recentEntries = TranscriptionHistory.shared.getEntries().prefix(5)
    if !recentEntries.isEmpty {
      let recentHeader = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
      recentHeader.isEnabled = false
      menu.addItem(recentHeader)

      for entry in recentEntries {
        let truncatedText = truncateText(entry.text, maxLength: 40)
        let item = NSMenuItem(
          title: "  \(truncatedText)",
          action: #selector(copyRecentTranscription(_:)),
          keyEquivalent: ""
        )
        item.representedObject = entry.text
        item.toolTip = entry.text
        menu.addItem(item)
      }

      menu.addItem(NSMenuItem.separator())
    }

    // History
    menu.addItem(
      NSMenuItem(
        title: "History...",
        action: #selector(openHistory),
        keyEquivalent: "h"
      ))

    menu.addItem(NSMenuItem.separator())

    // Position submenu
    let positionMenu = NSMenu()
    for position in StatusWindowPosition.allCases {
      let item = NSMenuItem(
        title: position.displayName,
        action: #selector(setPosition(_:)),
        keyEquivalent: ""
      )
      item.representedObject = position
      if position == SettingsManager.shared.getPosition() {
        item.state = .on
      }
      positionMenu.addItem(item)
    }
    let positionItem = NSMenuItem(title: "Status Position", action: nil, keyEquivalent: "")
    positionItem.submenu = positionMenu
    menu.addItem(positionItem)

    // Animation Style submenu
    let animationMenu = NSMenu()
    for animationType in AnimationSetType.allCases {
      let item = NSMenuItem(
        title: animationType.displayName,
        action: #selector(setAnimationStyle(_:)),
        keyEquivalent: ""
      )
      item.representedObject = animationType
      if animationType == SettingsManager.shared.getAnimationSet() {
        item.state = .on
      }
      animationMenu.addItem(item)
    }
    let animationItem = NSMenuItem(title: "Animation Style", action: nil, keyEquivalent: "")
    animationItem.submenu = animationMenu
    menu.addItem(animationItem)

    // Transcription Model submenu
    let modelMenu = NSMenu()
    for model in TranscriptionModel.allCases {
      let item = NSMenuItem(
        title: model.displayName,
        action: #selector(setTranscriptionModel(_:)),
        keyEquivalent: ""
      )
      item.representedObject = model
      item.toolTip = model.description
      if model == SettingsManager.shared.getTranscriptionModel() {
        item.state = .on
      }
      modelMenu.addItem(item)
    }
    let modelItem = NSMenuItem(title: "Transcription Model", action: nil, keyEquivalent: "")
    modelItem.submenu = modelMenu
    menu.addItem(modelItem)

    // Settings
    menu.addItem(
      NSMenuItem(
        title: "Settings...",
        action: #selector(openSettings),
        keyEquivalent: ","
      ))

    menu.addItem(NSMenuItem.separator())

    // About & Quit
    menu.addItem(
      NSMenuItem(
        title: "About vox",
        action: #selector(showAbout),
        keyEquivalent: ""
      ))

    menu.addItem(
      NSMenuItem(
        title: "Quit vox",
        action: #selector(quitApp),
        keyEquivalent: "q"
      ))

    statusItem?.menu = menu
  }

  private func truncateText(_ text: String, maxLength: Int) -> String {
    if text.count <= maxLength {
      return text
    }
    let endIndex = text.index(text.startIndex, offsetBy: maxLength - 1)
    return String(text[..<endIndex]) + "…"
  }

  // MARK: - Global Shortcut

  private func setupGlobalShortcut() {
    // Install single event handler for all hotkeys
    var eventType = EventTypeSpec()
    eventType.eventClass = OSType(kEventClassKeyboard)
    eventType.eventKind = OSType(kEventHotKeyPressed)

    InstallEventHandler(
      GetApplicationEventTarget(),
      { (_, event, userData) -> OSStatus in
        var hotKeyID = EventHotKeyID()
        GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )

        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()

        switch hotKeyID.id {
        case 1:  // Cmd+Shift+R - toggle recording
          DispatchQueue.main.async {
            appDelegate.toggleRecording()
          }
        case 2:  // ESC - cancel recording
          if appDelegate.audioRecorder.isRecording {
            DispatchQueue.main.async {
              appDelegate.cancelRecording()
            }
          }
        case 3:  // Enter - stop recording and transcribe
          if appDelegate.audioRecorder.isRecording {
            DispatchQueue.main.async {
              appDelegate.stopRecordingAndTranscribe()
            }
          }
        default:
          break
        }
        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      nil
    )

    // Register Cmd+Shift+R hotkey
    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x766F_7378)  // 'vosx' in hex
    hotKeyID.id = 1

    RegisterEventHotKey(
      UInt32(kVK_ANSI_R),
      UInt32(cmdKey | shiftKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }

  // MARK: - Recording Control

  @objc private func toggleRecording() {
    // Check if API key is configured
    guard SettingsManager.shared.hasAPIKey() else {
      statusWindow?.show(state: .error("Please configure API key in Settings"))
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        self.statusWindow?.hide()
      }
      return
    }

    if audioRecorder.isRecording {
      stopRecording()
    } else {
      startRecording()
    }
    rebuildMenu()
  }

  private func startRecording() {
    recordingStartTime = Date()
    currentAudioLevel = 0.0

    // Show status window with cancel handler
    statusWindow?.setCancelHandler { [weak self] in
      self?.cancelRecording()
    }
    statusWindow?.show(state: .recording, audioLevel: 0, duration: 0)

    // Start duration timer
    durationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.updateRecordingStatus()
    }

    // Register recording hotkeys (ESC to cancel, Enter to accept)
    registerRecordingHotKeys()

    audioRecorder.startRecording { [weak self] result in
      switch result {
      case .success:
        print("Recording started")
      case .failure(let error):
        DispatchQueue.main.async {
          self?.cleanupRecording()
          self?.statusWindow?.show(state: .error(error.localizedDescription))
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self?.statusWindow?.hide()
          }
        }
      }
    }
  }

  private func updateRecordingStatus() {
    guard let startTime = recordingStartTime else { return }
    let duration = Date().timeIntervalSince(startTime)
    statusWindow?.updateRecording(audioLevel: currentAudioLevel, duration: duration)
  }

  @objc private func stopRecordingAndTranscribe() {
    guard audioRecorder.isRecording else { return }
    stopRecording()
    rebuildMenu()
  }

  private func stopRecording() {
    cleanupRecording()

    audioRecorder.stopRecording { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success(let audioURL):
        DispatchQueue.main.async {
          self.statusWindow?.show(state: .transcribing)
          self.transcribe(audioURL: audioURL)
        }
      case .failure(let error):
        DispatchQueue.main.async {
          self.statusWindow?.show(state: .error(error.localizedDescription))
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusWindow?.hide()
          }
        }
      }
    }
  }

  @objc private func cancelRecording() {
    print("🚫 Recording cancelled by user")
    cleanupRecording()
    audioRecorder.cancelRecording()
    rebuildMenu()

    DispatchQueue.main.async { [weak self] in
      self?.statusWindow?.show(state: .error("Cancelled"))
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self?.statusWindow?.hide()
      }
    }
  }

  private func cleanupRecording() {
    durationTimer?.invalidate()
    durationTimer = nil
    recordingStartTime = nil
    unregisterRecordingHotKeys()
  }

  private func registerRecordingHotKeys() {
    // Register ESC to cancel recording
    if escHotKeyRef == nil {
      var escKeyID = EventHotKeyID()
      escKeyID.signature = OSType(0x766F_7365)  // 'vose' in hex (vox escape)
      escKeyID.id = 2

      RegisterEventHotKey(
        UInt32(kVK_Escape),
        0,  // No modifiers
        escKeyID,
        GetApplicationEventTarget(),
        0,
        &escHotKeyRef
      )
    }

    // Register Enter to accept recording
    if enterHotKeyRef == nil {
      var enterKeyID = EventHotKeyID()
      enterKeyID.signature = OSType(0x766F_7372)  // 'vosr' in hex (vox return)
      enterKeyID.id = 3

      RegisterEventHotKey(
        UInt32(kVK_Return),
        0,  // No modifiers
        enterKeyID,
        GetApplicationEventTarget(),
        0,
        &enterHotKeyRef
      )
    }
  }

  private func unregisterRecordingHotKeys() {
    if let ref = escHotKeyRef {
      UnregisterEventHotKey(ref)
      escHotKeyRef = nil
    }
    if let ref = enterHotKeyRef {
      UnregisterEventHotKey(ref)
      enterHotKeyRef = nil
    }
  }

  // MARK: - Transcription

  private func transcribe(audioURL: URL) {
    // Save audio file to debug location if debug mode is enabled
    let debugURL = debugMode ? saveDebugAudio(from: audioURL) : nil

    transcriptionService.transcribe(audioURL: audioURL) { [weak self] result in
      guard let self = self else { return }

      DispatchQueue.main.async {
        switch result {
        case .success(let text):
          // Save to history
          TranscriptionHistory.shared.addEntry(text: text, language: "en")

          // Copy to clipboard
          let pasteboard = NSPasteboard.general
          pasteboard.clearContents()
          pasteboard.setString(text, forType: .string)

          self.statusWindow?.show(state: .success("Copied!"))

          // Log the result
          print("📝 Transcription: \"\(text)\"")
          if self.debugMode, let debugURL = debugURL {
            print("🎵 Debug audio saved: \(debugURL.path)")
          }

          // Hide after 1.5 seconds and rebuild menu
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.statusWindow?.hide()
            self.rebuildMenu()
          }

        case .failure(let error):
          self.statusWindow?.show(state: .error(error.localizedDescription))
          print("❌ Transcription error: \(error.localizedDescription)")
          if self.debugMode, let debugURL = debugURL {
            print("🎵 Debug audio saved: \(debugURL.path)")
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.statusWindow?.hide()
          }
        }

        // Clean up temporary audio file
        try? FileManager.default.removeItem(at: audioURL)
      }
    }
  }

  /// Saves a copy of the audio file for debugging purposes
  private func saveDebugAudio(from sourceURL: URL) -> URL? {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let debugDir = homeDir.appendingPathComponent("vox_debug_audio")

    // Create debug directory if it doesn't exist
    try? FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

    // Create filename with timestamp
    let timestamp = Date().timeIntervalSince1970
    let filename = "recording_\(Int(timestamp)).m4a"
    let destURL = debugDir.appendingPathComponent(filename)

    // Copy the file
    do {
      try FileManager.default.copyItem(at: sourceURL, to: destURL)
      print("💾 Debug audio saved to: \(destURL.path)")

      // Get file size for debugging
      if let attributes = try? FileManager.default.attributesOfItem(atPath: destURL.path),
        let fileSize = attributes[.size] as? Int64 {
        print("📊 Audio file size: \(fileSize) bytes (\(Double(fileSize) / 1024.0) KB)")
      }

      return destURL
    } catch {
      print("⚠️  Failed to save debug audio: \(error)")
      return nil
    }
  }

  // MARK: - Menu Actions

  @objc private func copyRecentTranscription(_ sender: NSMenuItem) {
    guard let text = sender.representedObject as? String else { return }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    // Brief visual feedback
    statusWindow?.show(state: .success("Copied!"))
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      self.statusWindow?.hide()
    }
  }

  @objc private func setPosition(_ sender: NSMenuItem) {
    guard let position = sender.representedObject as? StatusWindowPosition else { return }
    SettingsManager.shared.savePosition(position)
    rebuildMenu()
  }

  @objc private func setAnimationStyle(_ sender: NSMenuItem) {
    guard let animationType = sender.representedObject as? AnimationSetType else { return }
    SettingsManager.shared.saveAnimationSet(animationType)
    rebuildMenu()
  }

  @objc private func setTranscriptionModel(_ sender: NSMenuItem) {
    guard let model = sender.representedObject as? TranscriptionModel else { return }
    SettingsManager.shared.saveTranscriptionModel(model)
    rebuildMenu()
  }

  @objc private func openSettings() {
    settingsWindow?.show()
  }

  @objc private func openHistory() {
    historyWindow?.show()
  }

  @objc private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "vox"
    alert.informativeText = """
      A simple audio transcription app.

      Version 1.0
      Powered by OpenAI Whisper API (gpt-4o-transcribe)

      Shortcuts:
      Start recording: ⌘⇧R
      Accept (transcribe): Enter
      Cancel: ESC
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
    alert.messageText = "Welcome to vox!"
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

  // MARK: - Cleanup

  func applicationWillTerminate(_ notification: Notification) {
    // Cleanup hotkeys
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    unregisterRecordingHotKeys()
    cleanupRecording()
  }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    rebuildMenu()
  }
}
