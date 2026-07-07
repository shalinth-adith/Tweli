//
//  CloudKitService.swift
//  Tweli
//
//  PLACEHOLDER for Phase 5. Every method is a no-op today so the app runs on
//  mock data. When CloudKit is wired, these become real CKRecord operations:
//  personal items in the private DB, couple-shared items via a CKShare zone.
//

import Foundation
import Combine

@MainActor
final class CloudKitService: ObservableObject {

    // MARK: - Couple space / sharing

    func createCoupleSpace(_ space: CoupleSpace) async {
        // TODO: CloudKit — create a shared CKRecordZone + CKShare, return invite URL/QR.
    }

    func joinCoupleSpace(code: String) async -> CoupleSpace? {
        // TODO: CloudKit — accept a CKShare from an invite code/link/QR.
        return nil
    }

    // MARK: - Reminders

    func saveReminder(_ reminder: ReminderItem) async { /* TODO: CloudKit upsert */ }
    func deleteReminder(_ reminder: ReminderItem) async { /* TODO: CloudKit delete */ }
    func fetchReminders() async -> [ReminderItem] { [] /* TODO: CloudKit fetch */ }

    // MARK: - Countdowns

    func saveCountdown(_ countdown: CountdownItem) async { /* TODO */ }
    func deleteCountdown(_ countdown: CountdownItem) async { /* TODO */ }
    func fetchCountdowns() async -> [CountdownItem] { [] /* TODO */ }

    // MARK: - Open-when letters

    func saveLetter(_ letter: OpenWhenLetter) async { /* TODO */ }
    func fetchLetters() async -> [OpenWhenLetter] { [] /* TODO */ }

    // MARK: - Virtual dates

    func saveVirtualDate(_ date: VirtualDateItem) async { /* TODO */ }
    func fetchVirtualDates() async -> [VirtualDateItem] { [] /* TODO */ }

    // MARK: - Mood

    func saveMood(_ mood: MoodStatus) async { /* TODO */ }
    func fetchPartnerMood(partnerId: UUID) async -> MoodStatus? { nil /* TODO */ }

    // MARK: - Missing-you pings

    func sendPing(_ ping: MissingYouPing) async { /* TODO: CloudKit + partner notification */ }
    func fetchPings() async -> [MissingYouPing] { [] /* TODO */ }
}
