//
//  SharedLocation.swift
//  Tweli
//
//  One partner's shared location — used to show how far apart the two of you are.
//  Like MoodStatus, there is exactly one record per user (each person writes only
//  their own); the distance is computed on-device from both. Coordinates are
//  coarse (city-level), captured opt-in — see LocationService.
//

import Foundation

/// A record that names which member of the couple wrote it, using the app's
/// device-local profile UUID. That id is not stable across reinstalls, so the
/// sync layer re-stamps it from the record's Firebase `authorUid` — see
/// `AppViewModel.applyRemote`. Conformance is what opts a model into that.
protocol LocallyAuthored {
    var userId: UUID { get set }
}

/// Decides whether an incoming record was written by this user, and normalises
/// its local id when it was.
///
/// This is the whole of the "8 m apart" fix, kept as a pure static so it can be
/// tested. Inline in `AppViewModel.applyRemote` it was unreachable without a
/// live Firestore listener — which is exactly how the original bug survived.
enum RecordAuthorship {

    /// Decode one synced payload, re-stamping `userId` when `authorUid` says I
    /// wrote it.
    ///
    /// `authorUid` is the Firebase uid and is stable across reinstalls. The
    /// `userId` inside the payload is a device-local UUID that is regenerated
    /// whenever the local profile is recreated, so on its own it cannot answer
    /// "is this mine?" — and a stale one makes the user's own records look like
    /// their partner's.
    ///
    /// Falls through untouched when the uid is unknown or empty, so an offline
    /// or signed-out state degrades to the previous behaviour rather than
    /// mis-attributing everything to one person.
    static func decode<T: Decodable>(_ type: T.Type,
                                     from data: Data,
                                     decoder: JSONDecoder,
                                     authorUid: String,
                                     myUid: String?,
                                     myLocalId: UUID) -> T? {
        guard var item = try? decoder.decode(T.self, from: data) else { return nil }
        guard let myUid, !myUid.isEmpty, !authorUid.isEmpty, authorUid == myUid,
              var authored = item as? any LocallyAuthored
        else { return item }
        authored.userId = myLocalId
        item = authored as! T
        return item
    }
}

struct SharedLocation: Identifiable, Codable, Hashable, LocallyAuthored {
    var id: UUID = UUID()
    var userId: UUID
    var latitude: Double
    var longitude: Double
    /// Reverse-geocoded place name for display, e.g. "Austin, TX". Optional.
    var cityLabel: String? = nil
    /// IANA identifier for the time zone at these coordinates, e.g.
    /// "Asia/Dubai". Captured alongside `cityLabel` during reverse geocoding and
    /// used by the Home banner to say what time it is where your partner is
    /// (comp L3: "It's 10:34 AM in Abu Dhabi — Anaya is starting her day").
    /// Optional so records written before this field decode cleanly.
    var timeZoneId: String? = nil
    var updatedAt: Date = Date()
}
