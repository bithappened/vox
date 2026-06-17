import Foundation

/// Transcription model options
enum TranscriptionModel: String, CaseIterable {
  case gpt4oTranscribe = "gpt-4o-transcribe"
  case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"
  case whisper1 = "whisper-1"

  var displayName: String {
    switch self {
    case .gpt4oTranscribe: return "GPT-4o Transcribe"
    case .gpt4oMiniTranscribe: return "GPT-4o Mini (Faster)"
    case .whisper1: return "Whisper-1 (Legacy)"
    }
  }

  var description: String {
    switch self {
    case .gpt4oTranscribe: return "Best accuracy, handles noisy audio"
    case .gpt4oMiniTranscribe: return "Faster response, lower cost"
    case .whisper1: return "Original Whisper model"
    }
  }
}

/// Position options for the status window
enum StatusWindowPosition: String, CaseIterable {
  case topRight = "top-right"
  case bottomRight = "bottom-right"
  case topLeft = "top-left"
  case bottomLeft = "bottom-left"
  case centerTop = "center-top"

  var displayName: String {
    switch self {
    case .topRight: return "Top Right"
    case .bottomRight: return "Bottom Right"
    case .topLeft: return "Top Left"
    case .bottomLeft: return "Bottom Left"
    case .centerTop: return "Center Top"
    }
  }
}

/// Manages app settings.
///
/// Non-sensitive preferences live in UserDefaults; the API key lives in the Keychain.
/// Both stores are injectable so tests can run against isolated suites.
final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults: UserDefaults
  private let credentialStore: CredentialStore

  private let languageKey = "vox_language_preference"
  private let positionKey = "vox_status_window_position"
  private let transcriptionModelKey = "vox_transcription_model"
  private let animationStyleKey = "vox_recording_animation_style"

  // Legacy key used by versions prior to Keychain migration.
  private let legacyAPIKeyKey = "vox_api_key"
  private let legacyAnimationSetKey = "vox_animation_set"

  init(
    defaults: UserDefaults = .standard,
    credentialStore: CredentialStore = KeychainCredentialStore()
  ) {
    self.defaults = defaults
    self.credentialStore = credentialStore
    migrateLegacyAPIKeyIfNeeded()
    migrateLegacyAnimationStyleIfNeeded()
  }

  // MARK: - API key

  @discardableResult
  func saveAPIKey(_ key: String) -> Bool {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return credentialStore.save(trimmed)
  }

  func getAPIKey() -> String? {
    guard let key = credentialStore.get() else { return nil }
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func hasAPIKey() -> Bool { getAPIKey() != nil }

  func deleteAPIKey() { credentialStore.delete() }

  /// One-time migration from UserDefaults to Keychain. Safe to call repeatedly.
  private func migrateLegacyAPIKeyIfNeeded() {
    guard let legacy = defaults.string(forKey: legacyAPIKeyKey) else { return }
    let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      defaults.removeObject(forKey: legacyAPIKeyKey)
      return
    }

    if credentialStore.get() != nil || credentialStore.save(trimmed) {
      defaults.removeObject(forKey: legacyAPIKeyKey)
    } else {
      debugLog("Leaving legacy API key in UserDefaults because Keychain migration failed")
    }
  }

  // MARK: - Language

  func saveLanguagePreference(_ language: String) {
    defaults.set(language, forKey: languageKey)
  }

  /// Returns "auto" by default (supports multilingual transcription).
  func getLanguagePreference() -> String {
    defaults.string(forKey: languageKey) ?? "auto"
  }

  // MARK: - Status window position

  func savePosition(_ position: StatusWindowPosition) {
    defaults.set(position.rawValue, forKey: positionKey)
  }

  /// Returns `.topRight` by default (unobtrusive for coding).
  func getPosition() -> StatusWindowPosition {
    guard let raw = defaults.string(forKey: positionKey),
      let position = StatusWindowPosition(rawValue: raw)
    else { return .topRight }
    return position
  }

  // MARK: - Transcription model

  func saveTranscriptionModel(_ model: TranscriptionModel) {
    defaults.set(model.rawValue, forKey: transcriptionModelKey)
  }

  /// Returns `.gpt4oMiniTranscribe` by default (faster for short voice notes).
  func getTranscriptionModel() -> TranscriptionModel {
    guard let raw = defaults.string(forKey: transcriptionModelKey),
      let model = TranscriptionModel(rawValue: raw)
    else { return .gpt4oMiniTranscribe }
    return model
  }

  // MARK: - Recording animation style

  func saveAnimationStyle(_ style: RecordingAnimationStyle) {
    defaults.set(style.rawValue, forKey: animationStyleKey)
  }

  /// Returns `.tinyRobot` (Rover Buddy, the signature look) by default.
  func getAnimationStyle() -> RecordingAnimationStyle {
    guard let raw = defaults.string(forKey: animationStyleKey) else { return .tinyRobot }
    if raw == "edge_aura" { return .voiceWave }  // "Edge Aura" was renamed to "Voice Wave"
    return RecordingAnimationStyle(rawValue: raw) ?? .tinyRobot
  }

  private func migrateLegacyAnimationStyleIfNeeded() {
    guard let legacy = defaults.string(forKey: legacyAnimationSetKey) else { return }

    if defaults.string(forKey: animationStyleKey) == nil {
      // The old visualizer styles were consolidated into Ribbon Wave.
      let migratedStyle: RecordingAnimationStyle?
      switch legacy {
      case "waveform", "bars", "pulse_rings", "ribbon_wave": migratedStyle = .voiceWave
      default: migratedStyle = nil
      }
      if let migratedStyle {
        saveAnimationStyle(migratedStyle)
      }
    }

    defaults.removeObject(forKey: legacyAnimationSetKey)
  }
}
