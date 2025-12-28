import SwiftUI

// MARK: - Set A: Bars

struct BarsBarConfig {
  let speed: Double
  let phase: Double
  let minScale: CGFloat
  let maxScale: CGFloat
}

struct BarsRecordingView: View {
  let audioLevel: Float
  let color: Color
  let barCount: Int = 5

  private let barConfigs: [BarsBarConfig] = [
    BarsBarConfig(speed: 1.4, phase: 0.0, minScale: 0.25, maxScale: 0.7),
    BarsBarConfig(speed: 1.1, phase: 0.4, minScale: 0.3, maxScale: 0.85),
    BarsBarConfig(speed: 1.0, phase: 0.8, minScale: 0.35, maxScale: 1.0),
    BarsBarConfig(speed: 1.2, phase: 1.2, minScale: 0.3, maxScale: 0.85),
    BarsBarConfig(speed: 1.5, phase: 1.6, minScale: 0.25, maxScale: 0.7)
  ]

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let level = CGFloat(audioLevel)

      HStack(alignment: .center, spacing: 3) {
        ForEach(0..<barCount, id: \.self) { index in
          BarsBarView(
            config: barConfigs[index],
            time: time,
            audioLevel: level,
            color: color
          )
        }
      }
    }
  }
}

private struct BarsBarView: View {
  let config: BarsBarConfig
  let time: TimeInterval
  let audioLevel: CGFloat
  let color: Color

  private let barWidth: CGFloat = 4
  private let maxHeight: CGFloat = 22

  var body: some View {
    let wave = (sin(time * 3.0 * config.speed + config.phase) + 1) / 2
    let ambientHeight = config.minScale + (config.maxScale - config.minScale) * 0.3 * wave
    let audioHeight = config.minScale + (config.maxScale - config.minScale) * audioLevel * (0.6 + 0.4 * wave)
    let blendFactor = min(1.0, audioLevel * 2)
    let finalScale = ambientHeight * (1 - blendFactor) + audioHeight * blendFactor
    let height = maxHeight * finalScale
    let baseOpacity: CGFloat = 0.75
    let loudnessBoost = audioLevel * 0.25
    let opacity = baseOpacity + loudnessBoost

    RoundedRectangle(cornerRadius: 2)
      .fill(color.opacity(opacity))
      .frame(width: barWidth, height: max(4, height))
  }
}

struct BarsTranscribingView: View {
  let color: Color
  let barCount: Int = 5

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate

      HStack(alignment: .center, spacing: 3) {
        ForEach(0..<barCount, id: \.self) { index in
          BarsWaveSweepBarView(index: index, barCount: barCount, time: time, color: color)
        }
      }
    }
  }
}

private struct BarsWaveSweepBarView: View {
  let index: Int
  let barCount: Int
  let time: TimeInterval
  let color: Color

  private let minHeight: CGFloat = 6
  private let maxHeight: CGFloat = 20

  var body: some View {
    let sweepSpeed: Double = 4.0
    let waveWidth: Double = 2.0
    let cycleLength = Double(barCount) + waveWidth
    let wavePosition = (time * sweepSpeed).truncatingRemainder(dividingBy: cycleLength)
    let distanceFromWave = abs(Double(index) - wavePosition)
    let intensity = max(0, 1 - (distanceFromWave / waveWidth))
    let smoothIntensity = intensity * intensity * (3 - 2 * intensity)
    let height = minHeight + (maxHeight - minHeight) * smoothIntensity
    let baseOpacity: CGFloat = 0.5
    let waveOpacity = baseOpacity + (smoothIntensity * 0.45)

    RoundedRectangle(cornerRadius: 2)
      .fill(color.opacity(waveOpacity))
      .frame(width: 4, height: height)
  }
}

struct BarsSuccessView: View {
  @State private var appear = false
  @State private var checkProgress: CGFloat = 0

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.green.opacity(0.3), lineWidth: 2)
        .frame(width: 20, height: 20)

      Circle()
        .trim(from: 0, to: appear ? 1 : 0)
        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(-90))

      BarsCheckmarkShape()
        .trim(from: 0, to: checkProgress)
        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .frame(width: 10, height: 10)
    }
    .scaleEffect(appear ? 1 : 0.7)
    .opacity(appear ? 1 : 0)
    .onAppear {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { appear = true }
      withAnimation(.easeOut(duration: 0.25).delay(0.1)) { checkProgress = 1 }
    }
  }
}

private struct BarsCheckmarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.width
    let height = rect.height
    path.move(to: CGPoint(x: width * 0.1, y: height * 0.5))
    path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.8))
    path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.2))
    return path
  }
}

struct BarsErrorView: View {
  @State private var shake: CGFloat = 0
  @State private var appear = false

  var body: some View {
    ZStack {
      BarsTriangleShape()
        .fill(Color.orange.opacity(0.15))
        .frame(width: 20, height: 18)

      BarsTriangleShape()
        .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        .frame(width: 20, height: 18)

      VStack(spacing: 2) {
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.orange)
          .frame(width: 2.5, height: 7)
        Circle()
          .fill(Color.orange)
          .frame(width: 3, height: 3)
      }
      .offset(y: 1)
    }
    .scaleEffect(appear ? 1 : 0.7)
    .opacity(appear ? 1 : 0)
    .offset(x: shake)
    .onAppear {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { appear = true }
      withAnimation(.linear(duration: 0.05).repeatCount(6, autoreverses: true).delay(0.15)) { shake = 2.5 }
    }
  }
}

private struct BarsTriangleShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
