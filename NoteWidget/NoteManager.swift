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
}
