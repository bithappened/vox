import AppKit
import SwiftUI

// MARK: - Audio sample model

struct AudioSample: Equatable {
  let level: Float
  let time: TimeInterval
}

enum IndicatorPhase: Equatable {
  case listening
  case transcribing
  case success
  case error
}

// MARK: - Animation style

/// The two recording indicator styles vox offers: a signature character
/// (Rover Buddy) and an ambient wave along the bottom of the screen (Voice
/// Wave). Raw values are stable so saved preferences keep loading.
enum RecordingAnimationStyle: String, CaseIterable, Identifiable {
  case tinyRobot = "tiny_robot"     // Rover Buddy — the signature mascot
  case voiceWave = "voice_wave"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .tinyRobot: return "Rover Buddy"
    case .voiceWave: return "Voice Wave"
    }
  }

  var menuDescription: String {
    switch self {
    case .tinyRobot:
      return "A friendly rover that listens, thinks, and cheers — reacts to your voice."
    case .voiceWave:
      return "A subtle wave along the bottom of the screen that flows with your voice."
    }
  }

  var recordingFrameSize: CGSize {
    switch self {
    case .tinyRobot: return CGSize(width: 132, height: 134)
    case .voiceWave: return CGSize(width: 34, height: 24)
    }
  }

  var transcribingFrameSize: CGSize {
    switch self {
    case .tinyRobot: return CGSize(width: 132, height: 134)
    case .voiceWave: return CGSize(width: 34, height: 24)
    }
  }

  var accentColor: Color {
    switch self {
    case .tinyRobot: return Color(red: 0.99, green: 0.68, blue: 0.24)
    case .voiceWave: return Color(red: 0.42, green: 0.92, blue: 1.0)
    }
  }
}

// MARK: - Indicator factory

enum StatusIndicatorFactory {
  @ViewBuilder
  static func recording(style: RecordingAnimationStyle, samples: [AudioSample]) -> some View {
    switch style {
    case .tinyRobot:
      RoverBuddyIndicator(samples: samples, phase: .listening)
    case .voiceWave:
      VoiceWaveIndicator(samples: samples, phase: .listening)
    }
  }

  @ViewBuilder
  static func transcribing(style: RecordingAnimationStyle) -> some View {
    switch style {
    case .tinyRobot:
      RoverBuddyIndicator(samples: [], phase: .transcribing)
    case .voiceWave:
      VoiceWaveIndicator(samples: [], phase: .transcribing)
    }
  }

  @ViewBuilder
  static func feedback(style: RecordingAnimationStyle, isSuccess: Bool) -> some View {
    switch style {
    case .tinyRobot:
      RoverBuddyIndicator(samples: [], phase: isSuccess ? .success : .error)
    case .voiceWave:
      VoiceWaveIndicator(samples: [], phase: isSuccess ? .success : .error)
    }
  }
}

// MARK: - Shared drawing helper

func latestLevel(_ samples: [AudioSample]) -> CGFloat {
  guard let sample = samples.last else { return 0 }
  return CGFloat(max(0, min(1, sample.level)))
}
