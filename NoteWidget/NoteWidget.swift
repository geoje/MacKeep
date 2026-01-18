import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry {
    SimpleEntry(
      note: Note(
        id: "placeholder", title: nil, text: "Loading...", parentId: "root", isArchived: false))
  }

  func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry
  {
    let selectedId = configuration.note?.id
    let notes = NoteManager.getSharedNotes()

    let note =
      notes.first(where: { $0.id == selectedId }) ?? notes.first
      ?? Note(
        id: "placeholder", title: "Title", text: "Content", parentId: "root",
        isArchived: false)
    return SimpleEntry(note: note)
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    let selectedId = configuration.note?.id
    let notes = NoteManager.getSharedNotes()

    let displayNote =
      notes.first(where: { $0.id == selectedId }) ?? notes.first
      ?? Note(
        id: "placeholder", title: nil, text: nil, parentId: "root", isArchived: false)

    let entry = SimpleEntry(note: displayNote)

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
    VStack(alignment: .leading, spacing: 4) {
      let hasContent = entry.note.text?.trimmingCharacters(in: .whitespaces).isEmpty == false
      let displayTitle =
        (entry.note.title ?? "").isEmpty && !hasContent ? "Untitled" : (entry.note.title ?? "")

      if !displayTitle.isEmpty {
        Text(displayTitle)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(2)
      }

      Text(entry.note.text?.isEmpty == false ? entry.note.text! : "No Content")
        .font(.system(size: 12))
        .lineLimit(entry.note.title != nil && !entry.note.title!.isEmpty ? 8 : 10)
        .foregroundColor(.secondary)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(backgroundColor(for: entry.note), for: .widget)
  }

  private func backgroundColor(for note: Note) -> Color {
    switch note.color?.uppercased() {
    case "YELLOW": return Color.yellow.opacity(0.22)
    case "GREEN": return Color.green.opacity(0.20)
    case "BLUE": return Color.blue.opacity(0.20)
    case "RED": return Color.red.opacity(0.20)
    case "ORANGE": return Color.orange.opacity(0.22)
    default: return Color.white
    }
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
