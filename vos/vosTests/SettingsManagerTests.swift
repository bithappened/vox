import Foundation
import XCTest

@testable import vos

/// Unit tests for SettingsManager
final class SettingsManagerTests: XCTestCase {
  let testKey = "vos_api_key"  // Same as production key
  var manager: SettingsManager!

  override func setUp() {
    super.setUp()
    // Clear any existing test data BEFORE test
    UserDefaults.standard.removeObject(forKey: testKey)
    UserDefaults.standard.synchronize()
    manager = SettingsManager.shared
  }

  override func tearDown() {
    // Cleanup after each test
    UserDefaults.standard.removeObject(forKey: testKey)
    UserDefaults.standard.synchronize()
    super.tearDown()
  }

  // MARK: - Save Tests

  func testSaveAPIKey_ValidKey_ReturnsTrue() {
    // Given
    let validKey = "sk-proj-" + String(repeating: "a", count: 157)

    // When
    let result = manager.saveAPIKey(validKey)

    // Then
    XCTAssertTrue(result)
  }

  func testSaveAPIKey_EmptyKey_ReturnsFalse() {
    // When
    let result = manager.saveAPIKey("")

    // Then
    XCTAssertFalse(result)
  }

  func testSaveAPIKey_WhitespaceOnly_ReturnsFalse() {
    // When
    let result = manager.saveAPIKey("   \n\t   ")

    // Then
    XCTAssertFalse(result)
  }

  func testSaveAPIKey_TrimsWhitespace() {
    // Given
    let keyWithSpaces = "  sk-proj-test  "

    // When
    _ = manager.saveAPIKey(keyWithSpaces)
    let retrieved = manager.getAPIKey()

    // Then
    XCTAssertEqual(retrieved, "sk-proj-test")
  }

  func testSaveAPIKey_TrimsNewlines() {
    // Given
    let keyWithNewlines = "\nsk-proj-test\n"

    // When
    _ = manager.saveAPIKey(keyWithNewlines)
    let retrieved = manager.getAPIKey()

    // Then
    XCTAssertEqual(retrieved, "sk-proj-test")
  }

  func testSaveAPIKey_TrimsMultipleWhitespacesAndNewlines() {
    // Given
    let messyKey = "  \n sk-proj-test \n  "

    // When
    _ = manager.saveAPIKey(messyKey)
    let retrieved = manager.getAPIKey()

    // Then
    XCTAssertEqual(retrieved, "sk-proj-test")
  }

  // MARK: - Get Tests

  func testGetAPIKey_NoKey_ReturnsNil() {
    // When
    let result = manager.getAPIKey()

    // Then
    XCTAssertNil(result)
  }

  func testGetAPIKey_AfterSave_ReturnsKey() {
    // Given
    let savedKey = "sk-proj-test123"
    _ = manager.saveAPIKey(savedKey)

    // When
    let result = manager.getAPIKey()

    // Then
    XCTAssertEqual(result, savedKey)
  }

  func testGetAPIKey_DoubleTrimming_Works() {
    // Given - simulate corrupted storage
    let keyWithExtraSpaces = "sk-proj-test  \n"
    UserDefaults.standard.set(keyWithExtraSpaces, forKey: "vos_api_key")

    // When
    let result = manager.getAPIKey()

    // Then
    XCTAssertEqual(result, "sk-proj-test")
  }

  func testGetAPIKey_PreservesLength() {
    // Given - actual API key format
    let apiKey =
      "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"
    _ = manager.saveAPIKey(apiKey)

    // When
    let retrieved = manager.getAPIKey()

    // Then
    XCTAssertEqual(retrieved?.count, 164)
    XCTAssertEqual(retrieved, apiKey)
  }

  // MARK: - Has Key Tests

  func testHasAPIKey_WithKey_ReturnsTrue() {
    // Given
    _ = manager.saveAPIKey("sk-proj-test")

    // When
    let result = manager.hasAPIKey()

    // Then
    XCTAssertTrue(result)
  }

  func testHasAPIKey_WithoutKey_ReturnsFalse() {
    // When
    let result = manager.hasAPIKey()

    // Then
    XCTAssertFalse(result)
  }

  // MARK: - Delete Tests

  func testDeleteAPIKey_RemovesKey() {
    // Given
    _ = manager.saveAPIKey("sk-proj-test")
    XCTAssertTrue(manager.hasAPIKey())

    // When
    manager.deleteAPIKey()

    // Then
    XCTAssertFalse(manager.hasAPIKey())
    XCTAssertNil(manager.getAPIKey())
  }

  func testDeleteAPIKey_WhenNoKey_DoesNotCrash() {
    // When/Then - should not crash
    manager.deleteAPIKey()
    XCTAssertFalse(manager.hasAPIKey())
  }

  // MARK: - Edge Cases

  func testSaveAndRetrieve_ComplexWhitespace() {
    // Given - key with various whitespace characters
    let messyKey = "  \t\n  sk-proj-test123  \r\n  "

    // When
    _ = manager.saveAPIKey(messyKey)
    let retrieved = manager.getAPIKey()

    // Then
    XCTAssertEqual(retrieved, "sk-proj-test123")
    XCTAssertFalse(retrieved?.contains(" ") ?? true)
    XCTAssertFalse(retrieved?.contains("\n") ?? true)
    XCTAssertFalse(retrieved?.contains("\t") ?? true)
  }

  func testPersistence_AcrossInstances() {
    // Given
    _ = manager.saveAPIKey("sk-proj-persistent")

    // When - get new instance
    let newManager = SettingsManager.shared

    // Then
    XCTAssertEqual(newManager.getAPIKey(), "sk-proj-persistent")
  }
}
