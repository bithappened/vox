import AppKit
import SwiftUI

// MARK: - History view

struct HistoryView: View {
  @State private var entries: [TranscriptionEntry] = []
  @State private var copiedID: UUID?
  @State private var searchText = ""

  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private var filteredEntries: [TranscriptionEntry] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return entries }
    return entries.filter { entry in
      entry.text.localizedCaseInsensitiveContains(query)
        || languageLabel(entry.language).localizedCaseInsensitiveContains(query)
        || Self.timestampFormatter.string(from: entry.timestamp).localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      if entries.isEmpty {
        emptyState(title: "No transcriptions yet", systemImage: "text.bubble")
      } else if filteredEntries.isEmpty {
        emptyState(title: "No matches", systemImage: "magnifyingglass")
      } else {
        table
      }
    }
    .frame(
      minWidth: 620,
      idealWidth: 760,
      maxWidth: .infinity,
      minHeight: 380,
      idealHeight: 520,
      maxHeight: .infinity
    )
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear(perform: loadEntries)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 23, weight: .semibold))
        .foregroundStyle(Color(nsColor: .systemBlue))

      VStack(alignment: .leading, spacing: 2) {
        Text("History")
          .font(.system(size: 20, weight: .semibold))
        Text(countLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search", text: $searchText)
          .textFieldStyle(.plain)
          .frame(width: 220)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

      if !entries.isEmpty {
        Button(action: clearHistory) {
          Image(systemName: "trash")
            .font(.system(size: 14, weight: .medium))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(HistoryIconButtonStyle(tint: Color(nsColor: .systemRed)))
        .help("Clear history")
      }
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
  }

  private var table: some View {
    VStack(spacing: 0) {
      tableHeader
      Divider()
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
            historyRow(entry, index: index)
            if index < filteredEntries.count - 1 {
              Divider().padding(.leading, 18)
            }
          }
        }
      }
    }
  }

  private var tableHeader: some View {
    HStack(spacing: 0) {
      headerCell("Time", width: 170)
      headerCell("Length", width: 78)
      headerCell("Language", width: 94)
      Text("Transcript")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      headerCell("Actions", width: 78, alignment: .trailing)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 9)
    .background(Color.primary.opacity(0.035))
  }

  private func headerCell(_ title: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .frame(width: width, alignment: alignment)
  }

  private func historyRow(_ entry: TranscriptionEntry, index: Int) -> some View {
    HStack(alignment: .center, spacing: 0) {
      Text(Self.timestampFormatter.string(from: entry.timestamp))
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(width: 170, alignment: .leading)

      durationCell(entry.duration)
        .frame(width: 78, alignment: .leading)

      Text(languageLabel(entry.language))
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(nsColor: .systemBlue).opacity(0.10), in: Capsule(style: .continuous))
        .foregroundStyle(Color(nsColor: .systemBlue))
        .frame(width: 94, alignment: .leading)

      Text(entry.text)
        .font(.system(size: 13))
        .lineLimit(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 12)

      HStack(spacing: 6) {
        Button(action: { copyToClipboard(entry) }) {
          Image(systemName: copiedID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
            .font(.system(size: 13, weight: .medium))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(HistoryIconButtonStyle(tint: copiedID == entry.id ? Color(nsColor: .systemGreen) : .secondary))
        .help("Copy")

        Button(action: { deleteEntry(entry) }) {
          Image(systemName: "trash")
            .font(.system(size: 13, weight: .medium))
            .frame(width: 24, height: 24)
        }
        .buttonStyle(HistoryIconButtonStyle(tint: .secondary))
        .help("Delete")
      }
      .frame(width: 78, alignment: .trailing)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 11)
    .background(rowBackground(index: index, entry: entry))
  }

  private func rowBackground(index: Int, entry: TranscriptionEntry) -> Color {
    if copiedID == entry.id {
      return Color(nsColor: .systemGreen).opacity(0.08)
    }
    return index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.025)
  }

  private func emptyState(title: String, systemImage: String) -> some View {
    VStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 48, weight: .light))
        .foregroundStyle(.secondary.opacity(0.55))
      Text(title)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var countLabel: String {
    let count = entries.count
    return count == 1 ? "1 item" : "\(count) items"
  }

  @ViewBuilder
  private func durationCell(_ duration: TimeInterval?) -> some View {
    if let duration {
      Text(durationLabel(duration))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(Color.primary)
    } else {
      Text("n/a")
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Color.secondary.opacity(0.65))
    }
  }

  private func durationLabel(_ duration: TimeInterval) -> String {
    let totalSeconds = max(0, Int(duration.rounded()))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }

  private func languageLabel(_ language: String) -> String {
    switch language {
    case "auto": return "Auto"
    case "en": return "English"
    case "es": return "Spanish"
    case "fr": return "French"
    case "de": return "German"
    case "it": return "Italian"
    case "pt": return "Portuguese"
    case "ja": return "Japanese"
    case "ko": return "Korean"
    case "zh": return "Chinese"
    default: return language.uppercased()
    }
  }

  private func loadEntries() {
    entries = TranscriptionHistory.shared.getEntries()
  }

  private func copyToClipboard(_ entry: TranscriptionEntry) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(entry.text, forType: .string)
    copiedID = entry.id

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
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
    alert.messageText = "Clear History?"
    alert.informativeText = "This permanently deletes all saved transcriptions."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Clear")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
      TranscriptionHistory.shared.clearHistory()
      loadEntries()
    }
  }
}

private struct HistoryIconButtonStyle: ButtonStyle {
  let tint: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(tint)
      .background(
        Circle()
          .fill(configuration.isPressed ? tint.opacity(0.14) : Color.primary.opacity(0.055))
      )
      .contentShape(Circle())
  }
}

// MARK: - Window controller

final class HistoryWindowController {
  private var window: NSWindow?

  func show() {
    if window == nil {
      let hosting = NSHostingController(rootView: HistoryView())

      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
      )

      panel.title = "vox History"
      panel.contentViewController = hosting
      panel.center()
      panel.isReleasedWhenClosed = false
      panel.level = .floating
      panel.minSize = NSSize(width: 620, height: 380)

      window = panel
    }

    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}