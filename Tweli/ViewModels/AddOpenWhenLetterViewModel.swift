//
//  AddOpenWhenLetterViewModel.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class AddOpenWhenLetterViewModel: ObservableObject {
    @Published var title = ""
    @Published var message = ""
    @Published var useUnlockDate = false
    @Published var unlockDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func build(createdBy: UUID, coupleSpaceId: UUID) -> OpenWhenLetter {
        OpenWhenLetter(title: title.trimmingCharacters(in: .whitespaces),
                       message: message,
                       createdBy: createdBy,
                       coupleSpaceId: coupleSpaceId,
                       unlockDate: useUnlockDate ? unlockDate : nil)
    }
}
