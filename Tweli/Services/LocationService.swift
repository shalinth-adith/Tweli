//
//  LocationService.swift
//  Tweli
//
//  Owns each partner's shared location and computes how far apart the two of you
//  are. Modeled on MoodService: one SharedLocation record per user (each writes
//  only their own), `myLocation`/`partnerLocation` filter by id, and the distance
//  is derived on-device from both.
//
//  Location is OPT-IN (the user taps "Use my location"), COARSE (city-level, for
//  privacy + battery), and refreshed at most once an hour on app foreground. The
//  partner's location arrives live via the Firestore listener.
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published private(set) var locations: [SharedLocation]
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    var currentUserId = UUID()   // set by AppViewModel.wireIdentities()
    var partnerId = UUID()
    var onDataChanged: (() -> Void)?

    private let cloud: FirebaseService
    private let manager = CLLocationManager()
    /// True while we're waiting on the permission prompt to fire a capture.
    private var pendingCapture = false

    /// Only re-capture our own location if the last fix is older than this.
    private let staleness: TimeInterval = 60 * 60   // 1 hour

    /// DEBUG-only lifecycle logging. Location is capture-driven (unlike moods,
    /// which are set by hand), so when the "N km apart" line is missing the break
    /// is almost always in capture/save/merge — these logs pinpoint which. Grep
    /// the device console for "[Location]".
    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[Location] \(message())")
        #endif
    }

    /// One-line snapshot of what the distance calc currently sees.
    private func logState(_ context: String) {
        #if DEBUG
        let mine = myLocation.map { "mine(\($0.cityLabel ?? "?") @\($0.latitude),\($0.longitude))" } ?? "mine(nil)"
        let theirs = partnerLocation.map { "partner(\($0.cityLabel ?? "?") @\($0.latitude),\($0.longitude))" } ?? "partner(nil)"
        let dist = distanceApartLabel ?? "nil"
        log("\(context): \(mine) · \(theirs) · distance=\(dist) · records=\(locations.count) · uid=\(currentUserId)")
        #endif
    }

    init(cloud: FirebaseService) {
        self.cloud = cloud
        self.locations = []
        self.authorizationStatus = .notDetermined
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // coarse / city-level
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Per-user records (mirrors MoodService)

    var myLocation: SharedLocation? { locations.first { $0.userId == currentUserId } }
    /// Any location NOT authored by me is the partner's — same reasoning as
    /// MoodService.partnerMood (profile UUIDs never cross devices; the local
    /// `partnerId` is fabricated and can't match). Newest wins if multiple.
    var partnerLocation: SharedLocation? {
        locations.filter { $0.userId != currentUserId }.max { $0.updatedAt < $1.updatedAt }
    }

    // MARK: - Distance (computed on-device, reactive)

    /// Straight-line distance between the two partners, in meters. `nil` until both
    /// have shared a location.
    var distanceApartMeters: Double? {
        guard let a = myLocation, let b = partnerLocation else { return nil }
        return Self.distanceMeters(from: a, to: b)
    }

    /// Locale-formatted distance, e.g. "4,213 km" (or miles in the US). `nil` until
    /// both partners have shared a location.
    var distanceApartLabel: String? {
        distanceApartMeters.map(Self.distanceLabel(meters:))
    }

    // Pure helpers (no CoreLocation permission / no service state) — unit-testable.

    nonisolated static func distanceMeters(from a: SharedLocation, to b: SharedLocation) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    nonisolated static func distanceLabel(meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale                 // km or mi per locale
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }

    // MARK: - Capture

    /// Called from "Use my location". Requests permission if needed, then captures.
    func requestAndCapture() {
        log("requestAndCapture: status=\(statusName(manager.authorizationStatus))")
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            captureNow()
        case .notDetermined:
            pendingCapture = true
            manager.requestWhenInUseAuthorization()
        default:
            log("requestAndCapture: denied/restricted → no capture, no distance")
        }
    }

    /// First-entry ask: when the user lands in the connected session and we've
    /// NEVER asked for location, raise the system prompt and capture on grant.
    /// One-shot by construction — after any decision the status is no longer
    /// .notDetermined, so this becomes a permanent no-op (denied users keep the
    /// manual-city fallback and the "Use my location" button in About you).
    func requestIfNeverAsked() {
        log("requestIfNeverAsked: status=\(statusName(manager.authorizationStatus))")
        guard manager.authorizationStatus == .notDetermined else { return }
        pendingCapture = true
        manager.requestWhenInUseAuthorization()
    }

    /// Foreground freshness check — the "every 1 hr" mechanism. Re-captures our own
    /// location only if we're already authorized and the last fix is stale.
    func refreshIfStale() {
        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways else {
            log("refreshIfStale: not authorized (\(statusName(manager.authorizationStatus))) → skip")
            return
        }
        if let mine = myLocation, Date().timeIntervalSince(mine.updatedAt) < staleness {
            log("refreshIfStale: my fix is fresh (\(Int(Date().timeIntervalSince(mine.updatedAt)))s) → skip")
            return
        }
        log("refreshIfStale: capturing (myLocation=\(myLocation == nil ? "nil" : "stale"))")
        captureNow()
    }

    private func captureNow() {
        log("captureNow: requesting one-shot fix…")
        manager.requestLocation()   // one-shot; delivers didUpdateLocations or didFailWithError
    }

    private func statusName(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }

    /// Upsert our own record (stable id per user, like MoodService) and sync it.
    private func setMyLocation(latitude: Double, longitude: Double,
                               cityLabel: String?, timeZoneId: String? = nil) {
        if let i = locations.firstIndex(where: { $0.userId == currentUserId }) {
            locations[i].latitude = latitude
            locations[i].longitude = longitude
            if let cityLabel { locations[i].cityLabel = cityLabel }
            if let timeZoneId { locations[i].timeZoneId = timeZoneId }
            locations[i].updatedAt = Date()
        } else {
            locations.append(SharedLocation(userId: currentUserId,
                                            latitude: latitude,
                                            longitude: longitude,
                                            cityLabel: cityLabel,
                                            timeZoneId: timeZoneId))
        }
        if let mine = myLocation {
            log("setMyLocation: saving \(mine.cityLabel ?? "?") @\(mine.latitude),\(mine.longitude) → Firestore")
            Task { await cloud.saveLocation(mine) }
        }
        logState("after setMyLocation")
        onDataChanged?()
    }

    /// Reverse-geocode a fresh fix into a city label, then store + sync it.
    private func handle(_ location: CLLocation) {
        // Store coordinates immediately; fill the city label when geocoding returns.
        setMyLocation(latitude: location.coordinate.latitude,
                      longitude: location.coordinate.longitude,
                      cityLabel: myLocation?.cityLabel)
        Task { [weak self] in
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            guard let self, let place = placemarks?.first else { return }
            // "City, Country" for display (e.g. "Chennai, India"). Falls back to
            // the finest available place name if the locality is missing.
            let city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea
            let joined = [city, place.country].compactMap { $0 }.joined(separator: ", ")
            let label = joined.isEmpty ? nil : joined
            // The placemark also carries the zone at those coordinates, which is
            // what lets the partner's device say "It's 11:04 PM in Abu Dhabi".
            let zone = place.timeZone?.identifier
            if label != nil || zone != nil {
                self.setMyLocation(latitude: location.coordinate.latitude,
                                   longitude: location.coordinate.longitude,
                                   cityLabel: label,
                                   timeZoneId: zone)
            }
        }
    }

    // MARK: - Remote merge (mirrors MoodService)

    func mergeRemote(_ items: [SharedLocation], deletedIDs: [UUID]) {
        if !items.isEmpty || !deletedIDs.isEmpty {
            log("mergeRemote: \(items.count) location record(s) in, \(deletedIDs.count) deletion(s); "
                + "authors=\(items.map { $0.userId == currentUserId ? "me" : "partner" })")
        }
        for item in items {
            if let i = locations.firstIndex(where: { $0.id == item.id }) { locations[i] = item }
            else { locations.append(item) }
        }
        if !deletedIDs.isEmpty { locations.removeAll { deletedIDs.contains($0.id) } }
        if !items.isEmpty || !deletedIDs.isEmpty { logState("after mergeRemote") }
    }

    // MARK: - CLLocationManagerDelegate (nonisolated → hop to main)

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.log("didUpdateLocations: got fix @\(location.coordinate.latitude),\(location.coordinate.longitude)")
            self.handle(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.log("didFailWithError: \(error.localizedDescription) — no fix captured this attempt")
            self.pendingCapture = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            self.log("authorization changed → \(self.statusName(status)) (pendingCapture=\(self.pendingCapture))")
            if self.pendingCapture,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                self.pendingCapture = false
                self.captureNow()
            }
        }
    }
}
