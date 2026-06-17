import Foundation
import XCTest

@testable import vox

/// Unit tests for SettingsManager — uses an isolated UserDefaults suite and
/// in-memory credential store so the user's real settings are never touched.
final class SettingsManagerTests: XCTestCase {
  private var defaults: UserDefaults!
  private var credentialStore: InMemoryCredentialStore!
  private var manager: SettingsManager!
  private let suiteName = "vox.tests.SettingsManagerTests"

  override func setUp() {
    super.setUp()
    UserDefaults().removePersistentDomain(forName: suiteName)
    defaults = UserDefaults(suiteName: suiteName)
    credentialStore = InMemoryCredentialStore()
    manager = SettingsManager(defaults: defaults, credentialStore: credentialStore)
  }

  override func tearDown() {
    UserDefaults().removePersistentDomain(forName: suiteName)
    defaults = nil
    credentialStore = nil
    manager = nil
    super.tearDown()
  }

  // MARK: - Save

  func testSaveAPIKey_ValidKey_ReturnsTrue() {
    let validKey = "sk-proj-" + String(repeating: "a", count: 157)
    XCTAssertTrue(manager.saveAPIKey(validKey))
  }

  func testSaveAPIKey_EmptyKey_ReturnsFalse() {
    XCTAssertFalse(manager.saveAPIKey(""))
  }

  func testSaveAPIKey_WhitespaceOnly_ReturnsFalse() {
    XCTAssertFalse(manager.saveAPIKey("   \n\t   "))
  }

  func testSaveAPIKey_TrimsWhitespace() {
    _ = manager.saveAPIKey("  sk-proj-test  ")
    XCTAssertEqual(manager.getAPIKey(), "sk-proj-test")
  }

  func testSaveAPIKey_TrimsNewlines() {
    _ = manager.saveAPIKey("\nsk-proj-test\n")
    XCTAssertEqual(manager.getAPIKey(), "sk-proj-test")
  }

  func testSaveAPIKey_TrimsMixedWhitespace() {
    _ = manager.saveAPIKey("  \n sk-proj-test \n  ")
    XCTAssertEqual(manager.getAPIKey(), "sk-proj-test")
  }

  // MARK: - Get / Has

  func testGetAPIKey_NoKey_ReturnsNil() {
    XCTAssertNil(manager.getAPIKey())
  }

  func testGetAPIKey_AfterSave_ReturnsKey() {
    _ = manager.saveAPIKey("sk-proj-test123")
    XCTAssertEqual(manager.getAPIKey(), "sk-proj-test123")
  }

  func testGetAPIKey_DoubleTrimming() {
    // Simulate a previously corrupted store value.
    credentialStore.save("sk-proj-test  \n")
    XCTAssertEqual(manager.getAPIKey(), "sk-proj-test")
  }

  func testGetAPIKey_PreservesLength() {
    let key = "sk-proj-" + String(repeating: "x", count: 156)
    _ = manager.saveAPIKey(key)
    let retrieved = manager.getAPIKey()
    XCTAssertEqual(retrieved?.count, 164)
    XCTAssertEqual(retrieved, key)
  }

  func testHasAPIKey_WithKey_ReturnsTrue() {
    _ = manager.saveAPIKey("sk-proj-test")
    XCTAssertTrue(manager.hasAPIKey())
  }

  func testHasAPIKey_WithoutKey_ReturnsFalse() {
    XCTAssertFalse(manager.hasAPIKey())
  }

  // MARK: - Delete

  func testDeleteAPIKey_RemovesKey() {
    _ = manager.saveAPIKey("sk-proj-test")
    XCTAssertTrue(manager.hasAPIKey())
    manager.deleteAPIKey()
    XCTAssertFalse(manager.hasAPIKey())
    XCTAssertNil(manager.getAPIKey())
  }

  func testDeleteAPIKey_NoStoredKey_DoesNotCrash() {
    manager.deleteAPIKey()
    XCTAssertFalse(manager.hasAPIKey())
  }

  // MARK: - Migration

  func testMigration_MovesLegacyKeyFromUserDefaultsToCredentialStore() {
    defaults.set("sk-proj-legacy", forKey: "vox_api_key")
    let migratingManager = SettingsManager(defaults: defaults, credentialStore: credentialStore)
    XCTAssertEqual(migratingManager.getAPIKey(), "sk-proj-legacy")
    XCTAssertNil(defaults.string(forKey: "vox_api_key"))
  }

  func testMigration_NoLegacyKey_NoOp() {
    XCTAssertNil(manager.getAPIKey())
    let manager2 = SettingsManager(defaults: defaults, credentialStore: credentialStore)
    XCTAssertNil(manager2.getAPIKey())
  }

  func testMigration_ExistingKeychainValue_NotOverwritten() {
    credentialStore.save("sk-proj-existing")
    defaults.set("sk-proj-legacy", forKey: "vox_api_key")
    let migratingManager = SettingsManager(defaults: defaults, credentialStore: credentialStore)
    XCTAssertEqual(migratingManager.getAPIKey(), "sk-proj-existing")
    XCTAssertNil(defaults.string(forKey: "vox_api_key"))
  }

  // MARK: - Edge cases

  func testSaveAndRetrieve_ComplexWhitespace() {
    let messy = "  \t\n  sk-proj-test123  \r\n  "
    _ = manager.saveAPIKey(messy)
    let retrieved = manager.getAPIKey()
    XCTAssertEqual(retrieved, "sk-proj-test123")
  }
}
