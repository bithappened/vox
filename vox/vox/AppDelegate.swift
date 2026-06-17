import Carbon.HIToolbox
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var statusWindow: StatusWindowController?
  private var voiceWaveWindow: VoiceWaveWindowController?
  private var settingsWindow: SettingsWindowController?
  private var historyWindow: HistoryWindowController?
  private let audioRecorder = AudioRecorder()
  private let transcriptionService = TranscriptionService()
  private var hotKeyRef: EventHotKeyRef?
  private var escHotKeyRef: EventHotKeyRef?
  private var enterHotKeyRef: EventHotKeyRef?
  private var recordingStartTime: Date?

  // Flip to true to dump every recording to ~/vox_debug_audio/ and emit verbose logs.
  private let debugMode = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    setupMenuBar()
    setupGlobalShortcut()

    statusWindow = StatusWindowController()
    voiceWaveWindow = VoiceWaveWindowController()
    settingsWindow = SettingsWindowController()
    historyWindow = HistoryWindowController()

    audioRecorder.debugMode = debugMode
    audioRecorder.onAudioLevelChange = { [weak self] level in
      self?.statusWindow?.appendSample(level)
      self?.voiceWaveWindow?.update(level: level)
    }

    if !SettingsManager.shared.hasAPIKey() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.showWelcome()
      }
    }
  }

  // MARK: - Menu bar setup

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

    if audioRecorder.isRecording {
      let recordingItem = NSMenuItem(title: "● Recording…", action: nil, keyEquivalent: "")
      recordingItem.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: nil)
      recordingItem.isEnabled = false
      menu.addItem(recordingItem)

      let cancelItem = NSMenuItem(
        title: "Cancel Recording",
        action: #selector(cancelRecording),
        keyEquivalent: "\u{1B}"
      )
      cancelItem.keyEquivalentModifierMask = []
      cancelItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
      menu.addItem(cancelItem)
    } else {
      let recordingItem = NSMenuItem(
        title: "Start Recording",
        action: #selector(toggleRecording),
        keyEquivalent: "r"
      )
      recordingItem.keyEquivalentModifierMask = [.command, .shift]
      recordingItem.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: nil)
      menu.addItem(recordingItem)
    }

    menu.addItem(.separator())

    let recentEntries = TranscriptionHistory.shared.getEntries().prefix(5)
    if !recentEntries.isEmpty {
      menu.addItem(makeSectionHeader("Recent"))

      for entry in recentEntries {
        let item = NSMenuItem(
          title: truncateText(entry.text, maxLength: 44),
          action: #selector(copyRecentTranscription(_:)),
          keyEquivalent: ""
        )
        item.representedObject = entry.text
        item.toolTip = entry.text
        item.image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)
        menu.addItem(item)
      }
      menu.addItem(.separator())
    }

    let historyItem = NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: "h")
    historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
    menu.addItem(historyItem)
    menu.addItem(.separator())

    let positionMenu = NSMenu()
    for position in StatusWindowPosition.allCases {
      let item = NSMenuItem(
        title: position.displayName,
        action: #selector(setPosition(_:)),
        keyEquivalent: ""
      )
      item.representedObject = position
      if position == SettingsManager.shared.getPosition() { item.state = .on }
      item.image = NSImage(systemSymbolName: "rectangle.inset.filled", accessibilityDescription: nil)
      positionMenu.addItem(item)
    }
    let positionItem = NSMenuItem(title: "Status Position", action: nil, keyEquivalent: "")
    positionItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
    positionItem.submenu = positionMenu
    menu.addItem(positionItem)

    let modelMenu = NSMenu()
    for model in TranscriptionModel.allCases {
      let item = NSMenuItem(
        title: model.displayName,
        action: #selector(setTranscriptionModel(_:)),
        keyEquivalent: ""
      )
      item.representedObject = model
      item.toolTip = model.description
      if model == SettingsManager.shared.getTranscriptionModel() { item.state = .on }
      item.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
      modelMenu.addItem(item)
    }
    let modelItem = NSMenuItem(title: "Transcription Model", action: nil, keyEquivalent: "")
    modelItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
    modelItem.submenu = modelMenu
    menu.addItem(modelItem)

    let animationMenu = NSMenu()
    for style in RecordingAnimationStyle.allCases {
      let item = NSMenuItem(
        title: style.displayName,
        action: #selector(setAnimationStyle(_:)),
        keyEquivalent: ""
      )
      item.representedObject = style
      item.toolTip = style.menuDescription
      item.image = imageForAnimationStyle(style)
      if style == SettingsManager.shared.getAnimationStyle() { item.state = .on }
      animationMenu.addItem(item)
    }
    let animationItem = NSMenuItem(title: "Animation Style", action: nil, keyEquivalent: "")
    animationItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
    animationItem.submenu = animationMenu
    menu.addItem(animationItem)

    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
    menu.addItem(settingsItem)

    menu.addItem(.separator())

    let aboutItem = NSMenuItem(title: "About vox", action: #selector(showAbout), keyEquivalent: "")
    aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
    menu.addItem(aboutItem)

    let quitItem = NSMenuItem(title: "Quit vox", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
    menu.addItem(quitItem)

    statusItem?.menu = menu
  }

  /// A styled section header — the native inset header on macOS 14+, a small
  /// secondary-label item as a fallback on older systems.
  private func makeSectionHeader(_ title: String) -> NSMenuItem {
    if #available(macOS 14.0, *) {
      return NSMenuItem.sectionHeader(title: title)
    }
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.secondaryLabelColor,
      ])
    return item
  }

  private func truncateText(_ text: String, maxLength: Int) -> String {
    guard text.count > maxLength else { return text }
    let endIndex = text.index(text.startIndex, offsetBy: maxLength - 1)
    return String(text[..<endIndex]) + "…"
  }

  private func imageForAnimationStyle(_ style: RecordingAnimationStyle) -> NSImage? {
    let symbolName: String
    switch style {
    case .tinyRobot: symbolName = "face.smiling"
    case .voiceWave: symbolName = "water.waves"
    }
    return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
  }

  // MARK: - Global hotkeys

  private func setupGlobalShortcut() {
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

        guard let userData = userData else { return noErr }
        let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

        switch hotKeyID.id {
        case 1:
          DispatchQueue.main.async { appDelegate.toggleRecording() }
        case 2:
          if appDelegate.audioRecorder.isRecording {
            DispatchQueue.main.async { appDelegate.cancelRecording() }
          }
        case 3:
          if appDelegate.audioRecorder.isRecording {
            DispatchQueue.main.async { appDelegate.stopRecordingAndTranscribe() }
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

    var hotKeyID = EventHotKeyID()
    hotKeyID.signature = OSType(0x766F_7878)  // 'voxx'
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

  // MARK: - Recording control

  @objc private func toggleRecording() {
    guard SettingsManager.shared.hasAPIKey() else {
      statusWindow?.showError("Please configure API key in Settings")
      statusWindow?.hide(after: 2.5)
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
    let startTime = Date()
    recordingStartTime = startTime

    showRecordingStatus(startTime: startTime)

    registerRecordingHotKeys()

    audioRecorder.startRecording { [weak self] result in
      switch result {
      case .success:
        self?.showVoiceWave(.listening)
      case .failure(let error):
        self?.cleanupRecording()
        self?.recordingStartTime = nil
        self?.showErrorStatus(error.localizedDescription, hideAfter: 2)
        self?.showVoiceWave(.error, hideAfter: 2)
      }
    }
  }

  @objc private func stopRecordingAndTranscribe() {
    guard audioRecorder.isRecording else { return }
    stopRecording()
    rebuildMenu()
  }

  private func stopRecording() {
    let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) }
    recordingStartTime = nil
    unregisterRecordingHotKeys()

    audioRecorder.stopRecording { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let audioURL):
        self.showVoiceWave(.transcribing)
        self.showTranscribingStatus()
        self.transcribe(audioURL: audioURL, recordingDuration: recordingDuration)
      case .failure(let error):
        self.showVoiceWave(.error, hideAfter: 2)
        self.showErrorStatus(error.localizedDescription, hideAfter: 2)
      }
    }
  }

  @objc private func cancelRecording() {
    recordingStartTime = nil
    cleanupRecording()
    audioRecorder.cancelRecording()
    rebuildMenu()
    statusWindow?.hide()
  }

  private func cleanupRecording() {
    unregisterRecordingHotKeys()
    voiceWaveWindow?.hide()
  }

  private func registerRecordingHotKeys() {
    if escHotKeyRef == nil {
      var escKeyID = EventHotKeyID()
      escKeyID.signature = OSType(0x766F_7865)  // 'voxe'
      escKeyID.id = 2
      RegisterEventHotKey(
        UInt32(kVK_Escape),
        0,
        escKeyID,
        GetApplicationEventTarget(),
        0,
        &escHotKeyRef
      )
    }

    if enterHotKeyRef == nil {
      var enterKeyID = EventHotKeyID()
      enterKeyID.signature = OSType(0x766F_7872)  // 'voxr'
      enterKeyID.id = 3
      RegisterEventHotKey(
        UInt32(kVK_Return),
        0,
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

  private func transcribe(audioURL: URL, recordingDuration: TimeInterval?) {
    let debugURL = debugMode ? saveDebugAudio(from: audioURL) : nil

    transcriptionService.transcribe(audioURL: audioURL) { [weak self] result in
      guard let self = self else { return }

      DispatchQueue.main.async {
        switch result {
        case .success(let text):
          let language = SettingsManager.shared.getLanguagePreference()
          TranscriptionHistory.shared.addEntry(
            text: text,
            language: language,
            duration: recordingDuration
          )

          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(text, forType: .string)

          self.showSuccessStatus("Copied", hideAfter: 1.4)
          self.showVoiceWave(.success, hideAfter: 1.4)
          self.rebuildMenu()

          if self.debugMode {
            debugLog("Transcription: \"\(text)\"")
            if let debugURL = debugURL {
              debugLog("Debug audio saved: \(debugURL.path)")
            }
          }

        case .failure(let error):
          self.showErrorStatus(error.localizedDescription, hideAfter: 2.4)
          self.showVoiceWave(.error, hideAfter: 2.4)
          if self.debugMode {
            debugLog("Transcription error: \(error.localizedDescription)")
            if let debugURL = debugURL {
              debugLog("Debug audio saved: \(debugURL.path)")
            }
          }
        }

        try? FileManager.default.removeItem(at: audioURL)
      }
    }
  }

  /// Saves a copy of the audio file for offline debugging.
  private func saveDebugAudio(from sourceURL: URL) -> URL? {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let debugDir = homeDir.appendingPathComponent("vox_debug_audio")
    try? FileManager.default.createDirectory(at: debugDir, withIntermediateDirectories: true)

    let filename = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
    let destURL = debugDir.appendingPathComponent(filename)

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destURL)
      return destURL
    } catch {
      debugLog("Failed to save debug audio: \(error)")
      return nil
    }
  }

  // MARK: - Menu actions

  @objc private func copyRecentTranscription(_ sender: NSMenuItem) {
    guard let text = sender.representedObject as? String else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)

    showSuccessStatus("Copied", hideAfter: 1)
    showVoiceWave(.success, hideAfter: 1)
  }

  @objc private func setPosition(_ sender: NSMenuItem) {
    guard let position = sender.representedObject as? StatusWindowPosition else { return }
    SettingsManager.shared.savePosition(position)
    rebuildMenu()
  }

  @objc private func setTranscriptionModel(_ sender: NSMenuItem) {
    guard let model = sender.representedObject as? TranscriptionModel else { return }
    SettingsManager.shared.saveTranscriptionModel(model)
    rebuildMenu()
  }

  @objc private func setAnimationStyle(_ sender: NSMenuItem) {
    guard let style = sender.representedObject as? RecordingAnimationStyle else { return }
    SettingsManager.shared.saveAnimationStyle(style)
    statusWindow?.viewModel.animationStyle = style
    if let recordingStartTime {
      if style == .voiceWave {
        statusWindow?.hide()
        showVoiceWave(.listening)
      } else {
        voiceWaveWindow?.hide()
        showRecordingStatus(startTime: recordingStartTime)
      }
    } else if style != .voiceWave {
      voiceWaveWindow?.hide()
    } else {
      statusWindow?.hide()
    }
    rebuildMenu()
  }

  private var isVoiceWaveStyle: Bool {
    SettingsManager.shared.getAnimationStyle() == .voiceWave
  }

  private func showRecordingStatus(startTime: Date) {
    guard !isVoiceWaveStyle else {
      statusWindow?.hide()
      return
    }
    statusWindow?.setCancelHandler { [weak self] in
      self?.cancelRecording()
    }
    statusWindow?.showRecording(startTime: startTime)
  }

  private func showTranscribingStatus() {
    guard !isVoiceWaveStyle else {
      statusWindow?.hide()
      return
    }
    statusWindow?.showTranscribing()
  }

  private func showSuccessStatus(_ message: String, hideAfter delay: TimeInterval) {
    guard !isVoiceWaveStyle else {
      statusWindow?.hide()
      return
    }
    statusWindow?.showSuccess(message)
    statusWindow?.hide(after: delay)
  }

  private func showErrorStatus(_ message: String, hideAfter delay: TimeInterval) {
    guard !isVoiceWaveStyle else {
      statusWindow?.hide()
      return
    }
    statusWindow?.showError(message)
    statusWindow?.hide(after: delay)
  }

  private func showVoiceWave(_ phase: IndicatorPhase, hideAfter delay: TimeInterval? = nil) {
    guard SettingsManager.shared.getAnimationStyle() == .voiceWave else {
      voiceWaveWindow?.hide()
      return
    }
    voiceWaveWindow?.show(phase: phase)
    if let delay {
      voiceWaveWindow?.hide(after: delay)
    }
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
      Powered by OpenAI Whisper API

      Shortcuts:
      Start recording: ⌘⇧R
      Accept (transcribe): Enter
      Cancel: Esc
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
