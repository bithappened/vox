import AVFoundation
import Foundation

/// Errors that can occur during audio recording
enum AudioRecorderError: Error, LocalizedError {
  case recordingFailed
  case microphoneAccessDenied
  case noRecordingInProgress

  var errorDescription: String? {
    switch self {
    case .recordingFailed:
      return "Failed to start recording"
    case .microphoneAccessDenied:
      return "Microphone access denied"
    case .noRecordingInProgress:
      return "No recording in progress"
    }
  }
}

/// Handles audio recording to temporary files
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
  private var audioRecorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var levelTimer: Timer?

  /// Callback for audio level updates (normalized 0.0 to 1.0)
  var onAudioLevelChange: ((Float) -> Void)?

  var isRecording: Bool {
    audioRecorder?.isRecording ?? false
  }

  // Debug mode flag - enables verbose audio level monitoring
  var debugMode: Bool = false

  /// Requests microphone permission and starts recording
  func startRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    // Request microphone permission
    AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
      guard granted else {
        completion(.failure(AudioRecorderError.microphoneAccessDenied))
        return
      }

      self?.beginRecording(completion: completion)
    }
  }

  private func beginRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    // Create temporary file URL
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "recording_\(UUID().uuidString).m4a"
    recordingURL = tempDir.appendingPathComponent(fileName)

    guard let url = recordingURL else {
      completion(.failure(AudioRecorderError.recordingFailed))
      return
    }

    // Setup recorder settings with higher sample rate to match system
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 48000.0,  // Match system sample rate
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      AVEncoderBitRateKey: 128000,  // Explicit bit rate for better quality
      AVLinearPCMBitDepthKey: 16
    ]

    do {
      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder?.delegate = self
      audioRecorder?.isMeteringEnabled = true  // Always enable for level visualization

      if debugMode {
        print("🎤 Recording started to: \(url.lastPathComponent)")
        print("🎤 Sample Rate: 48000 Hz, Channels: 1, Format: AAC")
      }

      let success = audioRecorder?.record() ?? false
      if success {
        startLevelMonitoring()
        completion(.success(()))
      } else {
        if debugMode {
          print("❌ Failed to start recording")
        }
        completion(.failure(AudioRecorderError.recordingFailed))
      }
    } catch {
      if debugMode {
        print("❌ Recording error: \(error)")
      }
      completion(.failure(error))
    }
  }

  /// Start monitoring audio levels for visualization
  private func startLevelMonitoring() {
    levelTimer?.invalidate()
    levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.updateAudioLevel()
    }
  }

  /// Stop monitoring audio levels
  private func stopLevelMonitoring() {
    levelTimer?.invalidate()
    levelTimer = nil
  }

  /// Update and broadcast current audio level
  private func updateAudioLevel() {
    guard let recorder = audioRecorder, recorder.isRecording else { return }

    recorder.updateMeters()
    let averagePower = recorder.averagePower(forChannel: 0)

    // Convert dB to normalized 0-1 range
    // Average power ranges from -160 (silence) to 0 (max)
    // We map -50 to 0 dB to 0-1 for more responsive visualization
    let minDb: Float = -50
    let maxDb: Float = 0
    let clampedPower = max(minDb, min(maxDb, averagePower))
    let normalizedLevel = (clampedPower - minDb) / (maxDb - minDb)

    DispatchQueue.main.async { [weak self] in
      self?.onAudioLevelChange?(normalizedLevel)
    }

    if debugMode {
      checkAudioLevels(averagePower: averagePower, peakPower: recorder.peakPower(forChannel: 0))
    }
  }

  /// Check if we're actually capturing audio (debug mode only)
  private func checkAudioLevels(averagePower: Float, peakPower: Float) {
    print("🎤 Audio Levels - Average: \(averagePower) dB, Peak: \(peakPower) dB")

    // Warn if levels are too low (silence is around -160 dB)
    if averagePower < -100 {
      print("⚠️  WARNING: Audio levels very low! Check:")
      print("   1. System Settings > Sound > Input - correct microphone selected?")
      print("   2. System Settings > Privacy & Security > Microphone - vox enabled?")
      print("   3. Try speaking louder or moving closer to microphone")
    }
  }

  /// Stops the current recording and returns the audio file URL
  func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
    stopLevelMonitoring()

    guard let recorder = audioRecorder, recorder.isRecording else {
      completion(.failure(AudioRecorderError.noRecordingInProgress))
      return
    }

    guard let url = recordingURL else {
      completion(.failure(AudioRecorderError.recordingFailed))
      return
    }

    recorder.stop()
    completion(.success(url))
  }

  /// Cancel current recording without saving
  func cancelRecording() {
    stopLevelMonitoring()

    if let recorder = audioRecorder, recorder.isRecording {
      recorder.stop()
    }

    // Clean up temp file
    if let url = recordingURL {
      try? FileManager.default.removeItem(at: url)
    }

    audioRecorder = nil
    recordingURL = nil
  }
}
