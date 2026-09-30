import Foundation
import Observation

struct Note: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var text: String
}

/// Quick notes, newest first, persisted as JSON in Application Support.
@MainActor @Observable
final class NotesStore {
    private(set) var notes: [Note] = []
    /// Unsaved input, kept while the panel is closed.
    var draft = ""
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = NotesStore.defaultURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Note].self, from: data) {
            notes = saved
        }
    }

    func add(_ text: String, date: Date = .now) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.insert(Note(date: date, text: trimmed), at: 0)
        save()
    }

    func remove(_ id: Note.ID) {
        notes.removeAll { $0.id == id }
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(notes).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Matrix: could not save notes: \(error)")
        }
    }

    nonisolated static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Matrix/notes.json")
    }
}
