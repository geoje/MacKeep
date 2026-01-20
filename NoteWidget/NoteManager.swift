import Foundation

struct NoteManager {
  static func getSharedNotes() -> [Note] {
    let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!
    guard let data = defaults.data(forKey: "nodes") else {
      return []
    }

    guard let allNotes = try? JSONDecoder().decode([Note].self, from: data) else {
      return []
    }

    let filteredNotes = allNotes.filter {
      $0.parentId == "root" && ($0.isArchived ?? false) == false
    }

    let mappedNotes = filteredNotes.map { note in
      var mutableNote = note
      let childTexts =
        allNotes
        .filter { $0.parentId == note.id }
        .compactMap { $0.text?.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
      mutableNote.text = childTexts.joined(separator: "\n")
      return mutableNote
    }

    return mappedNotes
  }

  static func getNotesFromGoogleKeep(completion: @escaping ([Note]) -> Void) {
    print("[NoteManager] getNotesFromGoogleKeep called")
    let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!

    guard let email = defaults.string(forKey: "email"),
      let masterToken = defaults.string(forKey: "masterToken")
    else {
      print("[NoteManager] ❌ Missing email or masterToken in UserDefaults")
      completion([])
      return
    }

    print("[NoteManager] ✅ Found credentials - email: \(email)")
    let deviceId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(16)
      .uppercased()

    // Try cached token first
    let now = Date()
    if let cachedToken = defaults.string(forKey: "cachedAuthToken"),
      let cachedExpiry = defaults.object(forKey: "cachedAuthTokenExpiry") as? Double
    {
      let expiryDate = Date(timeIntervalSince1970: cachedExpiry)
      if expiryDate > now.addingTimeInterval(60) {  // 60s clock skew buffer
        print("[NoteManager] Using cached OAuth token (valid until: \(expiryDate))")
        return fetchNotes(with: cachedToken, completion: completion)
      } else {
        print("[NoteManager] Cached OAuth token expired at: \(expiryDate)")
      }
    }

    print("[NoteManager] Requesting new OAuth token...")
    let gpsAuthAPI = GPSAuthAPI()
    gpsAuthAPI.performOAuth(email: email, masterToken: masterToken, deviceId: String(deviceId)) {
      authResult in
      switch authResult {
      case .success(let oauth):
        print("[NoteManager] ✅ OAuth token obtained: \(oauth.token.prefix(20))...")
        if let expiry = oauth.expiry {
          defaults.set(expiry.timeIntervalSince1970, forKey: "cachedAuthTokenExpiry")
          print("[NoteManager] Cached token expiry set to: \(expiry)")
        } else {
          defaults.removeObject(forKey: "cachedAuthTokenExpiry")
          print("[NoteManager] Token expiry not provided; no expiry cached")
        }
        defaults.set(oauth.token, forKey: "cachedAuthToken")

        fetchNotes(with: oauth.token, completion: completion)
      case .failure(let error):
        print("[NoteManager] ❌ OAuth token request failed: \(error.localizedDescription)")
        completion([])
      }
    }
  }

  private static func fetchNotes(with authToken: String, completion: @escaping ([Note]) -> Void) {
    print("[NoteManager] Fetching notes from Google Keep API...")
    let api = GoogleKeepAPI()
    api.fetchNotes(authToken: authToken) { result in
      switch result {
      case .success(let allNotes):
        print("[NoteManager] ✅ API call successful! Total notes: \(allNotes.count)")
        let filteredNotes = allNotes.filter {
          $0.parentId == "root" && ($0.isArchived ?? false) == false
            && ($0.timestamps?.trashed == nil || !$0.timestamps!.trashed!.starts(with: "2"))
        }
        print("[NoteManager] Filtered notes count: \(filteredNotes.count)")

        let mappedNotes = filteredNotes.map { note in
          var mutableNote = note
          let childTexts =
            allNotes
            .filter { $0.parentId == note.id }
            .compactMap { $0.text?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
          mutableNote.text = childTexts.joined(separator: "\n")
          return mutableNote
        }
        print("[NoteManager] Final notes to return: \(mappedNotes.count)")
        completion(mappedNotes)
      case .failure(let error):
        print("[NoteManager] ❌ API call failed: \(error.localizedDescription)")
        completion([])
      }
    }
  }
}
