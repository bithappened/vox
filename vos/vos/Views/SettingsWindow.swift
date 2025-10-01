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
    VStack(spacing: 24) {
      // Header
      HStack(spacing: 12) {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 28))
          .foregroundStyle(.blue)

        Text("Settings")
          .font(.title2)
          .fontWeight(.semibold)

        Spacer()
      }

      // API Key Section
      VStack(alignment: .leading, spacing: 12) {
        Text("OpenAI API Key")
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
            statusMessage = ""  // Clear message on edit
          }

          Button {
            showKey.toggle()
          } label: {
            Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
              .foregroundStyle(.secondary)
              .frame(width: 20, height: 20)
          }
          .buttonStyle(.plain)
          .help(showKey ? "Hide API key" : "Show API key")
        }

        Text("Get your API key from platform.openai.com")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // Model Info
      HStack(spacing: 8) {
        Text("Model:")
          .foregroundStyle(.secondary)
        Text("gpt-4o-transcribe")
          .fontWeight(.medium)
        Spacer()
      }
      .font(.subheadline)

      // Status Message
      if !statusMessage.isEmpty {
        HStack(spacing: 8) {
          Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundStyle(isSuccess ? .green : .orange)

          Text(statusMessage)
            .font(.callout)
        }
        .transition(.scale.combined(with: .opacity))
      }

      Spacer()

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
    .frame(width: 520, height: 320)
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

    // Save
    guard SettingsManager.shared.saveAPIKey(trimmed) else {
      showError("Failed to save API key")
      return
    }

    // Success
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      statusMessage = "API key saved successfully (length: \(trimmed.count))"
      isSuccess = true
    }

    // Auto-dismiss after success
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
      )

      panel.title = "vos Settings"
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
    .frame(width: 520, height: 320)
}
