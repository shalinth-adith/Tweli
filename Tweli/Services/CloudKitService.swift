//
//  CloudKitService.swift
//  Tweli
//
//  Real CloudKit sync for the couple space (free — no server).
//
//  Design: one custom shared zone ("CoupleZone") holds a root "CoupleSpace"
//  record plus one child record per item. Each item is stored as a JSON blob in
//  a "payload" field (models are Codable), which keeps mapping tiny and robust.
//  A single CKShare on the root shares the whole hierarchy with the partner.
//
//  Owner (created the space) reads/writes the PRIVATE database; the partner who
//  accepted the share reads/writes the SHARED database.
//
//  NOTE: untested on this machine — CloudKit needs a device signed into iCloud
//  and a second account for the partner. Extensive logging is included for
//  on-device debugging. See README "CloudKit testing".
//

import Foundation
import Combine
import CloudKit

@MainActor
final class CloudKitService: ObservableObject {

    // MARK: - Config

    static let containerId = "iCloud.me.adithyan.shalinth.Tweli"
    static let zoneName = "CoupleZone"
    static let rootRecordName = "coupleSpaceRoot"

    let container = CKContainer(identifier: containerId)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    enum Role: String { case none, owner, participant }
    @Published private(set) var role: Role
    @Published private(set) var accountAvailable = false

    private let defaults = UserDefaults.standard
    private let roleKey = "tweli.ck.role"
    private let sharedZoneNameKey = "tweli.ck.sharedZoneName"
    private let sharedZoneOwnerKey = "tweli.ck.sharedZoneOwner"

    /// Record type names for each model.
    enum RType {
        static let reminder = "Reminder", countdown = "Countdown", letter = "Letter"
        static let virtualDate = "VirtualDate", mood = "Mood", ping = "Ping"
    }

    init() {
        role = Role(rawValue: defaults.string(forKey: roleKey) ?? "none") ?? .none
    }

    private func setRole(_ r: Role) { role = r; defaults.set(r.rawValue, forKey: roleKey) }

    // MARK: - Account

    func refreshAccountStatus() async {
        do {
            accountAvailable = (try await container.accountStatus()) == .available
        } catch {
            log("accountStatus error: \(error.localizedDescription)")
            accountAvailable = false
        }
    }

    // MARK: - Zone resolution

    private var ownerZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// The zone we read/write for the current role. Participant discovers the
    /// shared zone from the shared database (cached in UserDefaults).
    private func currentZoneID() async -> CKRecordZone.ID? {
        switch role {
        case .owner:
            return ownerZoneID
        case .participant:
            if let name = defaults.string(forKey: sharedZoneNameKey),
               let owner = defaults.string(forKey: sharedZoneOwnerKey) {
                return CKRecordZone.ID(zoneName: name, ownerName: owner)
            }
            // Discover from the shared DB.
            if let zone = try? await sharedDB.allRecordZones().first {
                defaults.set(zone.zoneID.zoneName, forKey: sharedZoneNameKey)
                defaults.set(zone.zoneID.ownerName, forKey: sharedZoneOwnerKey)
                return zone.zoneID
            }
            return nil
        case .none:
            return nil
        }
    }

    private var activeDB: CKDatabase { role == .participant ? sharedDB : privateDB }

    // MARK: - Sharing

    /// Creates the shared couple zone + root record + CKShare. Returns the share
    /// to present in a UICloudSharingController.
    func createShare(title: String) async throws -> CKShare {
        let zone = CKRecordZone(zoneID: ownerZoneID)
        _ = try? await privateDB.save(zone)

        let rootID = CKRecord.ID(recordName: Self.rootRecordName, zoneID: ownerZoneID)
        let root = CKRecord(recordType: "CoupleSpace", recordID: rootID)
        root["title"] = title as CKRecordValue

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "Join \(title) on Tweli 💞" as CKRecordValue
        // Anyone who opens the link can join — so a plain link shared in WhatsApp
        // etc. lets the partner in without being pre-invited by email/phone.
        share.publicPermission = .readWrite

        let (saveResults, _) = try await privateDB.modifyRecords(saving: [root, share], deleting: [])
        for (_, result) in saveResults { if case .failure(let e) = result { log("share save partial failure: \(e)") } }
        setRole(.owner)

        var saved = share
        if case .success(let rec)? = saveResults[share.recordID], let s = rec as? CKShare { saved = s }
        // The public URL is often nil on the just-saved object — re-fetch to get it.
        if saved.url == nil, let refetched = try? await privateDB.record(for: saved.recordID) as? CKShare {
            saved = refetched
        }
        log("created share for “\(title)” url=\(saved.url?.absoluteString ?? "nil")")
        return saved
    }

    /// Accepts an incoming share (partner tapped the invite link).
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        let zoneID = metadata.rootRecordID.zoneID
        defaults.set(zoneID.zoneName, forKey: sharedZoneNameKey)
        defaults.set(zoneID.ownerName, forKey: sharedZoneOwnerKey)
        setRole(.participant)
        log("accepted share in zone \(zoneID.zoneName)")
    }

    /// Owner side: the display name of the invited person once they've accepted
    /// the share, or nil if nobody has joined yet. Read from the CKShare's
    /// participant list on the root record.
    func acceptedParticipantName() async -> String? {
        guard role == .owner else { return nil }
        let rootID = CKRecord.ID(recordName: Self.rootRecordName, zoneID: ownerZoneID)
        guard let root = try? await privateDB.record(for: rootID),
              let shareRef = root.share,
              let share = try? await privateDB.record(for: shareRef.recordID) as? CKShare
        else { return nil }

        for p in share.participants where p.role != .owner && p.acceptanceStatus == .accepted {
            if let comps = p.userIdentity.nameComponents {
                let name = PersonNameComponentsFormatter.localizedString(from: comps, style: .default)
                if !name.isEmpty { return name }
            }
            return "Your partner"
        }
        return nil
    }

    // MARK: - Generic item CRUD (JSON payload)

    private func save<T: Codable>(_ item: T, id: UUID, type: String) async {
        guard role != .none, let zoneID = await currentZoneID() else { return }
        let db = activeDB
        let recID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            let record: CKRecord
            if let existing = try? await db.record(for: recID) {
                record = existing
            } else {
                record = CKRecord(recordType: type, recordID: recID)
                let rootID = CKRecord.ID(recordName: Self.rootRecordName, zoneID: zoneID)
                record.setParent(rootID)   // keeps the item inside the shared hierarchy
            }
            record["payload"] = try JSONEncoder().encode(item) as CKRecordValue
            _ = try await db.save(record)
        } catch {
            log("save \(type) failed: \(error.localizedDescription)")
        }
    }

    private func delete(id: UUID) async {
        guard role != .none, let zoneID = await currentZoneID() else { return }
        let recID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        _ = try? await activeDB.deleteRecord(withID: recID)
    }

    // MARK: - Fetch changes (remote → local)

    /// Everything currently in the shared zone, grouped by record type, plus the
    /// ids that were deleted since the last fetch.
    struct RemoteChanges {
        var payloadsByType: [String: [Data]] = [:]
        var deletedIDs: [UUID] = []
    }

    func fetchChanges() async -> RemoteChanges {
        guard role != .none, let zoneID = await currentZoneID() else { return .init() }
        var out = RemoteChanges()
        do {
            let result = try await activeDB.recordZoneChanges(inZoneWith: zoneID, since: changeToken(for: zoneID))
            for (_, res) in result.modificationResultsByID {
                if case .success(let mod) = res,
                   let data = mod.record["payload"] as? Data {
                    out.payloadsByType[mod.record.recordType, default: []].append(data)
                }
            }
            for deletion in result.deletions {
                if let uuid = UUID(uuidString: deletion.recordID.recordName) { out.deletedIDs.append(uuid) }
            }
            saveChangeToken(result.changeToken, for: zoneID)
        } catch {
            log("fetchChanges failed: \(error.localizedDescription)")
        }
        return out
    }

    // MARK: - Change tokens (per zone)

    private func tokenKey(_ zoneID: CKRecordZone.ID) -> String {
        "tweli.ck.token.\(zoneID.zoneName).\(zoneID.ownerName)"
    }
    private func changeToken(for zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        guard let data = defaults.data(forKey: tokenKey(zoneID)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }
    private func saveChangeToken(_ token: CKServerChangeToken, for zoneID: CKRecordZone.ID) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            defaults.set(data, forKey: tokenKey(zoneID))
        }
    }

    // MARK: - Push subscription

    /// Registers a zone subscription so changes wake the app (needs the Remote
    /// notifications background mode — add in Xcode).
    func registerSubscription() async {
        guard role != .none, let zoneID = await currentZoneID() else { return }
        let sub = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "tweli-zone-sub")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push
        sub.notificationInfo = info
        _ = try? await activeDB.save(sub)
    }

    // MARK: - Reset

    func reset() {
        setRole(.none)
        [sharedZoneNameKey, sharedZoneOwnerKey].forEach { defaults.removeObject(forKey: $0) }
    }

    private func log(_ msg: String) { print("[CloudKit] \(msg)") }

    // MARK: - Typed wrappers (called by the feature services)

    func createCoupleSpace(_ space: CoupleSpace) async { /* share is created via createShare() from the UI */ }

    func saveReminder(_ r: ReminderItem) async { await save(r, id: r.id, type: RType.reminder) }
    func deleteReminder(_ r: ReminderItem) async { await delete(id: r.id) }

    func saveCountdown(_ c: CountdownItem) async { await save(c, id: c.id, type: RType.countdown) }
    func deleteCountdown(_ c: CountdownItem) async { await delete(id: c.id) }

    func saveLetter(_ l: OpenWhenLetter) async { await save(l, id: l.id, type: RType.letter) }
    func saveVirtualDate(_ d: VirtualDateItem) async { await save(d, id: d.id, type: RType.virtualDate) }
    func saveMood(_ m: MoodStatus) async { await save(m, id: m.id, type: RType.mood) }
    func sendPing(_ p: MissingYouPing) async { await save(p, id: p.id, type: RType.ping) }
}
