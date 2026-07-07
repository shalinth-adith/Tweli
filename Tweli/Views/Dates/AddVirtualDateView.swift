//
//  AddVirtualDateView.swift
//  Tweli
//

import SwiftUI

struct AddVirtualDateView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: VirtualDateService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddVirtualDateViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Date title (e.g. Movie night)", text: $vm.title)
                    TextField("Notes", text: $vm.notes, axis: .vertical).lineLimit(2...4)
                }
                Section("When") {
                    DatePicker("Date & time", selection: $vm.date, displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Toggle("Remind us 30 min before", isOn: $vm.reminderEnabled)
                }
            }
            .navigationTitle("New Virtual Date")
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
