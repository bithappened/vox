import AppKit
import SwiftUI

// MARK: - History View

struct HistoryView: View {
  @State private var entries: [TranscriptionEntry] = []
  @State private var copiedID: UUID?
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Image(systemName: "list.bullet.clipboard")
          .font(.system(size: 24))
          .foregroundStyle(.blue)

        Text("Transcription History")
          .font(.title2)
          .fontWeight(.semibold)

        Spacer()

        if !entries.isEmpty {
          Button(action: clearHistory) {
            Label("Clear All", systemImage: "trash")
              .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
          .help("Clear all transcriptions")
        }
      }
      .padding(20)

      Divider()

      // Content
      if entries.isEmpty {
        emptyState
      } else {
        historyList
      }
    }
    .frame(width: 600, height: 500)
    .onAppear(perform: loadEntries)
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "text.bubble")
        .font(.system(size: 60))
        .foregroundStyle(.secondary.opacity(0.5))

      Text("No transcriptions yet")
        .font(.title3)
        .foregroundStyle(.secondary)

      Text("Press Cmd+Shift+R to start recording")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var historyList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(entries) { entry in
          historyRow(entry)
        }
      }
      .padding(20)
    }
  }

  private func historyRow(_ entry: TranscriptionEntry) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text(entry.timestamp, style: .relative)
            .font(.caption)
            .foregroundStyle(.secondary)

          Text("•")
            .foregroundStyle(.secondary)

          Text(languageLabel(entry.language))
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(.blue)
            .cornerRadius(4)
        }

        Text(entry.text)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer()

      // Copy button
      Button(action: { copyToClipboard(entry) }) {
        Image(systemName: copiedID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
          .font(.system(size: 18))
          .foregroundStyle(copiedID == entry.id ? .green : .secondary)
      }
      .buttonStyle(.plain)
      .help("Copy to clipboard")

      // Delete button
      Button(action: { deleteEntry(entry) }) {
        Image(systemName: "trash")
          .font(.system(size: 16))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .help("Delete")
    }
    .padding(12)
    .background(Color.secondary.opacity(0.05))
    .cornerRadius(8)
  }

  private func languageLabel(_ language: String) -> String {
    switch language {
    case "auto": return "Auto"
    case "en": return "English"
    case "es": return "Spanish"
    default: return language.uppercased()
    }
  }

  private func loadEntries() {
    entries = TranscriptionHistory.shared.getEntries()
  }

  private func copyToClipboard(_ entry: TranscriptionEntry) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(entry.text, forType: .string)

    copiedID = entry.id

    // Reset checkmark after 2 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      if copiedID == entry.id {
        copiedID = nil
      }
    }
  }

  private func deleteEntry(_ entry: TranscriptionEntry) {
    TranscriptionHistory.shared.deleteEntry(id: entry.id)
    loadEntries()
  }

  private func clearHistory() {
    let alert = NSAlert()
    alert.messageText = "Clear All Transcriptions?"
    alert.informativeText = "This will permanently delete all transcription history."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Clear")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
      TranscriptionHistory.shared.clearHistory()
      loadEntries()
    }
  }
}

// MARK: - Window Controller

class HistoryWindowController {
  private var window: NSWindow?

  func show() {
    // Create window if needed
    if window == nil {
      let historyView = HistoryView()
      let hosting = NSHostingController(rootView: historyView)

      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
      )

      panel.title = "Transcription History"
      panel.contentViewController = hosting
      panel.center()
      panel.isReleasedWhenClosed = false
      panel.level = .floating
      panel.minSize = NSSize(width: 400, height: 300)

      window = panel
    }

    // Show and activate
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: - Preview

#Preview {
  HistoryView()
    .frame(width: 600, height: 500)
}
