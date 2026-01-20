import AppIntents
import Foundation
import WidgetKit

struct WidgetNoteEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Note"

  static var defaultQuery = WidgetNoteQuery()

  let id: String
  let title: String
  let subtitle: String?

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: .init(stringLiteral: title.isEmpty ? "Untitled" : title),
      subtitle: subtitle.map { .init(stringLiteral: $0) }
    )
  }
}

struct WidgetNoteQuery: EntityQuery {
  private func loadNotes() async -> [Note] {
    await withCheckedContinuation { continuation in
      NoteManager.getNotesFromGoogleKeep { notes in
        continuation.resume(returning: notes)
      }
    }
  }

  func suggestedEntities() async throws -> [WidgetNoteEntity] {
    let notes = await loadNotes()
    let entities = notes.map { note in
      let trimmedTitle = note.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let displayTitle = !trimmedTitle.isEmpty ? trimmedTitle : "Untitled"
      let textPreview = (note.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let subtitle = textPreview.isEmpty ? nil : String(textPreview.prefix(60))
      return WidgetNoteEntity(id: note.id, title: displayTitle, subtitle: subtitle)
    }
    return entities
  }

  nonisolated func defaultResult() async -> [WidgetNoteEntity]? {
    let notes = await withCheckedContinuation { continuation in
      NoteManager.getNotesFromGoogleKeep { notes in
        continuation.resume(returning: notes)
      }
    }

    return notes.map { note in
      let trimmedTitle = note.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let displayTitle = !trimmedTitle.isEmpty ? trimmedTitle : "Untitled"
      let textPreview = (note.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let subtitle = textPreview.isEmpty ? nil : String(textPreview.prefix(60))
      return WidgetNoteEntity(id: note.id, title: displayTitle, subtitle: subtitle)
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
