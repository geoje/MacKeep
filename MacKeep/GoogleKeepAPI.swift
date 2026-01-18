import Foundation

class GoogleKeepAPI {
  var onLog: ((String) -> Void)?

  private func log(_ message: String) {
    DispatchQueue.main.async {
      self.onLog?(message)
    }
  }

  private let clientSessionId: String

  init() {
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let randomInt = UInt32.random(in: 0...UInt32.max)
    self.clientSessionId = "s--\(timestamp)--\(randomInt)"
  }

  func fetchNotes(authToken: String, completion: @escaping (Result<[Note], Error>) -> Void) {
    log("Attempting to fetch notes...")
    let url = URL(string: "https://www.googleapis.com/notes/v1/changes")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue(
      "x-mackeep/1.0.0 (https://github.com/geoje/mackeep)", forHTTPHeaderField: "User-Agent")
    request.addValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
    request.addValue("*/*", forHTTPHeaderField: "Accept")
    request.addValue("keep-alive", forHTTPHeaderField: "Connection")
    request.addValue("OAuth \(authToken)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let requestBody: [String: Any] = [
      "nodes": [],
      "clientTimestamp": formatter.string(from: Date()),
      "requestHeader": [
        "clientSessionId": self.clientSessionId,
        "clientPlatform": "ANDROID",
        "clientVersion": ["major": "9", "minor": "9", "build": "9", "revision": "9"],
        "capabilities": [
          ["type": "NC"], ["type": "PI"], ["type": "LB"], ["type": "AN"], ["type": "SH"],
          ["type": "DR"], ["type": "TR"], ["type": "IN"], ["type": "SNB"], ["type": "MI"],
          ["type": "CO"],
        ],
      ],
    ]

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
    } catch {
      log("Error serializing request body: \(error.localizedDescription)")
      completion(.failure(error))
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        self.log("Error fetching notes: \(error.localizedDescription)")
        completion(.failure(error))
        return
      }

      if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        let responseBody = String(data: data ?? Data(), encoding: .utf8) ?? "No response body"
        let error = NSError(
          domain: "GoogleKeepAPI", code: httpResponse.statusCode,
          userInfo: [
            NSLocalizedDescriptionKey:
              "Server returned status \(httpResponse.statusCode). Body: \(responseBody)"
          ])
        self.log("HTTP Error: \(error.localizedDescription)")
        completion(.failure(error))
        return
      }

      guard let data = data else {
        let error = NSError(
          domain: "GoogleKeepAPI", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No data received"])
        self.log("Error: No data received from notes endpoint.")
        completion(.failure(error))
        return
      }

      self.log(
        "Fetch Notes Raw Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode response")"
      )

      do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let nodes = json["nodes"] as? [[String: Any]]
        {
          self.log("Successfully fetched and parsed \(nodes.count) nodes.")
          let decoder = JSONDecoder()
          let notes = nodes.compactMap {
            try? decoder.decode(Note.self, from: JSONSerialization.data(withJSONObject: $0))
          }
          completion(.success(notes))
        } else {
          self.log("Successfully fetched data, but failed to parse notes.")
          completion(.success([]))
        }
      } catch {
        self.log("Error parsing notes response: \(error.localizedDescription)")
        completion(.failure(error))
      }
    }
    task.resume()
  }
}

struct Note: Codable, Identifiable {
  var id: String
  var title: String?
  var text: String?
  var parentId: String?
  var isArchived: Bool?
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
