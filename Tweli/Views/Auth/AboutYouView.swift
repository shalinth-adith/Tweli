//
//  AboutYouView.swift
//  Tweli
//
//  Design 20a/20b — "A little about you". Shown once, right after first sign-in,
//  before Create / Join. Collects photo, name, birthday and city so the partner
//  always sees the right name, day and local time. Everything is stored on the
//  local profile; the name flows to the partner via the space's member map.
//

import SwiftUI
import PhotosUI

struct AboutYouView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var couple: CoupleSpaceService
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss

    /// When true, the screen is opened from Settings to edit an existing profile
    /// (Cancel/Save + dismiss) instead of the first-run onboarding step.
    var isEditing = false

    @State private var name = ""
    @State private var birthday: Date? = nil
    @State private var city = ""
    @State private var photoData: Data? = nil
    @State private var photoItem: PhotosPickerItem?
    @State private var showBirthdaySheet = false

    private let timezone = TimeZone.current

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 0) {
                    photoPicker.padding(.top, 18)

                    VStack(spacing: 8) {
                        Text("A little about you")
                            .font(.system(size: 28, weight: .heavy)).kerning(-0.6)
                            .foregroundStyle(.primary)
                        Text("So your person always sees the right\nname, day and time on their side.")
                            .font(.system(size: 14.5)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22).padding(.bottom, 26)

                    field(label: "Your name", focused: true) {
                        HStack(spacing: 10) {
                            icon("person", tint: Brand.pink)
                            TextField("Your name", text: $name)
                                .font(.system(size: 17, weight: .semibold))
                                .submitLabel(.done)
                        }
                    }

                    field(label: "Your birthday") {
                        Button { showBirthdaySheet = true } label: {
                            HStack(spacing: 10) {
                                icon("calendar", tint: .secondary)
                                Text(birthday.map(Self.birthdayFormat) ?? "Add your birthday")
                                    .font(.system(size: 17))
                                    .foregroundStyle(birthday == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    field(label: "Your city") {
                        HStack(spacing: 10) {
                            icon("mappin.and.ellipse", tint: .secondary)
                            TextField("Where you are", text: $city)
                                .font(.system(size: 17))
                            // Auto-fill the city + capture coordinates for the
                            // "how far apart" distance. Manual entry stays available.
                            Button { location.requestAndCapture() } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Brand.pink)
                            }
                            .buttonStyle(.plain)
                            Text(gmtLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(.tertiary)
                        Text("Only your partner ever sees this.")
                            .font(.system(size: 12.5)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14).padding(.horizontal, 4)
                }
                .padding(.horizontal, 22).padding(.bottom, 20)
            }

            BrandCTA(title: isEditing ? "Save" : "Continue", showsArrow: !isEditing) {
                save()
                if isEditing { dismiss() } else { app.finishAboutYou() }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            // Prefill the name from Apple / the stored profile.
            if name.isEmpty {
                let existing = couple.currentUser.displayName
                name = existing.isEmpty ? auth.displayName : existing
            }
            if birthday == nil { birthday = couple.currentUser.birthday }
            if city.isEmpty { city = couple.currentUser.city ?? "" }
            if photoData == nil { photoData = couple.currentUser.photoData }
        }
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        // When a location fix reverse-geocodes to a city, fill the field with it.
        .onChange(of: location.myLocation?.cityLabel) { _, label in
            if let label, !label.isEmpty { city = label }
        }
        .sheet(isPresented: $showBirthdaySheet) { birthdaySheet }
    }

    // MARK: - Top bar (skip / edit title)

    private var topBar: some View {
        HStack {
            if isEditing {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .frame(width: 60, height: 34, alignment: .leading)
            } else {
                Color.clear.frame(width: 60, height: 34)
            }
            Spacer()
            if isEditing {
                Text("Edit profile").font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            if !isEditing {
                Button("Skip") { save(); app.finishAboutYou() }
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                    .frame(width: 60, height: 34, alignment: .trailing)
            } else {
                Color.clear.frame(width: 60, height: 34)
            }
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: - Photo

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let photoData, let ui = UIImage(data: photoData) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        Brand.youGradient()
                            .overlay(Text(initial).font(.system(size: 38, weight: .semibold)).foregroundStyle(.white))
                    }
                }
                .frame(width: 96, height: 96).clipShape(Circle())
                .shadow(color: Brand.indigo.opacity(0.3), radius: 12, y: 8)

                Circle().fill(Brand.pink)
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 13)).foregroundStyle(.white))
                    .overlay(Circle().strokeBorder(Color(UIColor.systemGroupedBackground), lineWidth: 3))
            }
        }
        .buttonStyle(.plain)
    }

    private var initial: String {
        let n = name.isEmpty ? auth.displayName : name
        return n.first.map { String($0).uppercased() } ?? "·"
    }

    // MARK: - Birthday sheet

    private var birthdaySheet: some View {
        NavigationStack {
            DatePicker("Birthday",
                       selection: Binding(get: { birthday ?? defaultBirthday },
                                          set: { birthday = $0 }),
                       in: ...Date(),
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .navigationTitle("Your birthday")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showBirthdaySheet = false }
                    }
                }
            Spacer()
        }
        .presentationDetents([.height(360)])
    }

    private var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    // MARK: - Helpers

    private func field<Content: View>(label: String, focused: Bool = false,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold)).kerning(0.5)
                .textCase(.uppercase).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            content()
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(focused ? Brand.pink.opacity(0.35) : .clear, lineWidth: 1.5)
                )
        }
        .padding(.bottom, 18)
    }

    private func icon(_ name: String, tint: Color) -> some View {
        Image(systemName: name).font(.system(size: 18, weight: .medium)).foregroundStyle(tint).frame(width: 22)
    }

    private var gmtLabel: String {
        let secs = timezone.secondsFromGMT()
        let sign = secs >= 0 ? "+" : "-"
        let h = abs(secs) / 3600, m = (abs(secs) % 3600) / 60
        return String(format: "GMT %@%d:%02d", sign, h, m)
    }

    private static func birthdayFormat(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else { return }
            // Downscale + compress to a small square avatar (keeps storage tiny).
            let square = ui.squareAvatar(side: 256)
            await MainActor.run { photoData = square.jpegData(compressionQuality: 0.8) }
        }
    }

    private func save() {
        couple.updateProfile(name: name, birthday: birthday,
                             city: city.isEmpty ? nil : city,
                             timezoneIdentifier: timezone.identifier,
                             photoData: photoData)
    }
}

private extension UIImage {
    /// Center-crops to a square and resizes to `side` points for a compact avatar.
    func squareAvatar(side: CGFloat) -> UIImage {
        let minEdge = min(size.width, size.height)
        let crop = CGRect(x: (size.width - minEdge) / 2, y: (size.height - minEdge) / 2,
                          width: minEdge, height: minEdge)
        guard let cg = cgImage?.cropping(to: crop) else { return self }
        let cropped = UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
        let target = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: target).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
