//
//  ClosenessStripView.swift
//  Tweli
//
//  The "closeness" band under the mood card (comp L3 / N3):
//
//      ⊕ 2,912 km apart                        ♥ 21 days to go
//
//  Two tap targets: the left ("N km apart") opens the distance globe; the right
//  is the reunion — "N days to go" once a meet date is set, otherwise "Set meet
//  date" — and opens the "When do you meet?" sheet.
//
//  Comp geometry: radius 14, padding 12/16, a 120° info-blue wash with a
//  matching hairline. Only the distance number carries the blue; everything else
//  is tertiary ink so the band stays quiet next to the hero card above it.
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
    /// Tap the left half — open the distance globe.
    var onOpenDistance: () -> Void
    /// Tap the left half when distance isn't ready — request/refresh my location.
    var onShareLocation: () -> Void
    /// Tap the right half — open the "When do you meet?" sheet.
    var onSetMeet: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: distanceLabel != nil ? onOpenDistance : onShareLocation) {
                if distanceLabel != nil { distanceHalf } else { locationPromptHalf }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onSetMeet) { reunionHalf }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.twInfo.opacity(0.11), Color.twInfo.opacity(0.035)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: TweliMetrics.bandRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TweliMetrics.bandRadius, style: .continuous)
                .strokeBorder(Color.twInfo.opacity(0.22), lineWidth: 1)
        }
    }

    // MARK: - Left: distance

    private var distanceHalf: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.twInfo)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(distanceLabel ?? "")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(Color.twInfo)
                    .lineLimit(1)
                Text("apart")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.twInkTertiary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Left (fallback): share-location / waiting-for-partner prompt

    private var locationPromptHalf: some View {
        HStack(spacing: 8) {
            Image(systemName: hasMyLocation ? "location.slash" : "location.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(hasMyLocation ? "Waiting for partner" : "Share location")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(hasMyLocation ? Color.twInkTertiary : Color.twInfo)
        .contentShape(Rectangle())
    }

    // MARK: - Right: reunion countdown / "Set meet date"

    private var reunionHalf: some View {
        HStack(spacing: 6) {
            Image(systemName: daysToReunion == nil ? "calendar.badge.plus" : "heart.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.twAccent)
            Text(reunionText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(daysToReunion == nil ? Color.twAccentInk : Color.twInkTertiary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private var reunionText: String {
        guard let days = daysToReunion else { return "Set meet date" }
        if days <= 0 { return "Together today!" }
        if days == 1 { return "1 day to go" }
        return "\(days) days to go"
    }
}
