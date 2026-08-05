//
//  ThemeService.swift
//  Tweli
//
//  Backs the "Theme" row in Our space (comp L9 reads "Light", N9 reads "Dark",
//  B7 reads "Auto"). The choice is applied at the root as a
//  `preferredColorScheme`, which SwiftUI pushes down into the hosting
//  controller's trait collection — so the dynamic colors in DesignSystem.swift
//  resolve to the L or N palette without any view needing to know.
//

import SwiftUI
import Combine

enum TweliTheme: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: String { rawValue }

    /// The label shown in the Our space theme row.
    var label: String {
        switch self {
        case .auto:  return "Auto"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .auto:  return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark:  return "moon.stars"
        }
    }

    /// `nil` means "follow the system", which is what Auto does.
    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

@MainActor
final class ThemeService: ObservableObject {
    private static let key = "tweli.theme"

    @Published var theme: TweliTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.key) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? ""
        theme = TweliTheme(rawValue: stored) ?? .auto
    }

    /// Cycles Auto → Light → Dark → Auto, which is what tapping the row does.
    func advance() {
        let all = TweliTheme.allCases
        let next = (all.firstIndex(of: theme).map { $0 + 1 } ?? 0) % all.count
        theme = all[next]
    }
}
