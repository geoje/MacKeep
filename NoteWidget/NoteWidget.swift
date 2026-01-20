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
    print("[Widget] snapshot called")
    let selectedId = configuration.note?.id
    print("[Widget] selectedId: \(selectedId ?? "nil")")

    return await withCheckedContinuation { continuation in
      NoteManager.getNotesFromGoogleKeep { notes in
        print("[Widget] snapshot - received notes count: \(notes.count)")
        let note =
          notes.first(where: { $0.id == selectedId }) ?? notes.first
          ?? Note(
            id: "placeholder", title: "Title", text: "Content", parentId: "root",
            isArchived: false)
        print("[Widget] snapshot - selected note: \(note.title ?? "no title")")
        continuation.resume(returning: SimpleEntry(note: note))
      }
    }
  }

  func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<
    SimpleEntry
  > {
    print("[Widget] timeline called")
    let selectedId = configuration.note?.id
    print("[Widget] selectedId: \(selectedId ?? "nil")")

    return await withCheckedContinuation { continuation in
      NoteManager.getNotesFromGoogleKeep { notes in
        print("[Widget] timeline - received notes count: \(notes.count)")
        let displayNote =
          notes.first(where: { $0.id == selectedId }) ?? notes.first
          ?? Note(
            id: "placeholder", title: nil, text: nil, parentId: "root", isArchived: false)
        print("[Widget] timeline - selected note: \(displayNote.title ?? "no title")")

        let entry = SimpleEntry(note: displayNote)

        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        print("[Widget] timeline - next update: \(nextUpdate)")
        continuation.resume(returning: Timeline(entries: [entry], policy: .after(nextUpdate)))
      }
    }
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
    case "RED": return Color(red: 0.95, green: 0.76, blue: 0.76)
    case "ORANGE": return Color(red: 0.98, green: 0.85, blue: 0.70)
    case "YELLOW": return Color(red: 0.99, green: 0.95, blue: 0.70)
    case "GREEN": return Color(red: 0.80, green: 0.92, blue: 0.77)
    case "TEAL": return Color(red: 0.64, green: 0.87, blue: 0.85)
    case "BLUE": return Color(red: 0.81, green: 0.89, blue: 0.95)
    case "DARK_BLUE": return Color(red: 0.56, green: 0.77, blue: 0.95)
    case "PURPLE": return Color(red: 0.82, green: 0.77, blue: 0.91)
    case "PINK": return Color(red: 0.97, green: 0.77, blue: 0.86)
    case "BROWN": return Color(red: 0.91, green: 0.84, blue: 0.78)
    case "GRAY": return Color(red: 0.89, green: 0.89, blue: 0.89)
    default: return Color(red: 1.0, green: 1.0, blue: 1.0)
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
