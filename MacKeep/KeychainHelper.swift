import Foundation

class KeychainHelper {
  static let standard = KeychainHelper()

  func save(_ value: String, forKey key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: value.data(using: .utf8)!,
    ]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
  }

  func retrieve(forKey key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
    ]

    var result: AnyObject?
    SecItemCopyMatching(query as CFDictionary, &result)

    if let data = result as? Data {
      return String(data: data, encoding: .utf8)
    }
    return nil
  }
}
