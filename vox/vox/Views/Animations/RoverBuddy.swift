import AppKit
import SwiftUI

// MARK: - Rover Buddy (app wrapper)

struct RoverBuddyIndicator: View {
  let samples: [AudioSample]
  let phase: IndicatorPhase

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appearTime = Date().timeIntervalSinceReferenceDate

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let now = timeline.date.timeIntervalSinceReferenceDate
      RoverBuddyContent(
        time: now,
        level: Self.voiceEnvelope(samples, now: now),
        phase: phase,
        age: now - appearTime,
        reduceMotion: reduceMotion
      )
    }
    .frame(width: 132, height: 134)
    .accessibilityLabel(accessibilityLabel)
    .onAppear { appearTime = Date().timeIntervalSinceReferenceDate }
  }

  private var accessibilityLabel: String {
    switch phase {
    case .listening: return "Recording — Rover Buddy listening"
    case .transcribing: return "Transcribing — Rover Buddy thinking"
    case .success: return "Copied — Rover Buddy"
    case .error: return "Error — Rover Buddy"
    }
  }

  private static func voiceEnvelope(_ samples: [AudioSample], now: TimeInterval) -> CGFloat {
    var env: CGFloat = 0
    var sawAny = false
    for sample in samples where now - sample.time < 0.6 {
      sawAny = true
      let level = CGFloat(max(0, min(1, sample.level)))
      env += (level - env) * (level > env ? 0.45 : 0.12)
    }
    return sawAny ? pow(env, 0.7) : 0
  }
}

// MARK: - Palette (single warm hero-lit material)

private enum Rover {
  static let hi = Color(red: 1.0, green: 0.92, blue: 0.70)
  static let lite = Color(red: 1.0, green: 0.76, blue: 0.36)
  static let base = Color(red: 0.97, green: 0.57, blue: 0.20)
  static let dark = Color(red: 0.78, green: 0.38, blue: 0.14)
  static let deep = Color(red: 0.55, green: 0.20, blue: 0.16)   // colored shadow, not mud
  static let bounce = Color(red: 1.0, green: 0.80, blue: 0.52)  // warm ground bounce
  static let warmRim = Color(red: 1.0, green: 0.95, blue: 0.82)
  static let coolRim = Color(red: 0.78, green: 0.90, blue: 1.0)
}

// MARK: - Rover Buddy (pure content)

struct RoverBuddyContent: View {
  var time: TimeInterval
  var level: CGFloat
  var phase: IndicatorPhase
  var age: TimeInterval
  var reduceMotion: Bool = false

  var body: some View {
    Canvas { context, size in
      render(into: &context, size: size)
    }
    .frame(width: 132, height: 134)
  }

  private var accent: Color {
    switch phase {
    case .listening: return Color(red: 0.30, green: 0.93, blue: 0.96)
    case .transcribing: return Color(red: 0.46, green: 0.70, blue: 1.0)
    case .success: return Color(red: 0.40, green: 0.92, blue: 0.56)
    case .error: return Color(red: 1.0, green: 0.64, blue: 0.26)
    }
  }

  // MARK: Orchestration

  private func render(into context: inout GraphicsContext, size: CGSize) {
    let m = motion()
    let baseX = size.width / 2 + m.shake
    let groundY = size.height - 22
    let headCenter = CGPoint(x: baseX, y: size.height * 0.40 - m.lift)
    let bodyCenter = CGPoint(x: baseX, y: size.height * 0.62 - m.lift * 0.55)

    drawAmbientSeat(into: &context, size: size, center: CGPoint(x: baseX, y: size.height * 0.52))
    drawDropShadow(into: &context, headCenter: headCenter, bodyCenter: bodyCenter)
    drawContactShadow(into: &context, centerX: baseX, groundY: groundY, lift: m.lift)

    drawAntenna(into: &context, headCenter: headCenter, m: m)
    drawBody(into: &context, center: bodyCenter)

    var head = context
    head.translateBy(x: headCenter.x, y: headCenter.y)
    head.rotate(by: .degrees(m.tilt))
    head.scaleBy(x: m.squashX, y: m.squashY)
    drawHead(into: &head, half: CGSize(width: 33, height: 29))
    drawFace(into: &head)

    drawPhaseFX(into: &context, headCenter: headCenter)
  }

  // MARK: Motion

  private struct Motion {
    var lift: CGFloat; var tilt: Double; var squashX: CGFloat; var squashY: CGFloat
    var shake: CGFloat; var antennaSway: CGFloat
  }

  private func motion() -> Motion {
    guard !reduceMotion else {
      return Motion(lift: 0, tilt: 0, squashX: 1, squashY: 1, shake: 0, antennaSway: 0)
    }
    let breath = sin(time * (2 * .pi / 4.0))
    let lift = sin(time * 1.7) * 1.1 + level * 5.0 + breath * 0.6
    let tilt = sin(time * 0.9) * (1.4 + Double(level) * 2.2)
    let s = 1 + breath * 0.018 + level * 0.05
    let antennaSway = sin(time * 1.7 - 0.7) * (1.0 + level * 2.4)
    var shake: CGFloat = 0
    if phase == .error, age < 0.45 { shake = CGFloat(sin(age * 58) * 3.0 * exp(-age * 7)) }
    var pop: CGFloat = 1
    if phase == .success, age < 0.7 {
      pop = 1 + 0.13 * CGFloat(sin(min(age, 0.6) / 0.6 * .pi)) * CGFloat(exp(-age * 1.4))
    }
    return Motion(lift: lift, tilt: tilt, squashX: (1 / (s * 0.5 + 0.5)) * pop, squashY: s * pop,
                  shake: shake, antennaSway: antennaSway)
  }

  // MARK: Seat + shadows (replace the bounding pill)

  private func drawAmbientSeat(into context: inout GraphicsContext, size: CGSize, center: CGPoint) {
    var g = context
    g.addFilter(.blur(radius: 14))
    let r = size.width * 0.46
    g.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.82, width: r * 2, height: r * 1.64)),
           with: .radialGradient(Gradient(colors: [Color(red: 1.0, green: 0.72, blue: 0.42).opacity(0.10), .clear]),
                                 center: center, startRadius: 2, endRadius: r))
  }

  private func drawDropShadow(into context: inout GraphicsContext, headCenter: CGPoint, bodyCenter: CGPoint) {
    var g = context
    g.addFilter(.blur(radius: 7))
    let col = Color.black.opacity(0.16)
    g.fill(Path(roundedRect: CGRect(x: headCenter.x - 34, y: headCenter.y - 28, width: 68, height: 62), cornerRadius: 26, style: .continuous), with: .color(col))
    g.fill(Path(ellipseIn: CGRect(x: bodyCenter.x - 26, y: bodyCenter.y - 14, width: 52, height: 30)), with: .color(col))
  }

  private func drawContactShadow(into context: inout GraphicsContext, centerX: CGFloat, groundY: CGFloat, lift: CGFloat) {
    let spread = 1 + max(0, lift) * 0.03
    let fade = 1 - min(0.4, max(0, lift) * 0.03)
    var penumbra = context
    penumbra.addFilter(.blur(radius: 7))
    penumbra.fill(Path(ellipseIn: CGRect(x: centerX - 34 * spread, y: groundY - 7, width: 68 * spread, height: 14)),
                  with: .color(Color(red: 0.10, green: 0.04, blue: 0.0).opacity(0.22 * fade)))
    var core = context
    core.addFilter(.blur(radius: 3))
    core.fill(Path(ellipseIn: CGRect(x: centerX - 20 * spread, y: groundY - 4.5, width: 40 * spread, height: 9)),
              with: .color(Color(red: 0.10, green: 0.04, blue: 0.0).opacity(0.30 * fade)))
  }

  // MARK: Antenna

  private func drawAntenna(into context: inout GraphicsContext, headCenter: CGPoint, m: Motion) {
    let baseP = CGPoint(x: headCenter.x, y: headCenter.y - 27)
    let tip = CGPoint(x: headCenter.x + m.antennaSway, y: headCenter.y - 27 - 12)
    var stalk = Path()
    stalk.move(to: baseP)
    stalk.addQuadCurve(to: tip, control: CGPoint(x: (baseP.x + tip.x) / 2 - m.antennaSway * 0.4, y: (baseP.y + tip.y) / 2))
    context.stroke(stalk, with: .linearGradient(
      Gradient(colors: [Rover.dark, Rover.lite]), startPoint: baseP, endPoint: tip),
      style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

    let pulse = reduceMotion ? 0.5 : (sin(time * (phase == .transcribing ? 6.0 : 3.2)) + 1) / 2
    let glowR = 7.0 + level * 5 + pulse * 2
    var g = context
    g.addFilter(.blur(radius: 4))
    g.fill(Path(ellipseIn: CGRect(x: tip.x - glowR, y: tip.y - glowR, width: glowR * 2, height: glowR * 2)),
           with: .radialGradient(Gradient(colors: [accent.opacity(0.7 + level * 0.2), .clear]), center: tip, startRadius: 1, endRadius: glowR))
    let coreR = 3.4 + level * 1.2
    context.fill(Path(ellipseIn: CGRect(x: tip.x - coreR, y: tip.y - coreR, width: coreR * 2, height: coreR * 2)),
                 with: .radialGradient(Gradient(colors: [.white, accent]), center: CGPoint(x: tip.x - 0.8, y: tip.y - 0.8), startRadius: 0.2, endRadius: coreR))
  }

  // MARK: Body / chassis

  private func drawBody(into context: inout GraphicsContext, center: CGPoint) {
    for sx in [-1.0, 1.0] {
      let wc = CGPoint(x: center.x + CGFloat(sx) * 17, y: center.y + 9)
      let wheel = Path(ellipseIn: CGRect(x: wc.x - 8.5, y: wc.y - 8.5, width: 17, height: 17))
      context.fill(wheel, with: .radialGradient(Gradient(colors: [Color(red: 0.40, green: 0.28, blue: 0.20), Color(red: 0.12, green: 0.07, blue: 0.05)]),
                                                center: CGPoint(x: wc.x - 2.5, y: wc.y - 3.5), startRadius: 1, endRadius: 14))
      // Top rim + hub highlight so wheels read as glossy, not flat blobs.
      context.stroke(wheel, with: .linearGradient(Gradient(stops: [.init(color: Rover.warmRim.opacity(0.5), location: 0), .init(color: .clear, location: 0.5)]),
                                                  startPoint: CGPoint(x: wc.x, y: wc.y - 8.5), endPoint: CGPoint(x: wc.x, y: wc.y + 8.5)), lineWidth: 1)
      context.fill(Path(ellipseIn: CGRect(x: wc.x - 2.8, y: wc.y - 3.6, width: 4.4, height: 4.4)), with: .color(Color.white.opacity(0.45)))
    }

    let rect = CGRect(x: center.x - 23, y: center.y - 12, width: 46, height: 26)
    let shape = Path(roundedRect: rect, cornerRadius: 13, style: .continuous)
    // Volume — same hero light as the head, kept bright.
    context.fill(shape, with: .radialGradient(
      Gradient(stops: [
        .init(color: Rover.hi, location: 0.0), .init(color: Rover.lite, location: 0.40),
        .init(color: Rover.base, location: 0.80), .init(color: Rover.dark, location: 1.0)]),
      center: CGPoint(x: center.x - 11, y: rect.minY + 2), startRadius: 1, endRadius: 34))
    // AO where the head sits on top.
    var ao = context; ao.clip(to: shape)
    ao.addFilter(.blur(radius: 2))
    ao.fill(Path(ellipseIn: CGRect(x: center.x - 20, y: rect.minY - 14, width: 40, height: 20)),
            with: .radialGradient(Gradient(colors: [Rover.deep.opacity(0.42), .clear]), center: CGPoint(x: center.x, y: rect.minY + 1), startRadius: 1, endRadius: 18))
    // Top rim (key) + warm bottom bounce + crisp spec.
    context.stroke(shape, with: .linearGradient(
      Gradient(stops: [.init(color: Rover.warmRim.opacity(0.6), location: 0), .init(color: .clear, location: 0.5)]),
      startPoint: CGPoint(x: center.x, y: rect.minY), endPoint: CGPoint(x: center.x, y: rect.maxY)),
      style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    context.stroke(shape, with: .linearGradient(
      Gradient(stops: [.init(color: .clear, location: 0.62), .init(color: Rover.bounce.opacity(0.4), location: 1.0)]),
      startPoint: CGPoint(x: center.x, y: rect.minY), endPoint: CGPoint(x: center.x, y: rect.maxY)),
      style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    context.fill(Path(ellipseIn: CGRect(x: center.x - 14, y: rect.minY + 3, width: 6, height: 3.5)), with: .color(Color.white.opacity(0.7)))

    drawCoreVent(into: &context, center: center)
  }

  private func drawCoreVent(into context: inout GraphicsContext, center: CGPoint) {
    let slot = CGRect(x: center.x - 12, y: center.y - 5, width: 24, height: 10)
    let slotShape = Path(roundedRect: slot, cornerRadius: 5, style: .continuous)
    context.fill(slotShape, with: .linearGradient(Gradient(colors: [Color(red: 0.10, green: 0.05, blue: 0.03), Color(red: 0.20, green: 0.11, blue: 0.06)]),
                                                  startPoint: CGPoint(x: 0, y: slot.minY), endPoint: CGPoint(x: 0, y: slot.maxY)))
    var glow = context; glow.clip(to: slotShape)
    glow.addFilter(.blur(radius: 2))
    let n = 5
    for i in 0..<n {
      let ph = reduceMotion ? 0.5 : (sin(time * (phase == .transcribing ? 7.0 : 5.0) + Double(i) * 0.7) + 1) / 2
      let hgt = 2.0 + (phase == .listening ? level : 0.4) * (3.5 + CGFloat(ph) * 4.0)
      let x = slot.minX + 3.5 + CGFloat(i) * 4.3
      glow.fill(Path(roundedRect: CGRect(x: x, y: center.y - hgt / 2, width: 2.4, height: hgt), cornerRadius: 1.2, style: .continuous),
                with: .color(accent.opacity(0.7 + CGFloat(ph) * 0.3)))
    }
  }

  // MARK: Head — hero volume

  private func drawHead(into context: inout GraphicsContext, half: CGSize) {
    let rect = CGRect(x: -half.width, y: -half.height, width: half.width * 2, height: half.height * 2)
    let shape = Path(roundedRect: rect, cornerRadius: 24, style: .continuous)

    context.fill(shape, with: .radialGradient(
      Gradient(stops: [
        .init(color: Rover.hi, location: 0.0), .init(color: Rover.lite, location: 0.30),
        .init(color: Rover.base, location: 0.60), .init(color: Rover.dark, location: 0.86),
        .init(color: Rover.deep, location: 1.0)]),
      center: CGPoint(x: -half.width * 0.40, y: -half.height * 0.44), startRadius: 2, endRadius: half.width * 2.5))

    var ao = context; ao.clip(to: shape)
    ao.fill(Path(rect), with: .linearGradient(
      Gradient(stops: [.init(color: .clear, location: 0.62), .init(color: Rover.deep.opacity(0.30), location: 1.0)]),
      startPoint: CGPoint(x: 0, y: -half.height), endPoint: CGPoint(x: 0, y: half.height)))

    var cast = context; cast.clip(to: shape)
    cast.addFilter(.blur(radius: 5))
    cast.fill(Path(ellipseIn: CGRect(x: -12, y: -half.height - 2, width: 24, height: 18)),
              with: .radialGradient(Gradient(colors: [accent.opacity(0.22 + level * 0.12), .clear]), center: CGPoint(x: 0, y: -half.height + 4), startRadius: 1, endRadius: 16))

    var sheen = context; sheen.clip(to: shape)
    sheen.addFilter(.blur(radius: 4))
    sheen.fill(Path(ellipseIn: CGRect(x: -half.width * 0.74, y: -half.height * 0.82, width: 30, height: 20)), with: .color(Color.white.opacity(0.30)))
    // Crisp glossy hotspot.
    context.fill(Path(ellipseIn: CGRect(x: -half.width * 0.50, y: -half.height * 0.58, width: 7.5, height: 5)), with: .color(Color.white.opacity(0.95)))

    // Warm rim (key) on the upper-left edge.
    context.stroke(shape, with: .linearGradient(
      Gradient(stops: [.init(color: Rover.warmRim.opacity(0.78), location: 0.0), .init(color: Rover.warmRim.opacity(0.15), location: 0.45), .init(color: .clear, location: 0.75)]),
      startPoint: CGPoint(x: -half.width * 0.4, y: -half.height), endPoint: CGPoint(x: half.width * 0.2, y: half.height)),
      style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    // Warm bounce kicking up from the body along the bottom edge.
    context.stroke(shape, with: .linearGradient(
      Gradient(stops: [.init(color: .clear, location: 0.58), .init(color: Rover.bounce.opacity(0.45), location: 1.0)]),
      startPoint: CGPoint(x: 0, y: -half.height), endPoint: CGPoint(x: 0, y: half.height)),
      style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    // Cool fresnel kiss, right edge only.
    var coolRim = context
    coolRim.clip(to: shape)
    coolRim.clip(to: Path(CGRect(x: half.width * 0.15, y: -half.height - 2, width: half.width, height: half.height * 2 + 4)))
    coolRim.stroke(shape, with: .color(Rover.coolRim.opacity(0.40)), style: StrokeStyle(lineWidth: 2.2))
  }

  // MARK: Face

  private func drawFace(into context: inout GraphicsContext) {
    let visor = CGRect(x: -24, y: -16, width: 48, height: 28)
    let visorShape = Path(roundedRect: visor, cornerRadius: 14, style: .continuous)

    context.fill(visorShape, with: .radialGradient(
      Gradient(colors: [Color(red: 0.16, green: 0.19, blue: 0.24), Color(red: 0.03, green: 0.04, blue: 0.06)]),
      center: CGPoint(x: 0, y: -4), startRadius: 1, endRadius: 30))
    context.stroke(visorShape, with: .color(Rover.deep.opacity(0.5)), lineWidth: 1.6)
    var sheen = context; sheen.clip(to: visorShape)
    sheen.addFilter(.blur(radius: 1.5))
    var arc = Path()
    arc.move(to: CGPoint(x: -20, y: -8))
    arc.addQuadCurve(to: CGPoint(x: 20, y: -8), control: CGPoint(x: 0, y: -18))
    sheen.stroke(arc, with: .color(Color.white.opacity(0.16)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    context.stroke(visorShape, with: .color(Color.white.opacity(0.14)), lineWidth: 0.7)

    drawEyes(into: &context)
    drawMouth(into: &context)

    if phase == .transcribing, !reduceMotion {
      var scan = context; scan.clip(to: visorShape)
      let sweep = CGFloat((time.truncatingRemainder(dividingBy: 1.5)) / 1.5)
      let x = visor.minX + sweep * visor.width
      scan.addFilter(.blur(radius: 2.4))
      scan.fill(Path(CGRect(x: x - 4, y: visor.minY, width: 8, height: visor.height)),
                with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.5), .clear]),
                                      startPoint: CGPoint(x: x - 4, y: 0), endPoint: CGPoint(x: x + 4, y: 0)))
    }
  }

  private func blink() -> CGFloat {
    guard !reduceMotion else { return 1 }
    let t = time.truncatingRemainder(dividingBy: 4.6)
    if t < 0.09 { return 1 - (t / 0.09) }
    if t < 0.24 { return (t - 0.09) / 0.15 }
    return 1
  }

  private func drawEyes(into context: inout GraphicsContext) {
    let spacing: CGFloat = 11.5
    if phase == .success {
      for sx in [-1.0, 1.0] {
        let cx = CGFloat(sx) * spacing
        var arc = Path()
        arc.move(to: CGPoint(x: cx - 6.5, y: 0)); arc.addQuadCurve(to: CGPoint(x: cx + 6.5, y: 0), control: CGPoint(x: cx, y: -7.5))
        var g = context; g.addFilter(.blur(radius: 2.5))
        g.stroke(arc, with: .color(accent.opacity(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        context.stroke(arc, with: .color(accent), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
      }
      return
    }
    if phase == .error {
      for (i, sx) in [-1.0, 1.0].enumerated() {
        let cx = CGFloat(sx) * spacing
        let eyeRect = CGRect(x: cx - 6, y: -1.5, width: 12, height: 6.5)
        context.fill(Path(roundedRect: eyeRect, cornerRadius: 3, style: .continuous),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.5), Color(red: 0.05, green: 0.06, blue: 0.08)]), center: CGPoint(x: cx, y: 1), startRadius: 0.5, endRadius: 9))
        var brow = Path()
        brow.move(to: CGPoint(x: cx + CGFloat(i == 0 ? 5 : -5), y: -8)); brow.addLine(to: CGPoint(x: cx + CGFloat(i == 0 ? -5 : 5), y: -6))
        context.stroke(brow, with: .color(accent.opacity(0.9)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
      }
      return
    }

    let open = blink()
    let baseH: CGFloat = phase == .transcribing ? 11 : 13.5 + level * 2
    let eyeH = max(1.6, baseH * open)
    let eyeW: CGFloat = 13
    let lookY: CGFloat = phase == .transcribing ? -1.5 + CGFloat(sin(time * 2.2)) * 0.8 : 0
    for sx in [-1.0, 1.0] {
      let cx = CGFloat(sx) * spacing
      let eyeRect = CGRect(x: cx - eyeW / 2, y: -eyeH / 2 + lookY, width: eyeW, height: eyeH)
      let eyeShape = Path(roundedRect: eyeRect, cornerRadius: min(6.5, eyeH / 2), style: .continuous)
      if eyeH > 8 {
        var bloom = context; bloom.addFilter(.blur(radius: 3.5))
        bloom.fill(eyeShape, with: .color(accent.opacity(0.35)))
      }
      context.fill(eyeShape, with: .radialGradient(
        Gradient(stops: [.init(color: Color.white.opacity(0.95), location: 0.0), .init(color: accent, location: 0.35), .init(color: accent.opacity(0.7), location: 0.7), .init(color: Color(red: 0.02, green: 0.05, blue: 0.08), location: 1.0)]),
        center: CGPoint(x: cx - 1.5, y: lookY - eyeH * 0.18), startRadius: 0.4, endRadius: eyeW * 0.9))
      if open > 0.5 && eyeH > 8 {
        context.fill(Path(ellipseIn: CGRect(x: cx - 4.0, y: lookY - eyeH * 0.34, width: 4.2, height: 4.2)), with: .color(Color.white.opacity(0.95)))
        context.fill(Path(ellipseIn: CGRect(x: cx + 1.8, y: lookY + eyeH * 0.12, width: 2.0, height: 2.0)), with: .color(Color.white.opacity(0.7)))
      }
    }
  }

  private func drawMouth(into context: inout GraphicsContext) {
    let y: CGFloat = 7
    var path = Path()
    switch phase {
    case .success:
      path.move(to: CGPoint(x: -5, y: y)); path.addQuadCurve(to: CGPoint(x: 5, y: y), control: CGPoint(x: 0, y: y + 4))
      context.stroke(path, with: .color(Color.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    case .error:
      path.move(to: CGPoint(x: -4, y: y + 1.5)); path.addQuadCurve(to: CGPoint(x: 4, y: y + 1.5), control: CGPoint(x: 0, y: y - 2))
      context.stroke(path, with: .color(Color.white.opacity(0.4)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    default:
      let smile = 1.2 + level * 1.2
      path.move(to: CGPoint(x: -3.5, y: y)); path.addQuadCurve(to: CGPoint(x: 3.5, y: y), control: CGPoint(x: 0, y: y + smile))
      context.stroke(path, with: .color(Color.white.opacity(0.26)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }
  }

  private func drawPhaseFX(into context: inout GraphicsContext, headCenter: CGPoint) {
    guard phase == .success, !reduceMotion else { return }
    if age < 0.8 {
      let r = 20 + age * 44
      let op = (1 - age / 0.8) * 0.5
      context.stroke(Path(ellipseIn: CGRect(x: headCenter.x - r, y: headCenter.y - r, width: r * 2, height: r * 2)),
                     with: .color(accent.opacity(op)), lineWidth: 2.0 * (1 - age / 0.8) + 0.4)
    }
    let n = 7
    for i in 0..<n {
      let a = Double(i) / Double(n) * 2 * .pi + age * 0.6
      let burst = min(1, age / 0.5)
      let dist = 22 + CGFloat(burst) * (16 + CGFloat(i % 3) * 6)
      let p = CGPoint(x: headCenter.x + CGFloat(cos(a)) * dist, y: headCenter.y + CGFloat(sin(a)) * dist * 0.7 - 4)
      let twinkle = (sin(time * 5 + Double(i)) + 1) / 2
      let sz = 1.4 + CGFloat(twinkle) * 1.8
      let fade = max(0, 1 - age / 1.0)
      let col = i.isMultiple(of: 2) ? accent : Color(red: 1.0, green: 0.85, blue: 0.4)
      context.fill(Path(ellipseIn: CGRect(x: p.x - sz / 2, y: p.y - sz / 2, width: sz, height: sz)), with: .color(col.opacity(0.7 * fade)))
    }
  }
}
