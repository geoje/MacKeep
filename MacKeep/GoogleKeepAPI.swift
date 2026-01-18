import Foundation

class GoogleKeepAPI {
  let email: String
  let masterToken: String
  let deviceId: String
  private var authToken: String?
  private let gpsAuth: GPSAuthAPI
  var onLog: ((String) -> Void)?

  init(email: String, masterToken: String) {
    self.email = email
    self.masterToken = masterToken
    self.deviceId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(
      16
    ).uppercased()
    self.gpsAuth = GPSAuthAPI(email: email, masterToken: masterToken, deviceId: self.deviceId)
  }

  private func log(_ message: String) {
    onLog?(message)
    print(message)
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
      self.log("[GoogleKeepAPI] ERROR: Not authenticated")
      completion(.failure(APIError.notAuthenticated))
      return
    }

    self.log("[GoogleKeepAPI] Starting note fetch with authToken: \(authToken.prefix(20))...")

    var allNotes: [[String: Any]] = []
    var currentVersion: String = "0"

    func syncNotes() {
      self.log("[GoogleKeepAPI] Syncing with pageToken: \(currentVersion)")
      let timestamp = String(format: "%.0f000", Date().timeIntervalSince1970)
      var params: [String: Any] = [
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
            ["type": "MI"],
            ["type": "CO"],
          ],
        ],
      ]

      // Add targetVersion for pagination
      if currentVersion != "0" {
        params["targetVersion"] = currentVersion
      }

      var request = URLRequest(
        url: URL(
          string:
            "https://www.googleapis.com/notes/v1/changes"
        )!)
      request.httpMethod = "POST"
      request.setValue("OAuth \(authToken)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try? JSONSerialization.data(withJSONObject: params)

      self.log("[GoogleKeepAPI] Auth Header: OAuth \(authToken.prefix(50))...")

      URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
          self.log("[GoogleKeepAPI] Network Error: \(error.localizedDescription)")
          completion(.failure(error))
          return
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
          let error = NSError(
            domain: "", code: httpResponse.statusCode,
            userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
          self.log("Sync failed with status code: \(httpResponse.statusCode)")
          if let data = data, let responseBody = String(data: data, encoding: .utf8) {
            self.log("Error response body: \(responseBody)")
          }
          completion(.failure(error))
          return
        }

        guard let data = data else {
          self.log("[GoogleKeepAPI] No data received from server")
          completion(.failure(APIError.noData))
          return
        }

        // Print raw response
        if let httpResponse = response as? HTTPURLResponse {
          self.log("[GoogleKeepAPI] HTTP Status: \(httpResponse.statusCode)")
        }

        if let rawJsonString = String(data: data, encoding: .utf8) {
          self.log("[GoogleKeepAPI] Raw Response: \(rawJsonString.prefix(500))")
        }

        do {
          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

          self.log("[GoogleKeepAPI] Parsed JSON keys: \(json?.keys.sorted() ?? [])")

          if let nodes = json?["nodes"] as? [[String: Any]] {
            self.log("[GoogleKeepAPI] Found \(nodes.count) nodes in this response")

            for (index, node) in nodes.enumerated() {
              let nodeId = node["id"] as? String ?? "unknown"
              let type = node["type"] as? String ?? "unknown"
              let parentId = node["parentId"] as? String ?? "nil"
              self.log(
                "[GoogleKeepAPI]   Node \(index): id=\(nodeId), type=\(type), parentId=\(parentId)")
            }

            allNotes.append(contentsOf: nodes)
          } else {
            self.log("[GoogleKeepAPI] No 'nodes' key or not an array in response")
          }

          self.log("[GoogleKeepAPI] Total notes collected so far: \(allNotes.count)")

          if let toVersion = json?["toVersion"] as? String {
            self.log("[GoogleKeepAPI] Found toVersion, checking if truncated...")
            currentVersion = toVersion

            if let truncated = json?["truncated"] as? Bool, truncated {
              self.log("[GoogleKeepAPI] Response truncated, fetching more...")
              syncNotes()
            } else {
              self.log("[GoogleKeepAPI] Not truncated, processing all notes...")
              let notes = allNotes.filter { node in
                let parentId = node["parentId"] as? String
                let type = node["type"] as? String
                return (parentId == nil || parentId == "root") && type == "NOTE"
              }
              self.log("[GoogleKeepAPI] Final filtered notes count: \(notes.count)")
              completion(.success(notes.count))
            }
          } else {
            self.log("[GoogleKeepAPI] No toVersion in response, processing all notes...")
            let notes = allNotes.filter { node in
              let parentId = node["parentId"] as? String
              let type = node["type"] as? String
              return (parentId == nil || parentId == "root") && type == "NOTE"
            }
            self.log("[GoogleKeepAPI] Final filtered notes count: \(notes.count)")
            completion(.success(notes.count))
          }
        } catch {
          self.log("[GoogleKeepAPI] JSON parsing error: \(error.localizedDescription)")
          completion(.failure(error))
        }
      }.resume()
    }

    syncNotes()
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
