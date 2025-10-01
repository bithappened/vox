import Foundation

/// Errors that can occur during transcription
enum TranscriptionError: Error, LocalizedError {
  case invalidResponse
  case apiError(String)
  case networkError(Error)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Invalid API response"
    case .apiError(let message):
      return "API error: \(message)"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }
}

/// Service for transcribing audio using OpenAI Whisper API
final class TranscriptionService {
  private let apiURL = "https://api.openai.com/v1/audio/transcriptions"
  private let model = "gpt-4o-transcribe"

  /// Transcribes audio file using OpenAI Whisper API
  func transcribe(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
    guard let apiKey = validateAndGetAPIKey() else {
      completion(
        .failure(TranscriptionError.apiError("No API key configured. Please add one in Settings.")))
      return
    }

    do {
      let request = try createRequest(apiKey: apiKey, audioURL: audioURL)
      executeRequest(request, completion: completion)
    } catch {
      completion(.failure(error))
    }
  }

  /// Validates and retrieves API key from storage
  private func validateAndGetAPIKey() -> String? {
    guard let apiKey = SettingsManager.shared.getAPIKey() else {
      return nil
    }

    guard apiKey.hasPrefix("sk-") else {
      return nil
    }

    // Log for debugging (safe - only first/last chars)
    let preview = "\(apiKey.prefix(7))...\(apiKey.suffix(4))"
    print("✅ Using API key: \(preview) (length: \(apiKey.count))")

    return apiKey
  }

  /// Creates HTTP request for transcription
  private func createRequest(apiKey: String, audioURL: URL) throws -> URLRequest {
    guard let url = URL(string: apiURL) else {
      throw TranscriptionError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    print("🌐 Auth header length: \(7 + apiKey.count) (should be 171)")

    // Create multipart form data
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    request.httpBody = try createMultipartBody(boundary: boundary, audioURL: audioURL)
    return request
  }

  /// Executes the network request and handles response
  private func executeRequest(
    _ request: URLRequest,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let task = URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        completion(.failure(TranscriptionError.networkError(error)))
        return
      }

      guard let data = data else {
        completion(.failure(TranscriptionError.invalidResponse))
        return
      }

      self.parseResponse(data, completion: completion)
    }

    task.resume()
  }

  /// Parses API response JSON
  private func parseResponse(
    _ data: Data,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    do {
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        completion(.failure(TranscriptionError.invalidResponse))
        return
      }

      if let text = json["text"] as? String {
        completion(.success(text))
      } else if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
        completion(.failure(TranscriptionError.apiError(message)))
      } else {
        completion(.failure(TranscriptionError.invalidResponse))
      }
    } catch {
      completion(.failure(error))
    }
  }

  /// Creates multipart/form-data body for file upload
  private func createMultipartBody(boundary: String, audioURL: URL) throws -> Data {
    var body = Data()

    // Add model parameter
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8))
    body.append(Data("\(model)\r\n".utf8))

    // Add file parameter
    let audioData = try Data(contentsOf: audioURL)
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(
      Data(
        "Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".utf8))
    body.append(Data("Content-Type: audio/m4a\r\n\r\n".utf8))
    body.append(audioData)
    body.append(Data("\r\n".utf8))

    // Close boundary
    body.append(Data("--\(boundary)--\r\n".utf8))

    return body
  }
}
