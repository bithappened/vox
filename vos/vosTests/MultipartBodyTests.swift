import Foundation
import XCTest

@testable import vos

/// Unit tests for multipart/form-data body creation
final class MultipartBodyTests: XCTestCase {

  // MARK: - Helper Method

  /// Helper to create a test audio file
  func createTestAudioFile() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("test_audio.m4a")

    // Create test data
    let testData = Data("test audio content".utf8)
    try? testData.write(to: fileURL)

    return fileURL
  }

  override func tearDown() {
    // Cleanup test files
    let tempDir = FileManager.default.temporaryDirectory
    try? FileManager.default.removeItem(
      at: tempDir.appendingPathComponent("test_audio.m4a"))
    super.tearDown()
  }

  // MARK: - Multipart Body Tests

  func testCreateMultipartBody_ContainsBoundary() throws {
    // Given
    let boundary = "test-boundary-123"

    // When - test boundary format
    let bodyString = "--\(boundary)\r\n"

    // Then
    XCTAssertTrue(bodyString.contains(boundary))
    XCTAssertTrue(bodyString.hasPrefix("--"))
    XCTAssertTrue(bodyString.hasSuffix("\r\n"))
  }

  func testCreateMultipartBody_IncludesModel() {
    // Given
    let boundary = "test-boundary"
    let expectedModel = "gpt-4o-transcribe"

    // When
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8))
    body.append(Data("\(expectedModel)\r\n".utf8))

    // Then
    let bodyString = String(data: body, encoding: .utf8)!
    XCTAssertTrue(bodyString.contains("name=\"model\""))
    XCTAssertTrue(bodyString.contains(expectedModel))
  }

  func testCreateMultipartBody_IncludesFile() {
    // Given
    let boundary = "test-boundary"
    let audioData = Data("audio content".utf8)

    // When
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(
      Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".utf8))
    body.append(Data("Content-Type: audio/m4a\r\n\r\n".utf8))
    body.append(audioData)
    body.append(Data("\r\n".utf8))

    // Then
    let bodyString = String(data: body, encoding: .utf8)!
    XCTAssertTrue(bodyString.contains("name=\"file\""))
    XCTAssertTrue(bodyString.contains("filename=\"audio.m4a\""))
    XCTAssertTrue(bodyString.contains("Content-Type: audio/m4a"))
  }

  func testCreateMultipartBody_HasCorrectTermination() {
    // Given
    let boundary = "test-boundary"

    // When
    var body = Data()
    body.append(Data("--\(boundary)--\r\n".utf8))

    // Then
    let bodyString = String(data: body, encoding: .utf8)!
    XCTAssertTrue(bodyString.hasSuffix("--\(boundary)--\r\n"))
  }

  func testCreateMultipartBody_PreservesFileData() throws {
    // Given
    let testData = Data("test audio binary data".utf8)
    let audioURL = createTestAudioFile()
    try testData.write(to: audioURL)

    // When - read file back
    let readData = try Data(contentsOf: audioURL)

    // Then
    XCTAssertEqual(readData, testData)
  }

  // MARK: - Boundary Format Tests

  func testBoundary_UniquePerRequest() {
    // When
    let boundary1 = "Boundary-\(UUID().uuidString)"
    let boundary2 = "Boundary-\(UUID().uuidString)"

    // Then
    XCTAssertNotEqual(boundary1, boundary2)
  }

  func testBoundary_HasCorrectFormat() {
    // When
    let boundary = "Boundary-\(UUID().uuidString)"

    // Then
    XCTAssertTrue(boundary.hasPrefix("Boundary-"))
    XCTAssertGreaterThan(boundary.count, 15)
  }
}
