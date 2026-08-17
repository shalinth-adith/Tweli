//
//  ReinstallGate.swift
//  Tweli
//
//  Comps K1–K5. Whether this device has run Tweli before — the one fact that has
//  to survive the app being deleted.
//
//  UserDefaults cannot answer it. iOS erases an app's whole container on delete,
//  defaults included, which is exactly why a reinstall currently looks identical
//  to a first launch: same tutorial, same "Remind us." front door, no
//  acknowledgement that the person has been here before. The Keychain is the
//  only store iOS leaves behind, so it holds the marker and nothing else does.
//
//  What is kept is deliberately thin: a schema version and one boolean for
//  "this device was paired". No name, no space id, no dates. Those all come back
//  from the account after sign-in, where they belong — see comps K2/K3 — and the
//  Keychain copy would outlive the uninstall for no benefit the account doesn't
//  already provide.
//
//  `hadPair` earns its place because it is the difference between two honest
//  screens and one dishonest one: without it, "signed in, no space found" is
//  indistinguishable from a first-time user, and K5 ("she left while you were
//  away") could not be told apart from "you have never paired".
//
//  Device-level, like TutorialGate. Deleting the account clears it (`forget()`),
//  because at that point there is no account for the marker to describe.
//

import Foundation
import Security

struct ReinstallGate {

    /// What this launch is, decided once and read from two stores that fail
    /// differently: the Keychain survives a delete, UserDefaults does not.
    enum Launch: Equatable {
        /// Nothing in the Keychain — genuinely the first time on this device.
        case firstInstall
        /// Keychain remembers us, the container does not. The app was deleted
        /// and put back, or restored onto a new phone from an encrypted backup.
        case reinstall(hadPair: Bool)
        /// Both stores agree. The ordinary launch, and by far the common one.
        case sameInstall
    }

    /// Written on every launch. Its ABSENCE next to a live Keychain record is
    /// the whole signal.
    static let defaultsKey = "tweli.installSeen"

    private static let service = "com.tweli.install"
    private static let account = "device-history"

    private let defaults: UserDefaults
    /// Overridable so tests can exercise the logic against a scratch record
    /// instead of the real device Keychain.
    private let store: KeychainRecordStore

    init(defaults: UserDefaults = .standard,
         store: KeychainRecordStore = SystemKeychain()) {
        self.defaults = defaults
        self.store = store
    }

    // MARK: - Reading

    /// Classify this launch. Call ONCE, at composition time — after
    /// `markInstalled()` runs this necessarily reports `.sameInstall`, and a
    /// view that re-read it mid-session would lose the reinstall flow the
    /// moment anything invalidated it.
    var launch: Launch {
        let record = store.read(service: Self.service, account: Self.account)
            .flatMap { try? JSONDecoder().decode(Record.self, from: $0) }

        guard let record else { return .firstInstall }
        guard !defaults.bool(forKey: Self.defaultsKey) else { return .sameInstall }
        return .reinstall(hadPair: record.hadPair)
    }

    // MARK: - Writing

    /// Claim this launch: stamp the container so the next one is ordinary, and
    /// lay down the Keychain marker if it isn't there yet. Never downgrades
    /// `hadPair` — a reinstall must not forget that this device was paired.
    func markInstalled() {
        defaults.set(true, forKey: Self.defaultsKey)
        // Forced to disk, deliberately.
        //
        // UserDefaults flushes on its own schedule. Force-quitting the app
        // before that flush lands loses the key — and a missing container key
        // next to a live Keychain record is EXACTLY the signature of a
        // reinstall, so the whole K1–K5 flow ran again on an ordinary relaunch.
        // Reported from a real device: reinstall, use the app, force-quit,
        // reopen, and the welcome-back sequence played a second time.
        //
        // `synchronize()` is deprecated for routine use and correctly so, but
        // this is the one case it exists for: a single small write whose loss
        // changes what screen the user sees, on a path where the process may be
        // killed seconds later.
        defaults.synchronize()

        guard current() == nil else { return }
        write(Record(hadPair: false))
    }

    /// Called the moment two people are actually in a space. From here on a
    /// reinstall that finds no space is comp K5, not "you have never paired".
    func markPaired() {
        guard current()?.hadPair != true else { return }
        write(Record(hadPair: true))
    }

    /// Erase the marker. Only for account deletion: the account it described is
    /// gone, so the next launch should be a genuine first install. Leaving a
    /// space does NOT call this — the device has still run Tweli, and the person
    /// may pair again.
    func forget() {
        defaults.removeObject(forKey: Self.defaultsKey)
        store.delete(service: Self.service, account: Self.account)
    }

    // MARK: - Record

    private struct Record: Codable {
        var version = 1
        var hadPair: Bool
    }

    private func current() -> Record? {
        store.read(service: Self.service, account: Self.account)
            .flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
    }

    private func write(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        store.write(data, service: Self.service, account: Self.account)
    }
}

// MARK: - Keychain access

/// The two operations ReinstallGate needs, behind a protocol so the gate's logic
/// is testable without touching the device Keychain (which a unit-test host
/// cannot rely on having an entitlement for).
protocol KeychainRecordStore {
    func read(service: String, account: String) -> Data?
    func write(_ data: Data, service: String, account: String)
    func delete(service: String, account: String)
}

struct SystemKeychain: KeychainRecordStore {

    func read(service: String, account: String) -> Data? {
        var query = Self.base(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func write(_ data: Data, service: String, account: String) {
        let query = Self.base(service: service, account: account)
        // Update first: SecItemAdd on an existing item returns errSecDuplicateItem
        // rather than replacing it, so an add-only implementation would silently
        // never upgrade `hadPair` from false to true.
        let updated = SecItemUpdate(query as CFDictionary,
                                    [kSecValueData as String: data] as CFDictionary)
        guard updated != errSecSuccess else { return }

        var insert = query
        insert[kSecValueData as String] = data
        // NOT `ThisDeviceOnly`: an encrypted backup restored onto a new phone
        // should still say "welcome back", which is the case comp K1 draws
        // ("New phone, new install"). A device-only item would be dropped by
        // exactly that migration.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insert as CFDictionary, nil)
    }

    func delete(service: String, account: String) {
        SecItemDelete(Self.base(service: service, account: account) as CFDictionary)
    }

    private static func base(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// In-memory stand-in for tests and for the DEBUG launch overrides, which need
/// to fake a reinstall on a simulator without writing to the real Keychain.
final class InMemoryKeychain: KeychainRecordStore {
    private var items: [String: Data] = [:]

    init(seeded: [String: Data] = [:]) { items = seeded }

    private func key(_ service: String, _ account: String) -> String { "\(service)/\(account)" }

    func read(service: String, account: String) -> Data? { items[key(service, account)] }
    func write(_ data: Data, service: String, account: String) { items[key(service, account)] = data }
    func delete(service: String, account: String) { items[key(service, account)] = nil }
}
