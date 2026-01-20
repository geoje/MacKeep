import Foundation

struct Timestamps: Codable {
  var created: String?
  var updated: String?
  var trashed: String?
  var userEdited: String?
}

struct Note: Codable, Identifiable {
  var id: String
  var title: String?
  var text: String?
  var parentId: String?
  var isArchived: Bool?
  var type: String?
  var checked: Bool?
  var color: String?
  var timestamps: Timestamps?
}

class GoogleKeepAPI {
  private let clientSessionId: String

  init() {
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let randomInt = UInt32.random(in: 0...UInt32.max)
    self.clientSessionId = "s--\(timestamp)--\(randomInt)"
  }

  func fetchNotes(authToken: String, completion: @escaping (Result<[Note], Error>) -> Void) {
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
      completion(.failure(error))
      return
    }

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
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
        completion(.failure(error))
        return
      }

      guard let data = data else {
        let error = NSError(
          domain: "GoogleKeepAPI", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No data received"])
        completion(.failure(error))
        return
      }

      do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let nodes = json["nodes"] as? [[String: Any]]
        {
          let decoder = JSONDecoder()
          let notes = nodes.compactMap {
            try? decoder.decode(Note.self, from: JSONSerialization.data(withJSONObject: $0))
          }
          completion(.success(notes))
        } else {
          completion(.success([]))
        }
      } catch {
        completion(.failure(error))
      }
    }
    task.resume()
  }
}
