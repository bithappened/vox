import AVFoundation
import Foundation

/// Errors that can occur during audio recording.
enum AudioRecorderError: Error, LocalizedError {
  case recordingFailed
  case microphoneAccessDenied
  case noRecordingInProgress

  var errorDescription: String? {
    switch self {
    case .recordingFailed: return "Failed to start recording"
    case .microphoneAccessDenied: return "Microphone access denied"
    case .noRecordingInProgress: return "No recording in progress"
    }
  }
}

/// Records microphone input to a temporary `.m4a` file and reports normalized
/// audio levels (0–1) on the main queue ~20Hz.
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
  private var audioRecorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var levelTimer: Timer?

  /// Callback invoked on the main queue with a normalized audio level (0...1).
  var onAudioLevelChange: ((Float) -> Void)?

  /// Whether the recorder is currently capturing.
  var isRecording: Bool {
    audioRecorder?.isRecording ?? false
  }

  /// Enables verbose os_log output.
  var debugMode: Bool = false

  // MARK: - Public API

  func startRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
      // requestAccess(_:completionHandler:) can fire its callback on an arbitrary
      // queue. Hop to main so the AVAudioRecorder, our Timer, and the user's
      // completion block all live on the same run loop.
      DispatchQueue.main.async {
        guard granted else {
          completion(.failure(AudioRecorderError.microphoneAccessDenied))
          return
        }
        self?.beginRecording(completion: completion)
      }
    }
  }

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
    audioRecorder = nil
    recordingURL = nil
    completion(.success(url))
  }

  func cancelRecording() {
    stopLevelMonitoring()
    audioRecorder?.stop()

    if let url = recordingURL {
      try? FileManager.default.removeItem(at: url)
    }
    audioRecorder = nil
    recordingURL = nil
  }

  // MARK: - Internals

  private func beginRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "recording_\(UUID().uuidString).m4a"
    let url = tempDir.appendingPathComponent(fileName)
    recordingURL = url

    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 48000.0,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
      AVEncoderBitRateKey: 128_000,
      AVLinearPCMBitDepthKey: 16
    ]

    do {
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.delegate = self
      recorder.isMeteringEnabled = true
      audioRecorder = recorder

      if debugMode {
        debugLog("Recording started: \(url.lastPathComponent) [48kHz mono AAC]")
      }

      guard recorder.record() else {
        if debugMode { debugLog("Failed to start AVAudioRecorder") }
        completion(.failure(AudioRecorderError.recordingFailed))
        return
      }

      startLevelMonitoring()
      completion(.success(()))
    } catch {
      if debugMode { debugLog("Recording error: \(error)") }
      completion(.failure(error))
    }
  }

  private func startLevelMonitoring() {
    levelTimer?.invalidate()
    levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.updateAudioLevel()
    }
  }

  private func stopLevelMonitoring() {
    levelTimer?.invalidate()
    levelTimer = nil
  }

  private func updateAudioLevel() {
    guard let recorder = audioRecorder, recorder.isRecording else { return }
    recorder.updateMeters()

    let averagePower = recorder.averagePower(forChannel: 0)

    // Map −50…0 dB to 0…1 for visualization. Below −50 reads as silence.
    let minDb: Float = -50
    let maxDb: Float = 0
    let clamped = max(minDb, min(maxDb, averagePower))
    let normalized = (clamped - minDb) / (maxDb - minDb)

    DispatchQueue.main.async { [weak self] in
      self?.onAudioLevelChange?(normalized)
    }

    if debugMode, averagePower < -100 {
      debugLog("Very low audio level (\(averagePower) dB). Check microphone selection and permission.")
    }
  }
}
