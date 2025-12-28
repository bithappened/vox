import SwiftUI

// MARK: - Animation Set Definition

enum AnimationSetType: String, CaseIterable {
  case bars = "bars"
  case pulseRings = "pulse_rings"
  case waveform = "waveform"

  var displayName: String {
    switch self {
    case .bars: return "Bars"
    case .pulseRings: return "Pulse Rings"
    case .waveform: return "Waveform"
    }
  }

  var description: String {
    switch self {
    case .bars: return "Classic animated bars"
    case .pulseRings: return "Concentric pulsing rings"
    case .waveform: return "Smooth sine waveform"
    }
  }
}

// MARK: - Animation Set Factory

struct AnimationSetFactory {
  @ViewBuilder
  static func recordingView(for type: AnimationSetType, audioLevel: Float, color: Color) -> some View {
    switch type {
    case .bars:
      BarsRecordingView(audioLevel: audioLevel, color: color)
    case .pulseRings:
      PulseRecordingView(audioLevel: audioLevel, color: color)
    case .waveform:
      WaveRecordingView(audioLevel: audioLevel, color: color)
    }
  }

  @ViewBuilder
  static func transcribingView(for type: AnimationSetType, color: Color) -> some View {
    switch type {
    case .bars:
      BarsTranscribingView(color: color)
    case .pulseRings:
      PulseTranscribingView(color: color)
    case .waveform:
      WaveTranscribingView(color: color)
    }
  }

  @ViewBuilder
  static func successView(for type: AnimationSetType) -> some View {
    switch type {
    case .bars:
      BarsSuccessView()
    case .pulseRings:
      PulseSuccessView()
    case .waveform:
      WaveSuccessView()
    }
  }

  @ViewBuilder
  static func errorView(for type: AnimationSetType) -> some View {
    switch type {
    case .bars:
      BarsErrorView()
    case .pulseRings:
      PulseErrorView()
    case .waveform:
      WaveErrorView()
    }
  }

  static func recordingFrameSize(for type: AnimationSetType) -> CGSize {
    switch type {
    case .bars: return CGSize(width: 32, height: 24)
    case .pulseRings: return CGSize(width: 28, height: 28)
    case .waveform: return CGSize(width: 36, height: 24)
    }
  }

  static func transcribingFrameSize(for type: AnimationSetType) -> CGSize {
    switch type {
    case .bars: return CGSize(width: 32, height: 24)
    case .pulseRings: return CGSize(width: 28, height: 28)
    case .waveform: return CGSize(width: 36, height: 24)
    }
  }
}
