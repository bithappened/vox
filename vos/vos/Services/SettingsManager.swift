import Foundation

/// Manages app settings using UserDefaults
///
/// Uses UserDefaults for API key storage, which is the standard approach for Mac apps
/// (similar to Slack, Discord, VSCode, etc.). Automatically trims whitespace and newlines
/// to prevent corruption issues.
final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard
  private let apiKeyKey = "vos_api_key"

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
}
