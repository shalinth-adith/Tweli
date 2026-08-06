//
//  KeepsakeExport.swift
//  Tweli
//
//  Comp W1 "Export your letters — a keepsake of everything you two wrote".
//
//  Deliberately plain text rather than a PDF or an archive: it opens anywhere,
//  survives the app being gone, and is the one artefact a user takes with them
//  when they delete. Sealed letters are listed but NOT opened — a letter's whole
//  promise is that it waits for its moment, and an export is not that moment.
//

import Foundation

enum KeepsakeExport {

    /// Builds the keepsake. Everything here comes from records already on the
    /// device; nothing is fetched, so this works offline and during deletion.
    static func build(spaceTitle: String,
                      myName: String,
                      partnerName: String,
                      startedOn: Date?,
                      letters: [OpenWhenLetter],
                      moods: [MoodStatus],
                      myUserId: UUID) -> String {
        var out: [String] = []
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .none

        out.append("TWELI — \(spaceTitle)")
        out.append(String(repeating: "=", count: 48))
        out.append("\(myName) & \(partnerName)")
        if let startedOn {
            let days = Calendar.current.dateComponents(
                [.day], from: Calendar.current.startOfDay(for: startedOn),
                to: Calendar.current.startOfDay(for: Date())).day ?? 0
            out.append("Threaded since \(df.string(from: startedOn)) · \(days) days")
        }
        out.append("Exported \(df.string(from: Date()))")
        out.append("")

        // --- Letters, oldest first, so it reads as a story.
        let ordered = letters.sorted { $0.createdAt < $1.createdAt }
        let opened = ordered.filter { !$0.isLocked }
        let sealed = ordered.filter(\.isLocked)

        out.append("LETTERS (\(ordered.count))")
        out.append(String(repeating: "-", count: 48))
        if ordered.isEmpty { out.append("None yet.") }

        for letter in opened {
            let author = letter.createdBy == myUserId ? myName : partnerName
            out.append("")
            out.append(letter.title)
            out.append("From \(author) · \(df.string(from: letter.createdAt))")
            out.append("")
            out.append(letter.message)
            out.append("")
            out.append(String(repeating: "·", count: 24))
        }

        if !sealed.isEmpty {
            out.append("")
            out.append("STILL SEALED (\(sealed.count))")
            out.append(String(repeating: "-", count: 48))
            out.append("These haven't reached their moment yet, so their words")
            out.append("aren't printed here — only that they exist.")
            for letter in sealed {
                let author = letter.createdBy == myUserId ? myName : partnerName
                let when = letter.unlockDate.map { df.string(from: $0) } ?? "someday"
                out.append("  · \(letter.title) — from \(author), opens \(when)")
            }
        }

        // --- Moods, newest first: a log of how the days actually felt.
        let moodLog = moods.sorted { $0.updatedAt > $1.updatedAt }
        out.append("")
        out.append("MOODS (\(moodLog.count))")
        out.append(String(repeating: "-", count: 48))
        if moodLog.isEmpty { out.append("None yet.") }
        for mood in moodLog {
            let who = mood.userId == myUserId ? myName : partnerName
            var line = "\(df.string(from: mood.updatedAt)) — \(who): \(mood.displayLabel)"
            if let note = mood.note, !note.isEmpty { line += " — “\(note)”" }
            out.append(line)
        }

        out.append("")
        out.append(String(repeating: "=", count: 48))
        out.append("Two time zones. One thread.")
        return out.joined(separator: "\n")
    }

    /// Writes the keepsake to a temporary file so the share sheet offers "Save to
    /// Files" and Mail attachment rather than dumping the whole thing as a body.
    static func writeToTemporaryFile(_ contents: String, partnerName: String) -> URL? {
        let safePartner = partnerName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let name = safePartner.isEmpty ? "Tweli-letters.txt" : "Tweli-\(safePartner).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("[Keepsake] write failed: \(error.localizedDescription)")
            return nil
        }
    }
}
