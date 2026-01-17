import Foundation

class KeychainHelper {
  static let standard = KeychainHelper()

  func saveCredentials(email: String, masterToken: String) {
    savePassword(masterToken, forAccount: email, service: "MacKeep")
  }

  func retrieveCredentials() -> (email: String, masterToken: String)? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecReturnAttributes as String: true,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess, let items = result as? [[String: Any]] else {
      return nil
    }

    for item in items {
      if let account = item[kSecAttrAccount as String] as? String,
        let data = item[kSecValueData as String] as? Data,
        let password = String(data: data, encoding: .utf8)
      {
        return (email: account, masterToken: password)
      }
    }
    return nil
  }

  private func savePassword(_ password: String, forAccount account: String, service: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: service,
      kSecValueData as String: password.data(using: .utf8)!,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
  }

  func deleteCredentials(email: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecAttrAccount as String: email,
      kSecAttrService as String: "MacKeep",
    ]
    SecItemDelete(query as CFDictionary)
  }

  func save(_ value: String, forKey key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: value.data(using: .utf8)!,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
  }

  func retrieve(forKey key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    SecItemCopyMatching(query as CFDictionary, &result)

    if let data = result as? Data {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
}
