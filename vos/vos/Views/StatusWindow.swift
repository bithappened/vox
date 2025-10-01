import AppKit
import SwiftUI

// MARK: - Status State

enum StatusState {
  case recording
  case transcribing
  case success
  case error

  var color: Color {
    switch self {
    case .recording: return .red
    case .transcribing: return .blue
    case .success: return .green
    case .error: return .orange
    }
  }

  var icon: String {
    switch self {
    case .recording: return "mic.fill"
    case .transcribing: return "waveform.circle.fill"
    case .success: return "checkmark.circle.fill"
    case .error: return "exclamationmark.triangle.fill"
    }
  }
}

// MARK: - Status View

struct StatusView: View {
  let message: String
  let state: StatusState

  @State private var scale: CGFloat = 0.8
  @State private var opacity: Double = 0.0
  @State private var pulseScale: CGFloat = 1.0

  var body: some View {
    HStack(spacing: 14) {
      // Icon with optional pulse animation
      ZStack {
        // Pulsing background for recording state
        if state == .recording {
          Circle()
            .fill(state.color.opacity(0.2))
            .frame(width: 40, height: 40)
            .scaleEffect(pulseScale)
            .onAppear {
              withAnimation(
                .easeInOut(duration: 1.0)
                  .repeatForever(autoreverses: true)
              ) {
                pulseScale = 1.4
              }
            }
        }

        // Icon
        Image(systemName: state.icon)
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(state.color)
      }
      .frame(width: 40, height: 40)

      // Message
      Text(message)
        .font(.body)
        .fontWeight(.medium)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .frame(minWidth: 280, maxWidth: 420)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(.ultraThinMaterial)
        .shadow(
          color: Color.black.opacity(0.15),
          radius: 20,
          x: 0,
          y: 8
        )
    )
    .scaleEffect(scale)
    .opacity(opacity)
    .onAppear {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
        scale = 1.0
        opacity = 1.0
      }
    }
  }
}

// MARK: - Window Controller

class StatusWindowController: NSObject {
  private var window: NSWindow?
  private var hostingView: NSHostingView<StatusView>?

  func show(message: String, state: StatusState) {
    // Create window if needed
    if window == nil {
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 80),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )

      panel.isFloatingPanel = true
      panel.level = .floating
      panel.backgroundColor = .clear
      panel.isOpaque = false
      panel.hasShadow = false
      panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

      window = panel
    }

    // Update content
    let statusView = StatusView(message: message, state: state)
    hostingView = NSHostingView(rootView: statusView)
    window?.contentView = hostingView

    // Auto-resize to fit content
    if let contentSize = hostingView?.fittingSize {
      window?.setContentSize(contentSize)
    }

    // Position at center-top of screen
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let windowRect = window!.frame
      let xPosition = screenRect.midX - windowRect.width / 2
      let yPosition = screenRect.midY + (screenRect.height / 3)
      window?.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }

    // Ensure full opacity and show
    window?.alphaValue = 1.0
    window?.orderFrontRegardless()
  }

  func hide() {
    // Smooth fade out
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window?.animator().alphaValue = 0
      },
      completionHandler: {
        self.window?.orderOut(nil)
        self.window?.alphaValue = 1.0
      }
    )
  }
}

// MARK: - Preview

#Preview {
  StatusView(message: "Recording...", state: .recording)
    .frame(width: 420, height: 80)
}
