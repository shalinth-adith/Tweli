//
//  AddReminderView.swift
//  Tweli
//

import SwiftUI

struct AddReminderView: View {
    @EnvironmentObject private var app: AppViewModel
    @EnvironmentObject private var service: ReminderService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AddReminderViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reminder title", text: $vm.title)
                    TextField("Add a small note ❤️", text: $vm.note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Assigned to") {
                    Picker("Assigned to", selection: $vm.assignedTo) {
                        ForEach(ReminderAssignee.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("When") {
                    DatePicker("Date", selection: $vm.date, displayedComponents: .date)
                    DatePicker("Time", selection: $vm.time, displayedComponents: .hourAndMinute)
                    Picker("Repeat", selection: $vm.repeatType) {
                        ForEach(RepeatType.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Options") {
                    Picker("Visibility", selection: $vm.visibility) {
                        ForEach(ReminderVisibility.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Priority", selection: $vm.priority) {
                        ForEach(ReminderPriority.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!vm.canSave)
                }
            }
        }
    }

    private func save() {
        guard let spaceId = app.coupleSpaceService.coupleSpace?.id else { return }
        let reminder = vm.build(createdBy: app.currentUser.id, coupleSpaceId: spaceId)
        service.add(reminder)
        dismiss()
    }
}
