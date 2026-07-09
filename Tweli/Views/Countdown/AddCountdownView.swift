//
//  AddCountdownView.swift
//  Tweli
//

import SwiftUI

struct AddCountdownView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: CountdownService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddCountdownViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Countdown title", text: $vm.title)
                    TextField("Add a note", text: $vm.note, axis: .vertical).lineLimit(2...4)
                }
                Section("When") {
                    DatePicker("Date", selection: $vm.targetDate,
                               displayedComponents: vm.includeTime ? [.date, .hourAndMinute] : .date)
                    Toggle("Include time", isOn: $vm.includeTime)
                }
                Section("Category") {
                    Picker("Category", selection: $vm.category) {
                        ForEach(CountdownCategory.allCases) { Label($0.label, systemImage: $0.sfSymbol).tag($0) }
                    }
                }
                Section {
                    Toggle("Pin to Home", isOn: $vm.pinToHome)
                }
            }
            .navigationTitle("New Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!vm.canSave)
                }
            }
        }
    }

    private func save() {
        guard let spaceId = app.coupleSpaceService.coupleSpace?.id else { return }
        service.add(vm.build(createdBy: app.currentUser.id, coupleSpaceId: spaceId))
        dismiss()
    }
}
