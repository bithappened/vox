import AppKit
import SwiftUI

// MARK: - Animation Preview View

struct AnimationPreviewView: View {
  @State private var simulatedAudioLevel: Float = 0.0
  @State private var isAnimating = false
  @State private var refreshID = UUID()

  var body: some View {
    VStack(spacing: 20) {
      Text("Animation Preview")
        .font(.system(size: 16, weight: .semibold))
        .padding(.top, 8)

      // Audio level slider
      VStack(spacing: 8) {
        Text("Simulated Audio Level: \(String(format: "%.0f%%", simulatedAudioLevel * 100))")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)

        Slider(value: $simulatedAudioLevel, in: 0...1)
          .frame(width: 220)

        HStack(spacing: 12) {
          Button(isAnimating ? "Stop Auto" : "Auto Animate") {
            isAnimating.toggle()
          }
          Button("Replay") {
            refreshID = UUID()
          }
        }
        .font(.system(size: 11))
      }
      .padding(.horizontal)

      Divider()

      // SET A: Bars
      sectionHeader("Set A: Bars")

      HStack(spacing: 16) {
        stateCard("Recording", .red) {
          BarsRecordingView(audioLevel: simulatedAudioLevel, color: .red)
            .frame(width: 32, height: 24)
        }
        stateCard("Transcribing", .blue) {
          BarsTranscribingView(color: .blue)
            .frame(width: 32, height: 24)
        }
        stateCard("Success", .green) {
          BarsSuccessView()
            .frame(width: 24, height: 24)
        }
        .id("a-success-\(refreshID)")
        stateCard("Error", .orange) {
          BarsErrorView()
            .frame(width: 24, height: 24)
        }
        .id("a-error-\(refreshID)")
      }

      Divider()

      // SET B: Pulse Rings
      sectionHeader("Set B: Pulse Rings")

      HStack(spacing: 16) {
        stateCard("Recording", .red) {
          PulseRecordingView(audioLevel: simulatedAudioLevel, color: .red)
            .frame(width: 28, height: 28)
        }
        stateCard("Transcribing", .blue) {
          PulseTranscribingView(color: .blue)
            .frame(width: 28, height: 28)
        }
        stateCard("Success", .green) {
          PulseSuccessView()
            .frame(width: 24, height: 24)
        }
        .id("b-success-\(refreshID)")
        stateCard("Error", .orange) {
          PulseErrorView()
            .frame(width: 24, height: 24)
        }
        .id("b-error-\(refreshID)")
      }

      Divider()

      // SET C: Waveform (Default)
      sectionHeader("Set C: Waveform (Default)")

      HStack(spacing: 16) {
        stateCard("Recording", .red) {
          WaveRecordingView(audioLevel: simulatedAudioLevel, color: .red)
            .frame(width: 36, height: 24)
        }
        stateCard("Transcribing", .blue) {
          WaveTranscribingView(color: .blue)
            .frame(width: 36, height: 24)
        }
        stateCard("Success", .green) {
          WaveSuccessView()
            .frame(width: 24, height: 24)
        }
        .id("c-success-\(refreshID)")
        stateCard("Error", .orange) {
          WaveErrorView()
            .frame(width: 24, height: 24)
        }
        .id("c-error-\(refreshID)")
      }

      Divider()

      // Full status preview with selected
      sectionHeader("Full Preview (Selected: \(SettingsManager.shared.getAnimationSet().displayName))")

      VStack(spacing: 10) {
        CompactStatusView(state: .recording, audioLevel: simulatedAudioLevel, duration: 5, onCancel: {})
        CompactStatusView(state: .transcribing, audioLevel: 0, duration: 0, onCancel: nil)
        CompactStatusView(state: .success("Copied!"), audioLevel: 0, duration: 0, onCancel: nil)
          .id("full-success-\(refreshID)")
        CompactStatusView(state: .error("API Error"), audioLevel: 0, duration: 0, onCancel: nil)
          .id("full-error-\(refreshID)")
      }

      Spacer(minLength: 20)
    }
    .frame(width: 340)
    .padding(.bottom, 16)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      startAutoAnimation()
    }
    .onChange(of: isAnimating) { newValue in
      if newValue { startAutoAnimation() }
    }
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
  }

  private func stateCard<Content: View>(
    _ label: String,
    _ color: Color,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 6) {
      content()
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
      Text(label)
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  private func startAutoAnimation() {
    guard isAnimating else { return }
    Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { timer in
      guard self.isAnimating else { timer.invalidate(); return }
      let delta = Float.random(in: -0.12...0.12)
      let newLevel = self.simulatedAudioLevel + delta
      if Float.random(in: 0...1) < 0.08 {
        self.simulatedAudioLevel = min(1.0, self.simulatedAudioLevel + 0.35)
      } else {
        self.simulatedAudioLevel = max(0, min(1, newLevel))
      }
    }
  }
}

// MARK: - Window Controller

class AnimationPreviewWindowController: NSObject {
  private var window: NSWindow?

  func show() {
    if window == nil {
      let scrollView = NSScrollView()
      scrollView.hasVerticalScroller = true
      scrollView.hasHorizontalScroller = false
      scrollView.autohidesScrollers = true

      let contentView = AnimationPreviewView()
      let hostingView = NSHostingView(rootView: contentView)
      hostingView.translatesAutoresizingMaskIntoConstraints = false

      scrollView.documentView = hostingView

      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 340, height: 700),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
      )

      window?.title = "Proposed Animations"
      window?.contentView = scrollView
      window?.minSize = NSSize(width: 340, height: 400)
      window?.center()
      window?.isReleasedWhenClosed = false
    }

    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
