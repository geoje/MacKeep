import Foundation

struct OAuthToken: Codable {
  let token: String
  let expiry: Date?
}

class GPSAuthAPI {
  var onLog: ((String) -> Void)?
  private let defaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.defaults = userDefaults
  }

  private func log(_ message: String) {
    DispatchQueue.main.async { [weak self] in
      self?.onLog?(message)
    }
  }

  private func cachedToken() -> OAuthToken? {
    guard let token = defaults.string(forKey: "authToken") else { return nil }
    let expiryInterval = defaults.double(forKey: "authTokenExpiry")
    let expiry: Date? = expiryInterval > 0 ? Date(timeIntervalSince1970: expiryInterval) : nil
    if let expiry = expiry, expiry < Date() {
      // expired
      return nil
    }
    return OAuthToken(token: token, expiry: expiry)
  }

  private func saveToken(_ token: OAuthToken) {
    defaults.set(token.token, forKey: "authToken")
    if let expiry = token.expiry {
      defaults.set(expiry.timeIntervalSince1970, forKey: "authTokenExpiry")
    } else {
      defaults.removeObject(forKey: "authTokenExpiry")
    }
  }

  func invalidateCache() {
    defaults.removeObject(forKey: "authToken")
    defaults.removeObject(forKey: "authTokenExpiry")
    log("Token cache invalidated")
  }

  func performOAuth(
    email: String, masterToken: String, deviceId: String,
    completion: @escaping (Result<OAuthToken, Error>) -> Void
  ) {
    // Return cached token if valid (unless explicitly invalidated)
    if let cached = cachedToken() {
      log("Using cached OAuth token")
      completion(.success(cached))
      return
    }

    log("Starting OAuth with deviceId: \(deviceId)")

    let url = URL(string: "https://android.clients.google.com/auth")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("identity", forHTTPHeaderField: "Accept-Encoding")
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
      // Use provided deviceId rather than generating a random one
      "androidId": deviceId.lowercased(),
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

    log("Sending OAuth request to Google...")
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        self.log("OAuth request failed: \(error.localizedDescription)")
        completion(.failure(error))
        return
      }

      if let http = response as? HTTPURLResponse {
        self.log("Received response: status=\(http.statusCode)")
      }

      guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
        let error = NSError(
          domain: "GPSAuthAPI",
          code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No data or invalid data received"]
        )
        self.log("No data or invalid data received")
        completion(.failure(error))
        return
      }

      self.log("OAuth Raw Response: \(responseString)")

      self.log("Parsing OAuth response...")
      let responseDict = responseString.split(separator: "\n").reduce(into: [String: String]()) {
        result, line in
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
          result[String(parts[0])] = String(parts[1])
        }
      }

      self.log("OAuth Response Keys: \(responseDict.keys.joined(separator: ", "))")
      if let authToken = responseDict["Auth"] {
        self.log("Auth token received: \(authToken.prefix(20))...")
        var expiryDate: Date? = nil
        if let expiresIn = responseDict["ExpiresInDurationSec"], let seconds = Double(expiresIn) {
          expiryDate = Date().addingTimeInterval(seconds)
        } else if let expiryEpoch = responseDict["Expiry"], let epoch = Double(expiryEpoch) {
          expiryDate = Date(timeIntervalSince1970: epoch)
        }

        let token = OAuthToken(token: authToken, expiry: expiryDate)
        self.saveToken(token)
        self.log("OAuth success: token acquired")
        completion(.success(token))
      } else {
        let errorDetail = responseDict["Error"] ?? "Unknown error"
        self.log("OAuth error response: \(responseDict)")
        self.log("OAuth error: \(errorDetail)")
        let error = NSError(
          domain: "GPSAuthAPI",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to get OAuth token: \(errorDetail)"]
        )
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
