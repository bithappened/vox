import Foundation
import Security

/// Abstracts credential persistence so production code can use the Keychain
/// while tests can substitute an in-memory implementation.
protocol CredentialStore {
  @discardableResult
  func save(_ value: String) -> Bool
  func get() -> String?
  func delete()
}

/// Stores a single secret in the macOS Keychain as a generic password.
final class KeychainCredentialStore: CredentialStore {
  private let service: String
  private let account: String

  init(service: String = "so.kubo.vox", account: String = "openai-api-key") {
    self.service = service
    self.account = account
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }

  @discardableResult
  func save(_ value: String) -> Bool {
    guard let data = value.data(using: .utf8) else { return false }

    let updateStatus = SecItemUpdate(
      baseQuery as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )

    switch updateStatus {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      var insertQuery = baseQuery
      insertQuery[kSecValueData as String] = data
      insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
      if addStatus != errSecSuccess {
        debugLog("Keychain add failed with status: \(addStatus)")
      }
      return addStatus == errSecSuccess
    default:
      debugLog("Keychain update failed with status: \(updateStatus)")
      return false
    }
  }

  func get() -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  func delete() {
    SecItemDelete(baseQuery as CFDictionary)
  }
}

/// Volatile credential store for tests and previews.
final class InMemoryCredentialStore: CredentialStore {
  private var value: String?

  init(initial: String? = nil) {
    self.value = initial
  }

  @discardableResult
  func save(_ value: String) -> Bool {
    self.value = value
    return true
  }

  func get() -> String? { value }
  func delete() { value = nil }
}
