import Foundation

/// Represents a single transcription entry
struct TranscriptionEntry: Identifiable, Codable {
  let id: UUID
  let text: String
  let timestamp: Date
  let language: String

  init(text: String, language: String) {
    self.id = UUID()
    self.text = text
    self.timestamp = Date()
    self.language = language
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
  func addEntry(text: String, language: String) {
    var entries = getEntries()
    let newEntry = TranscriptionEntry(text: text, language: language)
    entries.insert(newEntry, at: 0)  // Add to front

    // Keep only the most recent entries
    if entries.count > maxEntries {
      entries = Array(entries.prefix(maxEntries))
    }

    saveEntries(entries)
    print("📜 Added transcription to history (total: \(entries.count))")
  }

  /// Get all transcription entries
  func getEntries() -> [TranscriptionEntry] {
    guard let data = defaults.data(forKey: historyKey) else {
      return []
    }

    do {
      let entries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
      return entries
    } catch {
      print("⚠️  Failed to decode history: \(error)")
      return []
    }
  }

  /// Clear all history
  func clearHistory() {
    defaults.removeObject(forKey: historyKey)
    defaults.synchronize()
    print("🗑️  Transcription history cleared")
  }

  /// Delete a specific entry
  func deleteEntry(id: UUID) {
    var entries = getEntries()
    entries.removeAll { $0.id == id }
    saveEntries(entries)
    print("🗑️  Deleted transcription from history")
  }

  private func saveEntries(_ entries: [TranscriptionEntry]) {
    do {
      let data = try JSONEncoder().encode(entries)
      defaults.set(data, forKey: historyKey)
      defaults.synchronize()
    } catch {
      print("⚠️  Failed to save history: \(error)")
    }
  }
}
