//
//  AddOpenWhenLetterView.swift
//  Tweli
//

import SwiftUI

struct AddOpenWhenLetterView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: OpenWhenLetterService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddOpenWhenLetterViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Letter") {
                    TextField("Open when… (e.g. you miss me)", text: $vm.title)
                    TextField("Your message", text: $vm.message, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section {
                    Toggle("Lock until a date", isOn: $vm.useUnlockDate)
                    if vm.useUnlockDate {
                        DatePicker("Unlock on", selection: $vm.unlockDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Letter")
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
        let spaceId = app.coupleSpaceService.coupleSpace?.id ?? MockData.spaceId
        service.add(vm.build(createdBy: app.currentUser.id, coupleSpaceId: spaceId))
        dismiss()
    }
}
