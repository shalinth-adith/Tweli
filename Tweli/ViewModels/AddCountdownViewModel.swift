//
//  AddCountdownViewModel.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class AddCountdownViewModel: ObservableObject {
    @Published var title = ""
    @Published var targetDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published var includeTime = false
    @Published var note = ""
    @Published var category: CountdownCategory = .custom
    @Published var pinToHome = false

    var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func build(createdBy: UUID, coupleSpaceId: UUID) -> CountdownItem {
        CountdownItem(title: title.trimmingCharacters(in: .whitespaces),
                      targetDate: targetDate,
                      note: note,
                      category: category,
                      isPinned: pinToHome,
                      createdBy: createdBy,
                      coupleSpaceId: coupleSpaceId)
    }
}
