//
//  AddVirtualDateViewModel.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class AddVirtualDateViewModel: ObservableObject {
    @Published var title = ""
    @Published var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var notes = ""
    @Published var reminderEnabled = true

    var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    func build(createdBy: UUID, coupleSpaceId: UUID) -> VirtualDateItem {
        VirtualDateItem(title: title.trimmingCharacters(in: .whitespaces),
                        date: date,
                        notes: notes,
                        coupleSpaceId: coupleSpaceId,
                        createdBy: createdBy,
                        reminderEnabled: reminderEnabled)
    }
}
