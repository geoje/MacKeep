import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
  private func getSharedNotes() -> [Note] {
    let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!
    guard let data = defaults.data(forKey: "notes"),
      let notes = try? JSONDecoder().decode([Note].self, from: data)
    else {
      return []
    }
    return notes
  }

  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(
      note: Note(
        id: "placeholder", title: nil, text: "Loading...", parentId: "root", isArchived: false))
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    let selectedId = configuration.note?.id
    let notes = getSharedNotes()

    let note =
      notes.first(where: { $0.id == selectedId }) ?? notes.first(where: {
        $0.parentId == "root" && ($0.isArchived ?? false) == false
      })
      ?? Note(
        id: "placeholder", title: "Title", text: "Content", parentId: "root",
        isArchived: false)
    return SimpleEntry(note: note)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    let selectedId = configuration.note?.id
    let notes = getSharedNotes()
    let note: Note

    if let selected = notes.first(where: { $0.id == selectedId }) {
      note = selected
    } else if let firstNote = notes.first(where: {
      $0.parentId == "root" && ($0.isArchived ?? false) == false
    }) {
      note = firstNote
    } else if !notes.isEmpty {
      note = notes[0]
    } else {
      let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!
      let hasToken = defaults.string(forKey: "authToken") != nil
      let message = hasToken ? "Tap to refresh notes" : "Open Mac Keep app to connect"
      note = Note(
        id: "placeholder", title: nil, text: message, parentId: "root", isArchived: false)
    }

    let entry = SimpleEntry(note: note)

    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
    return Timeline(entries: [entry], policy: .after(nextUpdate))
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date = Date()
  let note: Note
}

struct NoteWidgetEntryView: View {
  var entry: Provider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title = entry.note.title, !title.isEmpty {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(2)
      }

      if let text = entry.note.text, !text.isEmpty {
        Text(text)
          .font(.system(size: 14))
          .lineLimit(entry.note.title != nil ? 8 : 10)
          .foregroundColor(.secondary)
      }

      if entry.note.title == nil && (entry.note.text == nil || entry.note.text!.isEmpty) {
        Text("Empty note")
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(12)
    .containerBackground(.fill.tertiary, for: .widget)
  }
}

struct NoteWidget: Widget {
  let kind: String = "NoteWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) {
      entry in
      NoteWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Selected Keep Note")
    .description("Displays one selected note from Google Keep.")
  }
}
