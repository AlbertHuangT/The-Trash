//
//  CreateEventSheet.swift
//  Smart Sort
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct CreateEventSheet: View {
    @Binding var isPresented: Bool
    private let theme = TrashTheme()
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date()
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50
    @State private var showNotImplementedAlert = false

    let categories = ["cleanup", "workshop", "competition", "education", "other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TrashFormTextField(title: "Event Title", text: $title, textInputAutocapitalization: .words)
                    TrashFormTextField(title: "Description", text: $description, textInputAutocapitalization: .sentences)
                    TrashFormDatePicker(title: "Date & Time", selection: $eventDate)
                    TrashFormTextField(title: "Location", text: $location, textInputAutocapitalization: .words)
                }

                Section("Settings") {
                    TrashFormPicker(
                        title: "Category",
                        selection: $category,
                        options: categories.map { TrashPickerOption(value: $0, title: $0.capitalized, icon: nil) }
                    )

                    TrashFormStepper(title: "Max Participants", value: $maxParticipants, range: 10...500, step: 10)
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    TrashTextButton(title: "Create", variant: .accent) {
                        showNotImplementedAlert = true
                    }
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
            .sheet(isPresented: $showNotImplementedAlert) {
                TrashNoticeSheet(
                    title: "Coming Soon",
                    message: "Event creation from community pages is coming soon. Use the Events tab to create events for now.",
                    onClose: {
                        showNotImplementedAlert = false
                        isPresented = false
                    }
                )
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
        }
    }
}
