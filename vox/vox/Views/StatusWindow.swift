import AppKit
import Combine
import SwiftUI

// MARK: - Status state

enum StatusState: Equatable {
  case hidden
  case recording(startTime: Date)
  case transcribing
  case success(String)
  case error(String)

  var kind: String {
    switch self {
    case .hidden: return "hidden"
    case .recording: return "recording"
    case .transcribing: return "transcribing"
    case .success: return "success"
    case .error: return "error"
    }
  }
}

// MARK: - View model

/// Holds transient state for the status pill. The window's hosting view
/// observes this directly so 50 Hz audio sample updates don't force a
/// hosting-view rebuild or window reposition.
final class StatusViewModel: ObservableObject {
  @Published var state: StatusState = .hidden
  @Published var samples: [AudioSample] = []
  @Published var animationStyle: RecordingAnimationStyle = .tinyRobot
  private var lastSamplePruneTime: TimeInterval = 0

  /// Append a new audio sample, dropping anything older than `historyWindow`.
  func append(level: Float, historyWindow: TimeInterval = 2.0) {
    let now = Date().timeIntervalSinceReferenceDate
    samples.append(AudioSample(level: level, time: now))

    guard now - lastSamplePruneTime >= 0.25 || samples.count > 128 else { return }
    lastSamplePruneTime = now

    let cutoff = now - historyWindow
    if let firstFresh = samples.firstIndex(where: { $0.time >= cutoff }), firstFresh > 0 {
      samples.removeFirst(firstFresh)
    }
    if samples.count > 128 {
      samples.removeFirst(samples.count - 128)
    }
  }

  func resetSamples() {
    samples.removeAll(keepingCapacity: true)
    lastSamplePruneTime = 0
  }
}

// MARK: - View

struct CompactStatusView: View {
  @ObservedObject var viewModel: StatusViewModel
  let onCancel: (() -> Void)?

  private var accentColor: Color {
    switch viewModel.state {
    case .hidden: return Color.primary.opacity(0.12)
    case .recording: return viewModel.animationStyle.accentColor
    case .transcribing: return Color(nsColor: .systemBlue)
    case .success: return Color(nsColor: .systemGreen)
    case .error: return Color(nsColor: .systemOrange)
    }
  }

  var body: some View {
    Group {
      if viewModel.animationStyle == .tinyRobot {
        floatingLayout
      } else {
        pillLayout
      }
    }
    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.state.kind)
  }

  // MARK: Floating character (no bounding pill)

  /// Rover lives directly on the desktop with only a small caption chip for the
  /// timer / status — the character draws its own shadow, so no box is needed.
  private var floatingLayout: some View {
    VStack(spacing: 2) {
      indicator
      captionChip
    }
  }

  @ViewBuilder
  private var captionChip: some View {
    switch viewModel.state {
    case .hidden:
      EmptyView()
    case .recording(let startTime):
      captionContainer {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
          Text(formatDuration(timeline.date.timeIntervalSince(startTime)))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .fixedSize()
        }
      }
    case .transcribing:
      captionContainer { Text("Transcribing").font(captionFont).foregroundStyle(.primary) }
    case .success(let message):
      captionContainer { Text(message).font(captionFont).foregroundStyle(.primary) }
    case .error(let message):
      captionContainer { Text(message).font(captionFont).foregroundStyle(Color(nsColor: .systemOrange)) }
    }
  }

  private var captionFont: Font { .system(size: 12, weight: .medium, design: .rounded) }

  private func captionContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .fixedSize()
      .padding(.horizontal, 9)
      .padding(.vertical, 3)
      .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
      .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.6))
      .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
      .transition(.opacity.combined(with: .scale(scale: 0.9)))
  }

  // MARK: Pill (waveform / other styles)

  private var pillLayout: some View {
    HStack(spacing: 10) {
      indicator
      labelSlot
      cancelButtonSlot
    }
    .padding(.leading, 12)
    .padding(.trailing, 10)
    .padding(.vertical, 8)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(
            LinearGradient(
              colors: [accentColor.opacity(0.10), Color.clear],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color.primary.opacity(0.07), lineWidth: 0.6)
      }
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .shadow(color: .black.opacity(0.20), radius: 14, y: 5)
  }

  // MARK: Indicator

  @ViewBuilder
  private var indicator: some View {
    switch viewModel.state {
    case .hidden:
      EmptyView()
    case .recording:
      StatusIndicatorFactory.recording(style: viewModel.animationStyle, samples: viewModel.samples)
        .frame(
          width: stableIndicatorFrameSize.width,
          height: stableIndicatorFrameSize.height
        )
    case .transcribing:
      StatusIndicatorFactory.transcribing(style: viewModel.animationStyle)
        .frame(
          width: stableIndicatorFrameSize.width,
          height: stableIndicatorFrameSize.height
        )
    case .success:
      StatusIndicatorFactory.feedback(style: viewModel.animationStyle, isSuccess: true)
        .frame(width: stableIndicatorFrameSize.width, height: stableIndicatorFrameSize.height)
    case .error:
      StatusIndicatorFactory.feedback(style: viewModel.animationStyle, isSuccess: false)
        .frame(width: stableIndicatorFrameSize.width, height: stableIndicatorFrameSize.height)
    }
  }

  private var stableIndicatorFrameSize: CGSize {
    let recording = viewModel.animationStyle.recordingFrameSize
    let transcribing = viewModel.animationStyle.transcribingFrameSize
    return CGSize(
      width: max(recording.width, transcribing.width, 56),
      height: max(recording.height, transcribing.height, 24)
    )
  }

  private var isRecordingState: Bool {
    if case .recording = viewModel.state { return true }
    return false
  }

  private var labelSlotWidth: CGFloat {
    viewModel.animationStyle == .voiceWave ? 0 : 46
  }

  private var timerFont: Font {
    .system(size: 14, weight: .medium, design: .monospaced)
  }

  // MARK: Label

  @ViewBuilder
  private var label: some View {
    switch viewModel.state {
    case .hidden:
      EmptyView()
    case .recording(let startTime):
      // TimelineView guarantees the duration text re-renders ~30Hz even when
      // audio levels stop arriving for any reason.
      TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
        let elapsed = timeline.date.timeIntervalSince(startTime)
        Text(formatDuration(elapsed))
          .font(timerFont)
          .foregroundStyle(.primary)
          .monospacedDigit()
          .fixedSize()
      }
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
        .foregroundStyle(Color(nsColor: .systemOrange))
        .fixedSize()
    }
  }

  @ViewBuilder
  private var labelSlot: some View {
    if labelSlotWidth > 0 {
      label
        .opacity(isRecordingState ? 1 : 0)
        .frame(width: labelSlotWidth, alignment: .leading)
    }
  }

  // MARK: Cancel

  @ViewBuilder
  private var cancelButton: some View {
    if case .recording = viewModel.state, let onCancel = onCancel {
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 18, height: 18)
          .background(Circle().fill(Color.primary.opacity(0.08)))
      }
      .buttonStyle(.plain)
      .help("Cancel recording (Esc)")
    }
  }

  private var cancelButtonSlot: some View {
    ZStack {
      cancelButton
        .opacity(isRecordingState ? 1 : 0)
        .allowsHitTesting(isRecordingState)
    }
    .frame(width: 18, height: 18)
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let total = max(0, Int(duration))
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}

// MARK: - Window controller

final class StatusWindowController: NSObject {
  let viewModel = StatusViewModel()

  private var window: NSPanel?
  private var hostingView: NSHostingView<CompactStatusView>?
  private var cancelHandler: (() -> Void)?
  private var isVisible: Bool = false
  private var hideWorkItem: DispatchWorkItem?
  private var lastFittingSize: NSSize = .zero
  private var stateSubscription: AnyCancellable?
  private var styleSubscription: AnyCancellable?
  private var transitionID = 0

  private var position: StatusWindowPosition {
    SettingsManager.shared.getPosition()
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  override init() {
    super.init()
    viewModel.animationStyle = SettingsManager.shared.getAnimationStyle()
    // When the state *kind* changes we want to resize the pill.
    stateSubscription = viewModel.$state
      .map(\.kind)
      .removeDuplicates()
      .sink { [weak self] _ in
        // Defer to next runloop so the SwiftUI view has rendered the new content first.
        DispatchQueue.main.async { self?.fitWindowSize(animated: true) }
      }
    styleSubscription = viewModel.$animationStyle
      .removeDuplicates()
      .sink { [weak self] _ in
        DispatchQueue.main.async { self?.fitWindowSize(animated: true) }
      }
  }

  // MARK: Public API

  func showRecording(startTime: Date) {
    cancelHide()
    viewModel.animationStyle = SettingsManager.shared.getAnimationStyle()
    viewModel.resetSamples()
    viewModel.state = .recording(startTime: startTime)
    presentIfNeeded()
  }

  func showTranscribing() {
    cancelHide()
    viewModel.state = .transcribing
    presentIfNeeded()
  }

  func showSuccess(_ message: String) {
    cancelHide()
    viewModel.state = .success(message)
    presentIfNeeded()
  }

  func showError(_ message: String) {
    cancelHide()
    viewModel.state = .error(message)
    presentIfNeeded()
  }

  func appendSample(_ level: Float) {
    viewModel.append(level: level)
  }

  func setCancelHandler(_ handler: @escaping () -> Void) {
    cancelHandler = handler
    if hostingView != nil {
      rebuildHostingViewIfNeeded()
    }
  }

  func hide(after delay: TimeInterval = 0) {
    cancelHide()
    let work = DispatchWorkItem { [weak self] in
      self?.animateOut()
    }
    hideWorkItem = work
    if delay <= 0 {
      DispatchQueue.main.async(execute: work)
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
  }

  // MARK: Internals

  private func cancelHide() {
    hideWorkItem?.cancel()
    hideWorkItem = nil
  }

  private func presentIfNeeded() {
    ensureWindow()
    rebuildHostingViewIfNeeded()
    fitWindowSize(animated: isVisible)
    if !isVisible {
      animateIn()
    }
  }

  private func ensureWindow() {
    guard window == nil else { return }
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.alphaValue = 0
    window = panel
  }

  private func rebuildHostingViewIfNeeded() {
    let view = CompactStatusView(viewModel: viewModel, onCancel: cancelHandler)
    if hostingView == nil {
      // Default autoresizing on so the hosting view tracks the panel's content rect.
      let hosting = NSHostingView(rootView: view)
      hostingView = hosting
    } else {
      // Keep observing the same viewModel; just refresh the cancel handler.
      hostingView?.rootView = view
    }
    if let hostingView = hostingView, window?.contentView !== hostingView {
      window?.contentView = hostingView
    }
  }

  private func fitWindowSize(animated: Bool) {
    guard let window = window, let hosting = hostingView else { return }
    hosting.layoutSubtreeIfNeeded()
    let target = hosting.fittingSize
    if abs(target.width - lastFittingSize.width) < 0.5
      && abs(target.height - lastFittingSize.height) < 0.5
    {
      return
    }
    lastFittingSize = target
    let origin = originForResize(to: target, in: window)
    let frame = NSRect(origin: origin, size: target)
    window.setFrame(frame, display: true, animate: animated && !reduceMotion)
  }

  // MARK: Show / hide animations

  private func animateIn() {
    guard let window = window, let hosting = hostingView else { return }
    transitionID += 1
    hosting.layoutSubtreeIfNeeded()
    let target = computeOrigin(for: hosting.fittingSize)

    if window.isVisible && !isVisible {
      window.alphaValue = 1
      window.setFrameOrigin(target)
      window.orderFrontRegardless()
      isVisible = true
      return
    }

    if reduceMotion {
      window.setFrameOrigin(target)
      window.alphaValue = 1
      window.orderFrontRegardless()
      isVisible = true
      return
    }

    window.setFrameOrigin(NSPoint(x: target.x, y: target.y - 6))
    window.alphaValue = 0
    window.orderFrontRegardless()

    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.28
      ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.3, 1.0)
      window.animator().alphaValue = 1
      window.animator().setFrameOrigin(target)
    }
    isVisible = true
  }

  private func animateOut() {
    guard let window = window, isVisible else { return }
    isVisible = false
    transitionID += 1
    let token = transitionID

    if reduceMotion {
      window.alphaValue = 0
      window.orderOut(nil)
      viewModel.state = .hidden
      viewModel.resetSamples()
      cancelHandler = nil
      return
    }

    let startOrigin = window.frame.origin
    NSAnimationContext.runAnimationGroup(
      { ctx in
        ctx.duration = 0.18
        ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
        window.animator().alphaValue = 0
        window.animator().setFrameOrigin(NSPoint(x: startOrigin.x, y: startOrigin.y - 4))
      },
      completionHandler: { [weak self] in
        guard let self = self else { return }
        guard token == self.transitionID else {
          if self.isVisible, let hosting = self.hostingView {
            hosting.layoutSubtreeIfNeeded()
            window.alphaValue = 1
            window.setFrameOrigin(self.computeOrigin(for: hosting.fittingSize))
            window.orderFrontRegardless()
          }
          return
        }
        if !self.isVisible {
          window.orderOut(nil)
          window.setFrameOrigin(startOrigin)
          self.viewModel.state = .hidden
          self.viewModel.resetSamples()
          self.cancelHandler = nil
        }
      }
    )
  }

  private func computeOrigin(for size: NSSize) -> NSPoint {
    guard let screen = NSScreen.main else { return .zero }
    let screenRect = screen.visibleFrame
    let padding: CGFloat = 16

    switch position {
    case .topRight:
      return NSPoint(
        x: screenRect.maxX - size.width - padding,
        y: screenRect.maxY - size.height - padding
      )
    case .bottomRight:
      return NSPoint(
        x: screenRect.maxX - size.width - padding,
        y: screenRect.minY + padding
      )
    case .topLeft:
      return NSPoint(
        x: screenRect.minX + padding,
        y: screenRect.maxY - size.height - padding
      )
    case .bottomLeft:
      return NSPoint(
        x: screenRect.minX + padding,
        y: screenRect.minY + padding
      )
    case .centerTop:
      return NSPoint(
        x: screenRect.midX - size.width / 2,
        y: screenRect.maxY - size.height - padding
      )
    }
  }

  private func originForResize(to size: NSSize, in window: NSWindow) -> NSPoint {
    guard isVisible, window.isVisible, lastFittingSize != .zero else {
      return computeOrigin(for: size)
    }
    guard let screen = window.screen ?? NSScreen.main else {
      return computeOrigin(for: size)
    }

    let screenRect = screen.visibleFrame
    let padding: CGFloat = 16
    let xPosition: CGFloat
    switch position {
    case .topRight, .bottomRight:
      xPosition = screenRect.maxX - size.width - padding
    case .topLeft, .bottomLeft:
      xPosition = screenRect.minX + padding
    case .centerTop:
      xPosition = screenRect.midX - size.width / 2
    }

    let centeredY = window.frame.midY - size.height / 2
    let minY = screenRect.minY + padding
    let maxY = screenRect.maxY - size.height - padding
    return NSPoint(x: xPosition, y: min(max(centeredY, minY), maxY))
  }
}
