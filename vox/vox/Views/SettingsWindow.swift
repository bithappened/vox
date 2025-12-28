import AppKit
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
  @State private var apiKey: String = ""
  @State private var showKey: Bool = false
  @State private var statusMessage: String = ""
  @State private var isSuccess: Bool = false
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        Image(systemName: "mic.fill")
          .font(.system(size: 32))
          .foregroundStyle(.red)

        VStack(alignment: .leading, spacing: 2) {
          Text("vox")
            .font(.title2)
            .fontWeight(.semibold)

          Text("Voice transcription")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .padding(.bottom, 24)

      Divider()
        .padding(.bottom, 24)

      // API Key Section
      VStack(alignment: .leading, spacing: 12) {
        Label("OpenAI API Key", systemImage: "key.fill")
          .font(.headline)

        HStack(spacing: 8) {
          Group {
            if showKey {
              TextField("sk-proj-...", text: $apiKey)
            } else {
              SecureField("sk-proj-...", text: $apiKey)
            }
          }
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .onChange(of: apiKey) { _ in
            statusMessage = ""
          }

          Button {
            showKey.toggle()
          } label: {
            Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
          }
          .buttonStyle(.plain)
          .help(showKey ? "Hide API key" : "Show API key")
        }

        Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
          Label("Get your API key from OpenAI", systemImage: "arrow.up.right.square")
            .font(.caption)
        }
        .foregroundStyle(.blue)
      }

      Spacer()
        .frame(height: 24)

      // Info Section
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: "waveform")
            .foregroundStyle(.secondary)
          Text("Model: gpt-4o-transcribe")
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 8) {
          Image(systemName: "command")
            .foregroundStyle(.secondary)
          Text("Shortcut: ⌘⇧R")
            .foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.primary.opacity(0.05))
      )

      Spacer()

      // Status Message
      if !statusMessage.isEmpty {
        HStack(spacing: 8) {
          Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(isSuccess ? .green : .orange)

          Text(statusMessage)
            .font(.callout)
        }
        .padding(.bottom, 16)
        .transition(.scale.combined(with: .opacity))
      }

      // Buttons
      HStack(spacing: 12) {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Save") {
          saveAPIKey()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(32)
    .frame(width: 440, height: 360)
    .onAppear {
      loadAPIKey()
    }
  }

  private func loadAPIKey() {
    if let key = SettingsManager.shared.getAPIKey() {
      apiKey = key
    }
  }

  private func saveAPIKey() {
    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

    // Validation
    guard !trimmed.isEmpty else {
      showError("Please enter an API key")
      return
    }

    guard trimmed.hasPrefix("sk-") else {
      showError("Invalid key format (must start with 'sk-')")
      return
    }

    guard trimmed.count >= 20 else {
      showError("API key is too short")
      return
    }

    // Save API key
    guard SettingsManager.shared.saveAPIKey(trimmed) else {
      showError("Failed to save API key")
      return
    }

    // Success
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      statusMessage = "Saved!"
      isSuccess = true
    }

    // Auto-dismiss after success
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      dismiss()
    }
  }

  private func showError(_ message: String) {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      statusMessage = message
      isSuccess = false
    }
  }
}

// MARK: - Window Controller

class SettingsWindowController {
  private var window: NSWindow?

  func show() {
    // Create window if needed
    if window == nil {
      let settingsView = SettingsView()
      let hosting = NSHostingController(rootView: settingsView)

      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
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

    // Show and activate
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: - Preview

#Preview {
  SettingsView()
    .frame(width: 440, height: 360)
}
