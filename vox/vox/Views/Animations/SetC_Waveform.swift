import SwiftUI

// MARK: - Set C: Waveform

struct WaveRecordingView: View {
  let audioLevel: Float
  let color: Color

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let level = CGFloat(audioLevel)

      Canvas { context, size in
        var path = Path()
        let midY = size.height / 2
        let amplitude = (size.height / 2 - 2) * (0.2 + level * 0.8)

        path.move(to: CGPoint(x: 0, y: midY))

        for xPos in stride(from: CGFloat(0), through: size.width, by: 1) {
          let relativeX = Double(xPos / size.width)
          let wave1 = sin(relativeX * Double.pi * 3 + time * 6) * Double(amplitude)
          let wave2 = sin(relativeX * Double.pi * 5 + time * 4) * Double(amplitude) * 0.3
          let yPos = Double(midY) + wave1 + wave2
          path.addLine(to: CGPoint(x: Double(xPos), y: yPos))
        }

        context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 2)
      }
    }
  }
}

struct WaveTranscribingView: View {
  let color: Color

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate

      HStack(spacing: 6) {
        ForEach(0..<4, id: \.self) { index in
          Circle()
            .fill(color.opacity(0.5 + 0.5 * sin(time * 4 + Double(index) * 0.8)))
            .frame(width: 5, height: 5)
            .offset(y: sin(time * 3 + Double(index) * 0.6) * 4)
        }
      }
    }
  }
}

struct WaveSuccessView: View {
  @State private var ringProgress: CGFloat = 0
  @State private var dotScale: CGFloat = 0

  var body: some View {
    ZStack {
      Circle()
        .trim(from: 0, to: ringProgress)
        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(-90))

      Circle()
        .fill(Color.green)
        .scaleEffect(dotScale * 0.3)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.35)) { ringProgress = 1 }
      withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.2)) { dotScale = 1 }
    }
  }
}

struct WaveErrorView: View {
  @State private var scale: CGFloat = 0
  @State private var shake: CGFloat = 0

  var body: some View {
    Circle()
      .fill(Color.orange)
      .scaleEffect(scale)
      .offset(x: shake)
      .onAppear {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { scale = 1 }
        withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true).delay(0.15)) { shake = 3 }
      }
  }
}
