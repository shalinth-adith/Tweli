//
//  MissingYouPing.swift
//  Tweli
//

import Foundation

/// A tiny emotional ping sent between partners ("Shalinth misses you ❤️").
struct MissingYouPing: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var message: String
    var sentBy: UUID
    var sentTo: UUID
    var coupleSpaceId: UUID
    var sentAt: Date = Date()

    /// Relative label like "2h ago" for the history list.
    var relativeLabel: String {
        sentAt.formatted(.relative(presentation: .named))
    }
}

/// The preset ping messages shown as quick buttons on the Missing You screen.
enum MissingYouPreset: String, CaseIterable, Identifiable {
    case missYou = "Miss you"
    case thinkingOfYou = "Thinking of you"
    case sendHug = "Send a hug"
    case needYou = "Need you"
    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .missYou: return "heart.fill"
        case .thinkingOfYou: return "sparkles"
        case .sendHug: return "hands.clap.fill"
        case .needYou: return "heart.circle.fill"
        }
    }

    /// Warm message body actually delivered to the partner.
    func message(from name: String) -> String {
        switch self {
        case .missYou: return "\(name) misses you ❤️"
        case .thinkingOfYou: return "\(name) is thinking of you"
        case .sendHug: return "A small hug from far away 🫂"
        case .needYou: return "Your person needs you 💗"
        }
    }
}
