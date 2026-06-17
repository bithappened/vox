import AppKit
import SwiftUI

final class VoiceWaveModel: ObservableObject {
  @Published var level: CGFloat = 0
  @Published var phase: IndicatorPhase = .listening
  @Published var phaseChangedAt: TimeInterval = Date().timeIntervalSinceReferenceDate
}

final class VoiceWaveWindowController: NSObject {
  private let model = VoiceWaveModel()
  private var panels: [NSPanel] = []
  private var smoothedLevel: CGFloat = 0
  private var isShowing = false
  private var screenObserver: NSObjectProtocol?
  private var hideWorkItem: DispatchWorkItem?

  override init() {
    super.init()
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.rebuildForCurrentScreens()
    }
  }

  deinit {
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
    }
  }

  func show(phase: IndicatorPhase = .listening) {
    hideWorkItem?.cancel()
    hideWorkItem = nil
    updateModelPhase(phase)
    isShowing = true
    ensurePanels()
    panels.forEach { panel in
      panel.orderFrontRegardless()
      animate(panel: panel, alpha: 1, duration: 0.24)
    }
  }

  func hide() {
    hideWorkItem?.cancel()
    hideWorkItem = nil
    guard isShowing || !panels.isEmpty else { return }
    isShowing = false
    smoothedLevel = 0
    model.level = 0

    panels.forEach { panel in
      animate(panel: panel, alpha: 0, duration: 0.20) {
        if !self.isShowing {
          panel.orderOut(nil)
        }
      }
    }
  }

  func hide(after delay: TimeInterval) {
    hideWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.hide()
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  func setPhase(_ phase: IndicatorPhase) {
    guard isShowing else {
      show(phase: phase)
      return
    }
    hideWorkItem?.cancel()
    hideWorkItem = nil
    updateModelPhase(phase)
  }

  func update(level: Float) {
    guard isShowing else { return }
    let clamped = CGFloat(max(0, min(1, level)))
    smoothedLevel = smoothedLevel * 0.68 + clamped * 0.32
    model.level = smoothedLevel
  }

  private func ensurePanels() {
    guard panels.isEmpty else { return }
    panels = NSScreen.screens.map(makePanel(for:))
  }

  private func updateModelPhase(_ phase: IndicatorPhase) {
    model.phase = phase
    model.phaseChangedAt = Date().timeIntervalSinceReferenceDate
  }

  private func rebuildForCurrentScreens() {
    panels.forEach { $0.orderOut(nil) }
    panels.removeAll()
    guard isShowing else { return }
    ensurePanels()
    panels.forEach { panel in
      panel.alphaValue = 1
      panel.orderFrontRegardless()
    }
  }

  private func makePanel(for screen: NSScreen) -> NSPanel {
    let panel = NSPanel(
      contentRect: screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.alphaValue = 0

    let hostingView = NSHostingView(rootView: VoiceWaveScreenView(model: model))
    hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView
    return panel
  }

  private func animate(panel: NSPanel, alpha: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      panel.alphaValue = alpha
      completion?()
      return
    }

    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: alpha > panel.alphaValue ? .easeOut : .easeIn)
        panel.animator().alphaValue = alpha
      },
      completionHandler: completion
    )
  }
}

// MARK: - Screen view

/// A subtle glowing wave ribbon along the bottom of the screen. It always flows
/// (time-driven) with a visible resting amplitude, so it never disappears when
/// you pause — voice level only adds to it. Each phase reads distinctly:
/// listening (cool, voice-reactive), transcribing (a comet glides the crest),
/// success (green swell), error (amber).
private struct VoiceWaveScreenView: View {
  @ObservedObject var model: VoiceWaveModel

  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      Canvas { context, size in
        var ctx = context
        draw(in: &ctx, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
    guard size.width > 0, size.height > 0 else { return }
    let resp = response(time: time)
    let pal = palette(for: model.phase)
    let baseY = size.height - 44
    drawBottomVignette(in: &context, size: size)
    for layer in stride(from: 2, through: 0, by: -1) {
      drawRibbon(in: &context, size: size, baseY: baseY, layer: layer, resp: resp, pal: pal, time: time)
    }
    if model.phase == .transcribing, !reduceMotion {
      drawProcessingComet(in: &context, size: size, baseY: baseY, resp: resp, pal: pal, time: time)
    }
  }

  private func drawBottomVignette(in context: inout GraphicsContext, size: CGSize) {
    let band: CGFloat = 64
    context.fill(
      Path(CGRect(x: 0, y: size.height - band, width: size.width, height: band)),
      with: .linearGradient(Gradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: Color.black.opacity(0.10), location: 1)]),
        startPoint: CGPoint(x: 0, y: size.height - band), endPoint: CGPoint(x: 0, y: size.height)))
  }

  private func drawRibbon(
    in context: inout GraphicsContext, size: CGSize, baseY: CGFloat,
    layer: Int, resp: CGFloat, pal: [Color], time: TimeInterval
  ) {
    let color = pal[layer % pal.count]
    let layerOffset = CGFloat(layer) * 8
    let breath = reduceMotion ? 0 : CGFloat((sin(time * (2 * .pi / 4.5)) + 1) / 2)
    let amp = (6 + breath * 3 + resp * 24) * (1.0 - CGFloat(layer) * 0.16)
    let speed = (reduceMotion ? 0 : 0.7) + Double(layer) * 0.13
    let top = wavePath(size: size, baseY: baseY - layerOffset, amp: amp, speed: speed, phaseOffset: Double(layer) * 1.3, time: time)

    var fill = top
    fill.addLine(to: CGPoint(x: size.width, y: size.height))
    fill.addLine(to: CGPoint(x: 0, y: size.height))
    fill.closeSubpath()
    // The fill fades IN below the crest (clear at the top) so there is no hard
    // boundary where the ribbon meets the wallpaper.
    let topOp = (0.15 + resp * 0.12) * (1.0 - CGFloat(layer) * 0.22)
    context.fill(fill, with: .linearGradient(
      Gradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: color.opacity(topOp), location: 0.35),
        .init(color: color.opacity(topOp * 0.30), location: 0.75),
        .init(color: color.opacity(0.01), location: 1)]),
      startPoint: CGPoint(x: 0, y: baseY - amp - 8), endPoint: CGPoint(x: 0, y: size.height)))

    // Crest — soft blurred glow only, never a hard line.
    let dim = 1.0 - CGFloat(layer) * 0.2
    var wide = context
    wide.addFilter(.blur(radius: 10))
    wide.stroke(top, with: .color(color.opacity((0.16 + resp * 0.16) * dim)),
                style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
    if layer == 0 {
      var mid = context
      mid.addFilter(.blur(radius: 3.5))
      mid.stroke(top, with: .color(color.opacity(0.34 + resp * 0.24)),
                 style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
  }

  private func wavePath(size: CGSize, baseY: CGFloat, amp: CGFloat, speed: Double, phaseOffset: Double, time: TimeInterval) -> Path {
    var path = Path()
    let step: CGFloat = 6
    for x in stride(from: CGFloat(-step), through: size.width + step, by: step) {
      let s = sin(Double(x) * 0.0055 + time * speed + phaseOffset)
        + 0.42 * sin(Double(x) * 0.0123 - time * speed * 0.7 + phaseOffset * 1.4)
      let y = baseY - CGFloat(s) * amp * 0.7
      if x <= -step { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    return path
  }

  private func drawProcessingComet(in context: inout GraphicsContext, size: CGSize, baseY: CGFloat, resp: CGFloat, pal: [Color], time: TimeInterval) {
    let span = size.width + 160
    let x = (time * 260).truncatingRemainder(dividingBy: span) - 80
    let s = sin(Double(x) * 0.0055 + time * 0.7) + 0.42 * sin(Double(x) * 0.0123 - time * 0.49)
    let y = baseY - CGFloat(s) * (6 + resp * 24) * 0.7
    let color = pal[0]
    var g = context
    g.addFilter(.blur(radius: 7))
    g.fill(Path(ellipseIn: CGRect(x: x - 14, y: y - 14, width: 28, height: 28)), with: .color(color.opacity(0.5)))
    context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                 with: .radialGradient(Gradient(colors: [.white, color]), center: CGPoint(x: x, y: y), startRadius: 0.3, endRadius: 4))
  }

  private func response(time: TimeInterval) -> CGFloat {
    switch model.phase {
    case .listening:
      return min(1, model.level)
    case .transcribing:
      return 0.34 + (reduceMotion ? 0 : CGFloat((sin(time * 1.6) + 1) / 2) * 0.14)
    case .success:
      let age = time - model.phaseChangedAt
      let swell = max(0, 1 - CGFloat(age / 0.8)) * 0.4
      return 0.5 + swell + (reduceMotion ? 0 : CGFloat((sin(time * 2.4) + 1) / 2) * 0.08)
    case .error:
      return 0.44 + (reduceMotion ? 0 : CGFloat((sin(time * 6.0) + 1) / 2) * 0.16)
    }
  }

  private func palette(for phase: IndicatorPhase) -> [Color] {
    switch phase {
    case .listening:
      return [Color(red: 0.34, green: 0.88, blue: 1.0), Color(red: 0.40, green: 0.60, blue: 1.0), Color(red: 0.30, green: 0.84, blue: 0.95)]
    case .transcribing:
      return [Color(red: 0.36, green: 0.64, blue: 1.0), Color(red: 0.50, green: 0.50, blue: 1.0), Color(red: 0.32, green: 0.80, blue: 1.0)]
    case .success:
      return [Color(red: 0.34, green: 0.90, blue: 0.56), Color(red: 0.52, green: 1.0, blue: 0.80), Color(red: 0.34, green: 0.86, blue: 0.74)]
    case .error:
      return [Color(red: 1.0, green: 0.70, blue: 0.32), Color(red: 1.0, green: 0.52, blue: 0.28), Color(red: 1.0, green: 0.80, blue: 0.38)]
    }
  }
}
