import Foundation

class GoogleKeepAPI {
  let email: String
  let masterToken: String
  let deviceId: String

  private var authToken: String?

  init(email: String, masterToken: String) {
    self.email = email
    self.masterToken = masterToken
    self.deviceId = UUID().uuidString.lowercased()
  }

  func authenticate(completion: @escaping (Result<Void, Error>) -> Void) {
    // Step 1: master_token으로 OAuth 토큰 획득
    refreshAuthToken { result in
      completion(result)
    }
  }

  private func refreshAuthToken(completion: @escaping (Result<Void, Error>) -> Void) {
    // gpsoauth의 perform_oauth를 모방
    // master_token으로 OAuth 토큰 요청
    let urlString = "https://android.clients.google.com/auth"
    guard let url = URL(string: urlString) else {
      completion(.failure(APIError.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let body =
      "Email=\(email)&auth=\(masterToken)&service=memento&app_package=com.google.android.keep&client_sig=38918a453d07199354f8b19af05ec6562ced5788&device_id=\(deviceId)&Access_token=1&grant_type=oauth2&redirect_uri=urn:ietf:wg:oauth:2.0:oob"

    request.httpBody = body.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let data = data,
        let responseString = String(data: data, encoding: .utf8)
      else {
        completion(.failure(APIError.noData))
        return
      }

      // Parse response: Auth=<token>
      let lines = responseString.split(separator: "\n")
      for line in lines {
        if line.starts(with: "Auth=") {
          self.authToken = String(line.dropFirst(5))
          completion(.success(()))
          return
        }
      }

      completion(.failure(APIError.authenticationFailed))
    }.resume()
  }

  func fetchNotes(completion: @escaping (Result<[Note], Error>) -> Void) {
    guard let authToken = authToken else {
      completion(.failure(APIError.notAuthenticated))
      return
    }

    let urlString = "https://www.googleapis.com/notes/v1/changes"
    guard let url = URL(string: urlString) else {
      completion(.failure(APIError.invalidURL))
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let params: [String: Any] = [
      "nodes": [],
      "clientTimestamp": String(format: "%.3f", Date().timeIntervalSince1970),
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: params)

    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let data = data else {
        completion(.failure(APIError.noData))
        return
      }

      do {
        let decoder = JSONDecoder()
        let response = try decoder.decode(NotesResponse.self, from: data)
        completion(.success(response.nodes ?? []))
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }
}

struct Note: Codable {
  let id: String
  let title: String?
  let text: String?
}

struct NotesResponse: Codable {
  let nodes: [Note]?
}

enum APIError: Error {
  case invalidURL
  case noData
  case authenticationFailed
  case notAuthenticated
}
