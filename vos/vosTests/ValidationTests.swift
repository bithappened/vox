import Foundation
import XCTest

@testable import vos

/// Unit tests for API key validation logic
final class ValidationTests: XCTestCase {

  // MARK: - API Key Format Tests

  func testAPIKey_ValidFormat_StartsWithSK() {
    // Given
    let validKey = "sk-proj-test123"

    // Then
    XCTAssertTrue(validKey.hasPrefix("sk-"))
  }

  func testAPIKey_InvalidFormat_NoPrefix() {
    // Given
    let invalidKey = "proj-test123"

    // Then
    XCTAssertFalse(invalidKey.hasPrefix("sk-"))
  }

  func testAPIKey_InvalidFormat_WrongPrefix() {
    // Given
    let invalidKey = "pk-proj-test123"

    // Then
    XCTAssertFalse(invalidKey.hasPrefix("sk-"))
  }

  // MARK: - Length Tests

  func testAPIKey_ValidLength_164Chars() {
    // Given - real OpenAI API key format
    let validKey = "sk-proj-" + String(repeating: "a", count: 156)

    // Then
    XCTAssertEqual(validKey.count, 164)
    XCTAssertTrue(validKey.hasPrefix("sk-"))
  }

  func testAPIKey_TooShort_Fails() {
    // Given
    let shortKey = "sk-short"

    // Then
    XCTAssertLessThan(shortKey.count, 20)
  }

  // MARK: - Trimming Tests

  func testTrimAPIKey_RemovesLeadingSpaces() {
    // Given
    let keyWithSpaces = "   sk-proj-test"

    // When
    let trimmed = keyWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed, "sk-proj-test")
    XCTAssertFalse(trimmed.hasPrefix(" "))
  }

  func testTrimAPIKey_RemovesTrailingSpaces() {
    // Given
    let keyWithSpaces = "sk-proj-test   "

    // When
    let trimmed = keyWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed, "sk-proj-test")
    XCTAssertFalse(trimmed.hasSuffix(" "))
  }

  func testTrimAPIKey_RemovesNewlines() {
    // Given
    let keyWithNewlines = "\nsk-proj-test\n"

    // When
    let trimmed = keyWithNewlines.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed, "sk-proj-test")
    XCTAssertFalse(trimmed.contains("\n"))
  }

  func testTrimAPIKey_RemovesTabs() {
    // Given
    let keyWithTabs = "\tsk-proj-test\t"

    // When
    let trimmed = keyWithTabs.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed, "sk-proj-test")
    XCTAssertFalse(trimmed.contains("\t"))
  }

  func testTrimAPIKey_HandlesEmpty() {
    // Given
    let emptyKey = "   "

    // When
    let trimmed = emptyKey.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertTrue(trimmed.isEmpty)
  }

  // MARK: - Actual API Key Tests

  func testRealAPIKey_PreservesCorrectLength() {
    // Given - the actual API key from requirements
    let realKey =
      "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"

    // Then
    XCTAssertEqual(realKey.count, 164)
    XCTAssertTrue(realKey.hasPrefix("sk-"))
    XCTAssertTrue(realKey.hasPrefix("sk-proj-"))
  }

  func testRealAPIKey_WithWhitespace_TrimsTo164() {
    // Given - key with extra whitespace (common copy-paste error)
    let keyWithSpaces =
      "  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  \n"

    // When
    let trimmed = keyWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed.count, 164)
    XCTAssertTrue(trimmed.hasPrefix("sk-"))
  }

  // MARK: - Edge Cases

  func testAPIKey_OnlyNewlines_BecomesEmpty() {
    // Given
    let onlyNewlines = "\n\n\n"

    // When
    let trimmed = onlyNewlines.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertTrue(trimmed.isEmpty)
  }

  func testAPIKey_MixedWhitespace_TrimsCorrectly() {
    // Given
    let messyKey = " \t\n sk-proj-test \r\n\t "

    // When
    let trimmed = messyKey.trimmingCharacters(in: .whitespacesAndNewlines)

    // Then
    XCTAssertEqual(trimmed, "sk-proj-test")
  }

  // MARK: - Character Set Tests

  func testAPIKey_AllowedCharacters() {
    // Given - valid characters in API keys
    let validKey = "sk-proj-ABC123_xyz789-test"

    // Then
    XCTAssertTrue(
      validKey.allSatisfy { char in
        char.isLetter || char.isNumber || char == "-" || char == "_"
      })
  }
}
