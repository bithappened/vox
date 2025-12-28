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

/// Manages app settings using UserDefaults
///
/// Uses UserDefaults for API key storage, which is the standard approach for Mac apps
/// (similar to Slack, Discord, VSCode, etc.). Automatically trims whitespace and newlines
/// to prevent corruption issues.
final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard
  private let apiKeyKey = "vox_api_key"
  private let languageKey = "vox_language_preference"
  private let positionKey = "vox_status_window_position"
  private let animationSetKey = "vox_animation_set"
  private let transcriptionModelKey = "vox_transcription_model"

  private init() {}

  /// Save API key with automatic trimming
  /// Returns true if saved successfully
  func saveAPIKey(_ key: String) -> Bool {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      print("⚠️  Cannot save empty API key")
      return false
    }

    defaults.set(trimmed, forKey: apiKeyKey)
    defaults.synchronize()  // Force immediate write

    print("💾 API key saved (length: \(trimmed.count))")
    return true
  }

  /// Get API key with automatic trimming
  /// Returns nil if no key is stored
  func getAPIKey() -> String? {
    guard let key = defaults.string(forKey: apiKeyKey) else {
      print("🔑 No API key configured")
      return nil
    }

    // Double-trim for safety (handles any edge cases)
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      print("🔑 API key is empty after trimming")
      return nil
    }

    print("🔑 API key retrieved (length: \(trimmed.count))")
    return trimmed
  }

  /// Check if an API key is configured
  func hasAPIKey() -> Bool {
    return getAPIKey() != nil
  }

  /// Delete stored API key
  func deleteAPIKey() {
    defaults.removeObject(forKey: apiKeyKey)
    defaults.synchronize()
    print("🗑️  API key deleted")
  }

  /// Save language preference
  /// - Parameter language: Language code ("auto" for auto-detect, "en" for English, "es" for Spanish, etc.)
  func saveLanguagePreference(_ language: String) {
    defaults.set(language, forKey: languageKey)
    defaults.synchronize()
    print("🌐 Language preference saved: \(language)")
  }

  /// Get language preference
  /// Returns "auto" by default to support multilingual transcription
  func getLanguagePreference() -> String {
    return defaults.string(forKey: languageKey) ?? "auto"
  }

  /// Save status window position
  func savePosition(_ position: StatusWindowPosition) {
    defaults.set(position.rawValue, forKey: positionKey)
    defaults.synchronize()
  }

  /// Get status window position
  /// Returns .topRight by default (unobtrusive for coding)
  func getPosition() -> StatusWindowPosition {
    guard let rawValue = defaults.string(forKey: positionKey),
      let position = StatusWindowPosition(rawValue: rawValue)
    else {
      return .topRight
    }
    return position
  }

  /// Save animation set preference
  func saveAnimationSet(_ animationSet: AnimationSetType) {
    defaults.set(animationSet.rawValue, forKey: animationSetKey)
    defaults.synchronize()
  }

  /// Get animation set preference
  /// Returns .waveform by default
  func getAnimationSet() -> AnimationSetType {
    guard let rawValue = defaults.string(forKey: animationSetKey),
      let animationSet = AnimationSetType(rawValue: rawValue)
    else {
      return .waveform  // Default to Set C
    }
    return animationSet
  }

  /// Save transcription model preference
  func saveTranscriptionModel(_ model: TranscriptionModel) {
    defaults.set(model.rawValue, forKey: transcriptionModelKey)
    defaults.synchronize()
  }

  /// Get transcription model preference
  /// Returns .gpt4oMiniTranscribe by default (faster for voice notes)
  func getTranscriptionModel() -> TranscriptionModel {
    guard let rawValue = defaults.string(forKey: transcriptionModelKey),
      let model = TranscriptionModel(rawValue: rawValue)
    else {
      return .gpt4oMiniTranscribe  // Default to faster model
    }
    return model
  }
}
