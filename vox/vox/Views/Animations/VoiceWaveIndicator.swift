import AppKit
import SwiftUI

// MARK: - Voice Wave (compact pill preview)
// The real experience is the full-screen bottom wave (VoiceWaveWindow.swift);
// this tiny variant only exists so the style has a pill representation.

struct VoiceWaveIndicator: View {
  let samples: [AudioSample]
  let phase: IndicatorPhase

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      Canvas { context, size in
        let time = timeline.date.timeIntervalSinceReferenceDate
        let level = phase == .listening ? max(0.12, latestLevel(samples)) : 0.4
        let colors = palette
        let baseY = size.height * 0.62
        let amp = 2.0 + level * (size.height * 0.22)

        var path = Path()
        let step: CGFloat = 3
        for x in stride(from: CGFloat(0), through: size.width, by: step) {
          let s = sin(Double(x) * 0.16 + time * 3.0) + 0.4 * sin(Double(x) * 0.34 - time * 2.0)
          let y = baseY - CGFloat(s) * amp
          if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        var glow = context
        glow.addFilter(.blur(radius: 2.4))
        glow.stroke(path, with: .color(colors[0].opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.stroke(
          path,
          with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: 0)),
          style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
      }
    }
    .frame(width: 34, height: 24)
    .accessibilityLabel("Voice wave")
  }

  private var palette: [Color] {
    switch phase {
    case .listening: return [Color(red: 0.34, green: 0.88, blue: 1.0), Color(red: 0.40, green: 0.60, blue: 1.0)]
    case .transcribing: return [Color(red: 0.36, green: 0.64, blue: 1.0), Color(red: 0.50, green: 0.50, blue: 1.0)]
    case .success: return [Color(red: 0.34, green: 0.90, blue: 0.56), Color(red: 0.52, green: 1.0, blue: 0.80)]
    case .error: return [Color(red: 1.0, green: 0.70, blue: 0.32), Color(red: 1.0, green: 0.52, blue: 0.28)]
    }
  }
}
