import Foundation

class GoogleKeepAPI {
    let email: String
    let masterToken: String
    
    init(email: String, masterToken: String) {
        self.email = email
        self.masterToken = masterToken
    }
    
    func fetchNotes(completion: @escaping (Result<[Note], Error>) -> Void) {
        let urlString = "https://www.googleapis.com/notes/v1/notes"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(masterToken)", forHTTPHeaderField: "Authorization")
        
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
                completion(.success(response.notes ?? []))
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case text
    }
}

struct NotesResponse: Codable {
    let notes: [Note]?
}

enum APIError: Error {
    case invalidURL
    case noData
}