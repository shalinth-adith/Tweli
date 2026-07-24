//
//  ClosenessStripView.swift
//  Tweli
//
//  The blue "closeness" band under the mood card (designs 21a/b). Two tap
//  targets: the left ("N km apart") opens the animated distance journey; the
//  right is the reunion — "N days to go" once a meet date is set, otherwise
//  "Set meet date" — and opens the "When do you meet?" sheet (which syncs the
//  date to both partners).
//

import SwiftUI

struct ClosenessStripView: View {
    /// Distance between the two shared locations, e.g. "8,432 km". `nil` until
    /// BOTH partners have shared a location — then the left half becomes a
    /// prompt (share your location / waiting for your partner) instead.
    let distanceLabel: String?
    /// Whether *my* location has been captured/shared yet.
    let hasMyLocation: Bool
    /// Whole days until the reunion (pinned "meeting" countdown). `nil` ⇒ no
    /// meet date set yet → the right half invites you to set one.
    let daysToReunion: Int?
    /// Tap the left half — open the animated distance journey.
    var onOpenDistance: () -> Void
    /// Tap the left half when distance isn't ready — request/refresh my location.
    var onShareLocation: () -> Void
    /// Tap the right half — open the "When do you meet?" sheet.
    var onSetMeet: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if distanceLabel != nil {
                Button(action: onOpenDistance) { distanceHalf }
                    .buttonStyle(.plain)
            } else {
                Button(action: onShareLocation) { locationPromptHalf }
                    .buttonStyle(.plain)
            }
            divider
            Button(action: onSetMeet) { reunionHalf }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.twInfo.opacity(0.13), Color.twInkTertiary.opacity(0.06)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.twInfo.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.twInfo.opacity(0.18))
            .frame(width: 1, height: 22)
    }

    // MARK: - Left: distance

    private var distanceHalf: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.twInfo)
            HStack(spacing: 5) {
                Text(distanceLabel ?? "")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.twInfo)
                    .lineLimit(1)
                Text("apart")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.twInfo.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Left (fallback): share-location / waiting-for-partner prompt

    private var locationPromptHalf: some View {
        HStack(spacing: 7) {
            Image(systemName: hasMyLocation ? "location.slash" : "location.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(hasMyLocation ? "Waiting for partner" : "Share location")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.85)
            if !hasMyLocation {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.twInfo.opacity(0.5))
            }
        }
        .foregroundStyle(hasMyLocation ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.twInfo))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Right: reunion countdown / "Set meet date"

    private var reunionHalf: some View {
        HStack(spacing: 6) {
            Image(systemName: daysToReunion == nil ? "calendar.badge.plus" : "airplane")
                .font(.system(size: 13, weight: .semibold))
            Text(reunionText)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.twAccent.opacity(0.5))
        }
        .foregroundStyle(Color.twAccent)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var reunionText: String {
        guard let days = daysToReunion else { return "Set meet date" }
        if days <= 0 { return "Together today!" }
        if days == 1 { return "1 day to go" }
        return "\(days) days to go"
    }
}
