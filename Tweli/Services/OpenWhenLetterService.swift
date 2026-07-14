//
//  OpenWhenLetterService.swift
//  Tweli
//

import Foundation
import Combine

@MainActor
final class OpenWhenLetterService: ObservableObject {

    @Published private(set) var letters: [OpenWhenLetter]

    var onDataChanged: (() -> Void)?
    private let cloud: FirebaseService

    init(cloud: FirebaseService) {
        self.cloud = cloud
#if DEBUG
        self.letters = MockData.letters   // demo data for design/dev builds only
#else
        self.letters = []
#endif
    }

    var unopened: [OpenWhenLetter] { letters.filter { !$0.isOpened } }
    var opened: [OpenWhenLetter] { letters.filter { $0.isOpened } }

    func add(_ letter: OpenWhenLetter) {
        letters.append(letter)
        Task { await cloud.saveLetter(letter) }
        onDataChanged?()
    }

    func markOpened(_ letter: OpenWhenLetter) {
        guard let i = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        guard !letters[i].isLocked else { return }
        letters[i].isOpened = true
        letters[i].openedAt = Date()
        Task { await cloud.saveLetter(letters[i]) }
        onDataChanged?()
    }

    func delete(_ letter: OpenWhenLetter) {
        letters.removeAll { $0.id == letter.id }
        onDataChanged?()
    }

    func mergeRemote(_ items: [OpenWhenLetter], deletedIDs: [UUID]) {
        for item in items {
            if let i = letters.firstIndex(where: { $0.id == item.id }) { letters[i] = item }
            else { letters.append(item) }
        }
        if !deletedIDs.isEmpty { letters.removeAll { deletedIDs.contains($0.id) } }
    }
}
