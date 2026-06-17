import Foundation

/// Represents a single transcription entry
struct TranscriptionEntry: Identifiable, Codable {
  let id: UUID
  let text: String
  let timestamp: Date
  let language: String
  let duration: TimeInterval?

  init(text: String, language: String, duration: TimeInterval? = nil) {
    self.id = UUID()
    self.text = text
    self.timestamp = Date()
    self.language = language
    self.duration = duration
  }
}

/// Manages transcription history with persistence
final class TranscriptionHistory {
  static let shared = TranscriptionHistory()

  private let defaults = UserDefaults.standard
  private let historyKey = "vox_transcription_history"
  private let maxEntries = 50  // Keep last 50 transcriptions

  private init() {}

  /// Add a new transcription to history
  func addEntry(text: String, language: String, duration: TimeInterval? = nil) {
    var entries = getEntries()
    entries.insert(TranscriptionEntry(text: text, language: language, duration: duration), at: 0)
    if entries.count > maxEntries {
      entries = Array(entries.prefix(maxEntries))
    }
    saveEntries(entries)
  }

  /// Get all transcription entries
  func getEntries() -> [TranscriptionEntry] {
    guard let data = defaults.data(forKey: historyKey) else { return [] }
    do {
      return try JSONDecoder().decode([TranscriptionEntry].self, from: data)
    } catch {
      debugLog("Failed to decode history: \(error)")
      return []
    }
  }

  /// Clear all history
  func clearHistory() {
    defaults.removeObject(forKey: historyKey)
  }

  /// Delete a specific entry
  func deleteEntry(id: UUID) {
    var entries = getEntries()
    entries.removeAll { $0.id == id }
    saveEntries(entries)
  }

  private func saveEntries(_ entries: [TranscriptionEntry]) {
    do {
      let data = try JSONEncoder().encode(entries)
      defaults.set(data, forKey: historyKey)
    } catch {
      debugLog("Failed to save history: \(error)")
    }
  }
}
