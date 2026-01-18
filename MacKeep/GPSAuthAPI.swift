import Foundation

class GPSAuthAPI {
  var onLog: ((String) -> Void)?

  private func generateRandomAndroidId() -> String {
    let random = UInt64.random(in: 0...UInt64.max)
    return String(format: "%016x", random)
  }

  private func log(_ message: String) {
    DispatchQueue.main.async {
      self.onLog?(message)
    }
  }

  func performOAuth(
    email: String, masterToken: String, deviceId: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    log("Attempting to get OAuth token...")
    let url = URL(string: "https://android.clients.google.com/auth")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("indetity", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.addValue("GoogleAuth/1.4", forHTTPHeaderField: "User-Agent")

    let bodyParameters: [String: Any] = [
      "accountType": "HOSTED_OR_GOOGLE",
      "Email": email,
      "has_permission": 1,
      "EncryptedPasswd": masterToken,
      "service":
        "oauth2:https://www.googleapis.com/auth/memento https://www.googleapis.com/auth/reminders",
      "source": "android",
      "androidId": generateRandomAndroidId(),
      "app": "com.google.android.keep",
      "client_sig": "38918a453d07199354f8b19af05ec6562ced5788",
      "device_country": "us",
      "operatorCountry": "us",
      "lang": "en",
      "sdk_version": 17,
      "google_play_services_version": 240_913_000,
    ]

    request.httpBody =
      bodyParameters
      .map { key, value in
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let encodedValue = "\(value)".addingPercentEncoding(
          withAllowedCharacters: .urlQueryAllowed)!
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")
      .data(using: .utf8)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        self.log("Error getting OAuth token: \(error.localizedDescription)")
        completion(.failure(error))
        return
      }

      guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
        let error = NSError(
          domain: "GPSAuthAPI",
          code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No data or invalid data received"]
        )
        self.log("Error: No data or invalid data received from OAuth endpoint.")
        completion(.failure(error))
        return
      }

      self.log("OAuth Response: \(responseString)")

      let responseDict = responseString.split(separator: "\n").reduce(into: [String: String]()) {
        result, line in
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          result[String(parts[0])] = String(parts[1])
        }
      }

      if let authToken = responseDict["Auth"] {
        self.log("Successfully retrieved OAuth token.")
        completion(.success(authToken))
      } else {
        let errorDetail = responseDict["Error"] ?? "Unknown error"
        let error = NSError(
          domain: "GPSAuthAPI",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to get OAuth token: \(errorDetail)"]
        )
        self.log("Error: Failed to parse OAuth token from response. Detail: \(errorDetail)")
        completion(.failure(error))
      }
    }
    task.resume()
  }
}

enum GPSAuthError: Error, LocalizedError {
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
