import SwiftUI

// MARK: - Set B: Pulse Rings

struct PulseRecordingView: View {
  let audioLevel: Float
  let color: Color

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let level = CGFloat(audioLevel)

      ZStack {
        // Outer ring - pulses with audio
        Circle()
          .stroke(color.opacity(0.3 + level * 0.3), lineWidth: 2)
          .scaleEffect(0.6 + level * 0.4 + sin(time * 4) * 0.05)

        // Middle ring
        Circle()
          .stroke(color.opacity(0.5 + level * 0.3), lineWidth: 2)
          .scaleEffect(0.4 + level * 0.3 + sin(time * 5 + 1) * 0.05)

        // Center dot
        Circle()
          .fill(color.opacity(0.7 + level * 0.3))
          .scaleEffect(0.15 + level * 0.15)
      }
    }
  }
}

struct PulseTranscribingView: View {
  let color: Color

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate

      ZStack {
        ForEach(0..<3, id: \.self) { index in
          Circle()
            .fill(color.opacity(0.6 + Double(index) * 0.15))
            .frame(width: 5, height: 5)
            .offset(x: 9 * cos(time * 3 + Double(index) * 2.1),
                    y: 9 * sin(time * 3 + Double(index) * 2.1))
        }
      }
    }
  }
}

struct PulseSuccessView: View {
  @State private var scale: CGFloat = 0
  @State private var opacity: CGFloat = 0

  var body: some View {
    Circle()
      .fill(Color.green)
      .scaleEffect(scale)
      .opacity(opacity)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          scale = 1
          opacity = 1
        }
      }
  }
}

struct PulseErrorView: View {
  @State private var progress: CGFloat = 0
  @State private var opacity: CGFloat = 0

  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 6, y: 6))
        path.addLine(to: CGPoint(x: 18, y: 18))
        path.move(to: CGPoint(x: 18, y: 6))
        path.addLine(to: CGPoint(x: 6, y: 18))
      }
      .trim(from: 0, to: progress)
      .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
    .opacity(opacity)
    .onAppear {
      withAnimation(.easeOut(duration: 0.15)) { opacity = 1 }
      withAnimation(.easeOut(duration: 0.25)) { progress = 1 }
    }
  }
}
