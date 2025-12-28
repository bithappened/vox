import AppKit
import SwiftUI

// MARK: - Status State

enum StatusState: Equatable {
  case recording
  case transcribing
  case success(String)
  case error(String)
}

// MARK: - Status View

struct CompactStatusView: View {
  let state: StatusState
  let audioLevel: Float
  let duration: TimeInterval
  let onCancel: (() -> Void)?

  @State private var appeared = false

  private var animationSet: AnimationSetType {
    SettingsManager.shared.getAnimationSet()
  }

  var body: some View {
    HStack(spacing: 10) {
      // Indicator - uses selected animation set
      Group {
        switch state {
        case .recording:
          AnimationSetFactory.recordingView(for: animationSet, audioLevel: audioLevel, color: .red)
            .frame(
              width: AnimationSetFactory.recordingFrameSize(for: animationSet).width,
              height: AnimationSetFactory.recordingFrameSize(for: animationSet).height
            )
        case .transcribing:
          AnimationSetFactory.transcribingView(for: animationSet, color: .blue)
            .frame(
              width: AnimationSetFactory.transcribingFrameSize(for: animationSet).width,
              height: AnimationSetFactory.transcribingFrameSize(for: animationSet).height
            )
        case .success:
          AnimationSetFactory.successView(for: animationSet)
            .frame(width: 24, height: 24)
        case .error:
          AnimationSetFactory.errorView(for: animationSet)
            .frame(width: 24, height: 24)
        }
      }

      // Text
      switch state {
      case .recording:
        Text(formatDuration(duration))
          .font(.system(size: 17, weight: .medium, design: .monospaced))
          .foregroundStyle(.primary)
          .fixedSize()

      case .transcribing:
        Text("Transcribing")
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(.primary)
          .fixedSize()

      case .success(let message):
        Text(message)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(.primary)
          .fixedSize()

      case .error(let message):
        Text(message)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(.orange)
          .fixedSize()
      }

      // Cancel button
      if case .recording = state, let onCancel = onCancel {
        Button(action: onCancel) {
          Image(systemName: "xmark")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.leading, 12)
    .padding(.trailing, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.regularMaterial)
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    )
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .scaleEffect(appeared ? 1.0 : 0.9)
    .opacity(appeared ? 1.0 : 0.0)
    .onAppear {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
        appeared = true
      }
    }
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Window Controller

class StatusWindowController: NSObject {
  private var window: NSPanel?
  private var hostingView: NSHostingView<CompactStatusView>?

  private var currentState: StatusState = .recording
  private var currentAudioLevel: Float = 0.0
  private var currentDuration: TimeInterval = 0
  private var cancelHandler: (() -> Void)?

  private var position: StatusWindowPosition {
    SettingsManager.shared.getPosition()
  }

  func show(state: StatusState, audioLevel: Float = 0, duration: TimeInterval = 0) {
    currentState = state
    currentAudioLevel = audioLevel
    currentDuration = duration

    ensureWindow()
    updateContent()
    positionWindow()

    window?.alphaValue = 1.0
    window?.orderFrontRegardless()
  }

  func updateRecording(audioLevel: Float, duration: TimeInterval) {
    currentAudioLevel = audioLevel
    currentDuration = duration
    updateContent()
  }

  func setCancelHandler(_ handler: @escaping () -> Void) {
    cancelHandler = handler
  }

  private func ensureWindow() {
    guard window == nil else { return }

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 160, height: 44),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    panel.isFloatingPanel = true
    panel.level = .floating
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

    window = panel
  }

  private func updateContent() {
    let statusView = CompactStatusView(
      state: currentState,
      audioLevel: currentAudioLevel,
      duration: currentDuration,
      onCancel: cancelHandler
    )

    if hostingView == nil {
      hostingView = NSHostingView(rootView: statusView)
      window?.contentView = hostingView
    } else {
      hostingView?.rootView = statusView
    }

    if let contentSize = hostingView?.fittingSize {
      window?.setContentSize(contentSize)
    }
  }

  private func positionWindow() {
    guard let screen = NSScreen.main, let window = window else { return }

    let screenRect = screen.visibleFrame
    let windowRect = window.frame
    let padding: CGFloat = 16

    let origin: NSPoint
    switch position {
    case .topRight:
      origin = NSPoint(
        x: screenRect.maxX - windowRect.width - padding,
        y: screenRect.maxY - windowRect.height - padding
      )
    case .bottomRight:
      origin = NSPoint(
        x: screenRect.maxX - windowRect.width - padding,
        y: screenRect.minY + padding
      )
    case .topLeft:
      origin = NSPoint(
        x: screenRect.minX + padding,
        y: screenRect.maxY - windowRect.height - padding
      )
    case .bottomLeft:
      origin = NSPoint(
        x: screenRect.minX + padding,
        y: screenRect.minY + padding
      )
    case .centerTop:
      origin = NSPoint(
        x: screenRect.midX - windowRect.width / 2,
        y: screenRect.maxY - windowRect.height - padding
      )
    }

    window.setFrameOrigin(origin)
  }

  func hide() {
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.2
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window?.animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        self?.window?.orderOut(nil)
        self?.window?.alphaValue = 1.0
        self?.cancelHandler = nil
      }
    )
  }
}

// MARK: - Legacy type aliases for compatibility

typealias AudioBarsView = BarsRecordingView
typealias WaveSweepView = BarsTranscribingView
typealias SuccessIndicatorView = BarsSuccessView
typealias ErrorIndicatorView = BarsErrorView
