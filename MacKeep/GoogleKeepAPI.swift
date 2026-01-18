import Foundation

class GoogleKeepAPI {
  var onLog: ((String) -> Void)?

  private func log(_ message: String) {
    DispatchQueue.main.async {
      self.onLog?(message)
    }
  }

  func fetchNotes(authToken: String, completion: @escaping (Result<[Note], Error>) -> Void) {
    log("Attempting to fetch notes...")
    let url = URL(string: "https://www.googleapis.com/notes/v1/changes")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("OAuth \(authToken)", forHTTPHeaderField: "Authorization")

    let requestBody: [String: Any] = [
      "clientTimestamp": String(Int(Date().timeIntervalSince1970 * 1000)),
      "requestHeader": [
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
      log(
        "Fetch Notes Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")"
      )
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
          // For now, we just return an empty array as we are focusing on the request itself.
          // We will parse the notes properly later.
          completion(.success([]))
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
  var text: String
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
