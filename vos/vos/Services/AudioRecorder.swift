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
  var isRecording: Bool {
    audioRecorder?.isRecording ?? false
  }

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

    // Setup recorder settings - macOS doesn't need AVAudioSession
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100.0,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    do {
      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder?.delegate = self
      audioRecorder?.record()
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  /// Stops the current recording and returns the audio file URL
  func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
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
}
