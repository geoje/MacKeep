import AppIntents
import Foundation
import WidgetKit

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

struct WidgetNoteEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Note"

  static var defaultQuery = WidgetNoteQuery()

  let id: String
  let title: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: .init(stringLiteral: title))
  }
}

struct WidgetNoteQuery: EntityQuery {
  func suggestedEntities() async throws -> [WidgetNoteEntity] {
    guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
      return []
    }

    return await withCheckedContinuation { continuation in
      let api = GoogleKeepAPI()
      api.fetchNotes(authToken: authToken) { result in
        switch result {
        case .success(let notes):
          let filteredNotes = notes.filter { note in
            note.parentId == "root" && (note.isArchived ?? false) == false
          }

          let entities = filteredNotes.map { note in
            let displayTitle = note.title ?? note.text ?? "Untitled"
            return WidgetNoteEntity(id: note.id, title: displayTitle)
          }
          continuation.resume(returning: entities)
        case .failure:
          continuation.resume(returning: [])
        }
      }
    }
  }

  func entities(for identifiers: [String]) async throws -> [WidgetNoteEntity] {
    let all = try await suggestedEntities()
    let set = Set(identifiers)
    return all.filter { set.contains($0.id) }
  }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Note Configuration" }
  static var description: IntentDescription { "Choose a note to display in the widget." }

  @Parameter(title: "Note")
  var note: WidgetNoteEntity?
}
