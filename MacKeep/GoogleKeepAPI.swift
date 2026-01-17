import Foundation

class GoogleKeepAPI {
  let email: String
  let masterToken: String
  let deviceId: String
  private var authToken: String?
  private let gpsAuth: GPSAuthAPI

  init(email: String, masterToken: String) {
    self.email = email
    self.masterToken = masterToken
    self.deviceId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(
      16
    ).uppercased()
    self.gpsAuth = GPSAuthAPI(email: email, masterToken: masterToken, deviceId: self.deviceId)
  }

  func getOAuthToken(completion: @escaping (Result<String, Error>) -> Void) {
    gpsAuth.performOAuth { result in
      switch result {
      case .success(let token):
        self.authToken = token
        completion(.success(token))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func fetchNotes(completion: @escaping (Result<Int, Error>) -> Void) {
    guard let authToken = authToken else {
      completion(.failure(APIError.notAuthenticated))
      return
    }

    let timestamp = String(format: "%.0f000", Date().timeIntervalSince1970)
    let params: [String: Any] = [
      "nodes": [],
      "clientTimestamp": timestamp,
      "requestHeader": [
        "clientSessionId":
          "s--\(Int(Date().timeIntervalSince1970 * 1000))--\(Int.random(in: 1_000_000_000..<9_999_999_999))",
        "clientPlatform": "ANDROID",
        "clientVersion": [
          "major": "9",
          "minor": "9",
          "build": "9",
          "revision": "9",
        ],
        "capabilities": [
          ["type": "NC"],
          ["type": "PI"],
          ["type": "LB"],
          ["type": "AN"],
          ["type": "SH"],
          ["type": "DR"],
          ["type": "TR"],
          ["type": "IN"],
          ["type": "SNB"],
        ],
      ],
    ]

    var request = URLRequest(url: URL(string: "https://www.googleapis.com/notes/v1/changes")!)
    request.httpMethod = "POST"
    request.setValue("OAuth \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: params)

    URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let data = data else {
        completion(.failure(APIError.noData))
        return
      }

      do {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let allNodes = json?["nodes"] as? [[String: Any]] {
          let notes = allNodes.filter { node in
            let parentId = node["parentId"] as? String
            return parentId == nil || parentId == "root"
          }
          completion(.success(notes.count))
        } else {
          completion(.success(0))
        }
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }
}

enum APIError: Error, LocalizedError {
  case noData
  case notAuthenticated

  var errorDescription: String? {
    switch self {
    case .noData: return "No data received"
    case .notAuthenticated: return "Not authenticated"
    }
  }
}
