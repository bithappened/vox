import AppKit
import SwiftUI

// swiftlint:disable:next force_unwrapping
private let openAIKeysURL = URL(string: "https://platform.openai.com/api-keys")!

private let supportedLanguages: [(code: String, label: String)] = [
  ("auto", "Auto-detect"),
  ("en", "English"),
  ("es", "Spanish"),
  ("fr", "French"),
  ("de", "German"),
  ("it", "Italian"),
  ("pt", "Portuguese"),
  ("ja", "Japanese"),
  ("ko", "Korean"),
  ("zh", "Chinese")
]

// MARK: - Settings view

struct SettingsView: View {
  @State private var apiKey: String = ""
  @State private var showKey: Bool = false
  @State private var statusMessage: String = ""
  @State private var isSuccess: Bool = false
  @State private var transcriptionModel: TranscriptionModel = .gpt4oMiniTranscribe
  @State private var languageCode: String = "auto"
  @State private var statusPosition: StatusWindowPosition = .topRight

  @Environment(\.dismiss) var dismiss

  private var trimmedKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var keyLooksValid: Bool { trimmedKey.hasPrefix("sk-") && trimmedKey.count >= 20 }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(spacing: 18) {
          apiKeyGroup
          transcriptionGroup
          displayGroup
          shortcutsGroup
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
      }
      Divider()
      footer
    }
    .frame(width: 500, height: 664)
    .onAppear(perform: load)
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 13) {
      AppBadge()
      VStack(alignment: .leading, spacing: 1) {
        Text("vox").font(.system(size: 22, weight: .bold))
        Text("Voice transcription").font(.subheadline).foregroundStyle(.secondary)
      }
      Spacer()
      Text("v1.0").font(.caption).foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }

  // MARK: Groups

  private var apiKeyGroup: some View {
    SettingsGroup(title: "OpenAI API Key", icon: "key.fill", footer: AnyView(apiKeyFooter)) {
      HStack(spacing: 8) {
        Group {
          if showKey {
            TextField("sk-proj-…", text: $apiKey)
          } else {
            SecureField("sk-proj-…", text: $apiKey)
          }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 12, design: .monospaced))
        .onChange(of: apiKey) { _ in statusMessage = "" }

        iconButton(showKey ? "eye.slash.fill" : "eye.fill", help: showKey ? "Hide key" : "Show key") {
          showKey.toggle()
        }
        iconButton("trash", help: "Remove stored key",
                   disabled: apiKey.isEmpty && !SettingsManager.shared.hasAPIKey()) {
          clearAPIKey()
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 11)
    }
  }

  private var apiKeyFooter: some View {
    HStack(spacing: 4) {
      Image(systemName: keyLooksValid ? "checkmark.seal.fill" : "info.circle")
        .foregroundStyle(keyLooksValid ? Color(nsColor: .systemGreen) : .secondary)
      Text(keyLooksValid ? "Key looks valid." : "Keys start with “sk-”.")
        .foregroundStyle(.secondary)
      Spacer()
      Link(destination: openAIKeysURL) {
        HStack(spacing: 3) {
          Text("Get a key")
          Image(systemName: "arrow.up.right")
        }
      }
    }
    .font(.caption)
  }

  private var transcriptionGroup: some View {
    SettingsGroup(
      title: "Transcription",
      icon: "waveform",
      footer: AnyView(
        Text("\(transcriptionModel.description). Auto-detect handles multilingual recordings.")
      )
    ) {
      labeledRow("Model") {
        Picker("", selection: $transcriptionModel) {
          ForEach(TranscriptionModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
      }
      rowDivider()
      labeledRow("Language") {
        Picker("", selection: $languageCode) {
          ForEach(supportedLanguages, id: \.code) { Text($0.label).tag($0.code) }
        }
        .labelsHidden()
        .fixedSize()
      }
    }
  }

  private var displayGroup: some View {
    SettingsGroup(
      title: "Display",
      icon: "rectangle.on.rectangle",
      footer: AnyView(Text("Where the recording indicator appears on screen."))
    ) {
      labeledRow("Indicator position") {
        Picker("", selection: $statusPosition) {
          ForEach(StatusWindowPosition.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
      }
    }
  }

  private var shortcutsGroup: some View {
    SettingsGroup(title: "Shortcuts", icon: "command") {
      labeledRow("Start / stop recording") { keyCaps(["⇧", "⌘", "R"]) }
      rowDivider()
      labeledRow("Accept & transcribe") { keyCaps(["⏎"]) }
      rowDivider()
      labeledRow("Cancel recording") { keyCaps(["esc"]) }
    }
  }

  // MARK: Footer

  private var footer: some View {
    HStack(spacing: 10) {
      if !statusMessage.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(isSuccess ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
          Text(statusMessage)
        }
        .font(.callout)
        .transition(.opacity)
      }
      Spacer()
      Button("Cancel") { dismiss() }
        .keyboardShortcut(.cancelAction)
      Button("Save") { save() }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(trimmedKey.isEmpty)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  // MARK: Row helpers

  private func labeledRow<Control: View>(_ label: String, @ViewBuilder _ control: () -> Control) -> some View {
    HStack {
      Text(label).font(.system(size: 13))
      Spacer(minLength: 12)
      control()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
  }

  private func iconButton(_ symbol: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(width: 26, height: 26)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
    .buttonStyle(.plain)
    .help(help)
    .disabled(disabled)
  }

  // MARK: Actions

  private func load() {
    apiKey = SettingsManager.shared.getAPIKey() ?? ""
    transcriptionModel = SettingsManager.shared.getTranscriptionModel()
    languageCode = SettingsManager.shared.getLanguagePreference()
    statusPosition = SettingsManager.shared.getPosition()
  }

  private func save() {
    guard !trimmedKey.isEmpty else {
      showError("Please enter an API key")
      return
    }
    guard trimmedKey.hasPrefix("sk-") else {
      showError("Invalid key format (must start with 'sk-')")
      return
    }
    guard trimmedKey.count >= 20 else {
      showError("API key is too short")
      return
    }

    guard SettingsManager.shared.saveAPIKey(trimmedKey) else {
      showError("Failed to save API key")
      return
    }

    SettingsManager.shared.saveTranscriptionModel(transcriptionModel)
    SettingsManager.shared.saveLanguagePreference(languageCode)
    SettingsManager.shared.savePosition(statusPosition)

    withAnimation(.easeOut(duration: 0.2)) {
      statusMessage = "Saved"
      isSuccess = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
      dismiss()
    }
  }

  private func clearAPIKey() {
    SettingsManager.shared.deleteAPIKey()
    apiKey = ""
    withAnimation(.easeOut(duration: 0.2)) {
      statusMessage = "API key removed"
      isSuccess = true
    }
  }

  private func showError(_ message: String) {
    withAnimation(.easeOut(duration: 0.2)) {
      statusMessage = message
      isSuccess = false
    }
  }
}

// MARK: - Reusable components

/// The app-identity badge — a glossy rounded-square icon, drawn in SwiftUI so it
/// stays crisp at any scale and matches the recording mic identity.
private struct AppBadge: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(LinearGradient(
          colors: [Color(red: 1.0, green: 0.42, blue: 0.40), Color(red: 0.83, green: 0.13, blue: 0.20)],
          startPoint: .top, endPoint: .bottom))
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(LinearGradient(colors: [Color.white.opacity(0.38), Color.clear], startPoint: .top, endPoint: .center))
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.30), lineWidth: 0.6)
      Image(systemName: "mic.fill")
        .font(.system(size: 21, weight: .medium))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
    }
    .frame(width: 44, height: 44)
    .shadow(color: Color(red: 0.83, green: 0.13, blue: 0.20).opacity(0.32), radius: 5, y: 3)
  }
}

/// A single keyboard keycap.
private struct KeyCap: View {
  let label: String
  init(_ label: String) { self.label = label }

  var body: some View {
    Text(label)
      .font(.system(size: 11, weight: .semibold, design: .rounded))
      .foregroundStyle(.primary)
      .frame(minWidth: 13)
      .padding(.horizontal, 5)
      .padding(.vertical, 3)
      .background(
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .fill(Color(nsColor: .controlColor))
          .shadow(color: .black.opacity(0.10), radius: 0.5, y: 0.5))
      .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color.primary.opacity(0.14), lineWidth: 0.6))
  }
}

private func keyCaps(_ caps: [String]) -> some View {
  HStack(spacing: 3) { ForEach(caps, id: \.self) { KeyCap($0) } }
}

/// A grouped settings "card" with an icon header and an optional footnote —
/// the macOS System-Settings idiom, hand-built for full control of the details.
private struct SettingsGroup<Content: View>: View {
  let title: String
  let icon: String
  var footer: AnyView?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
      }
      .padding(.leading, 4)

      VStack(spacing: 0) { content }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5))

      if let footer {
        footer.font(.caption).foregroundStyle(.secondary).padding(.leading, 4).padding(.top, 1)
      }
    }
  }
}

private func rowDivider() -> some View {
  Divider().overlay(Color(nsColor: .separatorColor).opacity(0.6)).padding(.leading, 14)
}

// MARK: - Window controller

final class SettingsWindowController {
  private var window: NSWindow?

  func show() {
    if window == nil {
      let hosting = NSHostingController(rootView: SettingsView())
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 664),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
      )
      panel.title = "vox Settings"
      panel.contentViewController = hosting
      panel.center()
      panel.isReleasedWhenClosed = false
      panel.level = .floating
      window = panel
    }
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
