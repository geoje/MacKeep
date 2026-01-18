import AppIntents
import Foundation
import WidgetKit

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
    let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!
    guard let data = defaults.data(forKey: "notes"),
      let notes = try? JSONDecoder().decode([Note].self, from: data)
    else {
      return []
    }

    let entities = notes.map { note in
      let displayTitle = note.title ?? note.text ?? "Untitled"
      return WidgetNoteEntity(id: note.id, title: displayTitle)
    }
    return entities
  }

  nonisolated func defaultResult() async -> [WidgetNoteEntity]? {
    let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!
    guard let data = defaults.data(forKey: "notes"),
      let notes = try? JSONDecoder().decode([Note].self, from: data)
    else {
      return []
    }

    let entities = notes.map { note in
      let displayTitle = note.title ?? note.text ?? "Untitled"
      return WidgetNoteEntity(id: note.id, title: displayTitle)
    }
    return entities
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
