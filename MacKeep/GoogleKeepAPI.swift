import Foundation

class GoogleKeepAPI {
  let email: String
  let masterToken: String
  let deviceId: String
  private var authToken: String?

  init(email: String, masterToken: String) {
    self.email = email
    self.masterToken = masterToken
    self.deviceId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(
      16
    ).uppercased()
  }

  func getOAuthToken(completion: @escaping (Result<String, Error>) -> Void) {
    let params = [
      "accountType": "HOSTED_OR_GOOGLE",
      "Email": email,
      "has_permission": "1",
      "EncryptedPasswd": masterToken,
      "service": "memento",
      "source": "android",
      "androidId": deviceId,
      "app": "com.google.android.keep",
      "client_sig": "38918a453d07199354f8b19af05ec6562ced5788",
      "device_country": "us",
      "operatorCountry": "us",
      "lang": "en",
      "sdk_version": "17",
      "google_play_services_version": "240913000",
    ]

    let body = params.sorted { $0.key < $1.key }
      .map {
        "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)"
      }
      .joined(separator: "&")

    var request = URLRequest(url: URL(string: "https://android.clients.google.com/auth")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("GoogleAuth/1.4", forHTTPHeaderField: "User-Agent")
    request.httpBody = body.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let responseString = String(data: data ?? Data(), encoding: .utf8) else {
        completion(.failure(APIError.noData))
        return
      }

      var result: [String: String] = [:]
      responseString.split(separator: "\n").forEach { line in
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          result[String(parts[0])] = String(parts[1])
        }
      }

      if let error = result["Error"] {
        completion(.failure(APIError.loginError(error)))
        return
      }

      if let auth = result["Auth"] {
        self.authToken = auth
        completion(.success(auth))
      } else {
        completion(.failure(APIError.authenticationFailed))
      }
    }.resume()
  }
}

enum APIError: Error, LocalizedError {
  case noData
  case authenticationFailed
  case loginError(String)

  var errorDescription: String? {
    switch self {
    case .noData: return "No data received"
    case .authenticationFailed: return "Authentication failed"
    case .loginError(let err): return "Login error: \(err)"
    }
  }
}
