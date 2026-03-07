//
//  CreateEventFormSheet.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import SwiftUI

struct CreateEventFormSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var userSettings: UserSettings
    var onCreated: () -> Void
    private let theme = TrashTheme()

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(86400)
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50
    @State private var isPersonalEvent = true
    @State private var selectedCommunityId: String?

    @State private var isLoading = false
    @State private var isCheckingAllowance = true
    @State private var creationAllowed = true
    @State private var creationLimitMessage = "You can create up to 7 events per week."
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    let categories = ["cleanup", "workshop", "competition", "education", "other"]

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !location.trimmingCharacters(in: .whitespaces).isEmpty
            && eventDate > Date()
    }

    private var canSubmit: Bool {
        canCreate && creationAllowed && !isCheckingAllowance && !isLoading
            && (isPersonalEvent || selectedCommunityId != nil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TrashSegmentedControl(
                        options: [
                            TrashSegmentOption(
                                value: true,
                                title: "Personal Event",
                                icon: "person.crop.circle"
                            ),
                            TrashSegmentOption(
                                value: false,
                                title: "Community Event",
                                icon: "person.3.fill"
                            ),
                        ],
                        selection: $isPersonalEvent
                    )

                    if !isPersonalEvent {
                        if userSettings.adminCommunities.isEmpty {
                            HStack {
                                TrashIcon(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(theme.semanticWarning)
                                Text("You need to be a community admin to create community events")
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                        } else {
                            TrashOptionalFormPicker(
                                title: "Select Community",
                                selection: $selectedCommunityId,
                                options: [TrashOptionalPickerOption(value: nil, title: "Select...")]
                                    + userSettings.adminCommunities.map {
                                        TrashOptionalPickerOption(value: $0.id, title: $0.name)
                                    }
                            )
                        }
                    }
                } header: {
                    Text("Event Host")
                } footer: {
                    Text(
                        isPersonalEvent
                            ? "You will be shown as the organizer"
                            : "Only community admins can create community events"
                    )
                }

                Section("Event Details") {
                    TrashFormTextField(
                        title: "Event Title",
                        text: $title,
                        textInputAutocapitalization: .words
                    )
                    TrashFormTextEditor(text: $description, minHeight: 80)
                    TrashFormDatePicker(title: "Date & Time", selection: $eventDate, range: Date()...)
                    TrashFormTextField(
                        title: "Location",
                        text: $location,
                        textInputAutocapitalization: .words
                    )
                }

                Section("Settings") {
                    TrashFormPicker(
                        title: "Category",
                        selection: $category,
                        options: categories.map { category in
                            TrashPickerOption(
                                value: category,
                                title: category.capitalized,
                                icon: iconForCategory(category)
                            )
                        }
                    )

                    TrashFormStepper(
                        title: "Max Participants",
                        value: $maxParticipants,
                        range: 5...500,
                        step: 5
                    )
                }

                Section {
                    HStack(spacing: 12) {
                        TrashIcon(systemName: "info.circle.fill")
                            .foregroundColor(theme.accents.blue)
                        Text(creationLimitMessage)
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                        Spacer()
                        if isCheckingAllowance {
                            ProgressView()
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        HStack {
                            TrashIcon(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.semanticDanger)
                            Text(errorMessage)
                                .foregroundColor(theme.semanticDanger)
                                .font(theme.typography.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    TrashTextButton(title: "Create", variant: .accent, action: createEvent)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            }
                        }
                        .disabled(!canSubmit)
                }
            }
            .sheet(isPresented: $showSuccessAlert) {
                TrashNoticeSheet(
                    title: "Event Created!",
                    message: "Your event \"\(title)\" has been created successfully!",
                    onClose: {
                        showSuccessAlert = false
                        isPresented = false
                        onCreated()
                    }
                )
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
            .task {
                if userSettings.joinedCommunities.isEmpty {
                    await userSettings.loadMyCommunities()
                }
                await loadCreationAllowance()
            }
        }
    }

    private func createEvent() {
        guard canSubmit else { return }
        guard let userLocation = userSettings.selectedLocation else {
            errorMessage = "Please select a location first"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await EventService.shared.createEvent(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description,
                    category: category,
                    eventDate: eventDate,
                    location: location.trimmingCharacters(in: .whitespaces),
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude,
                    maxParticipants: maxParticipants,
                    communityId: isPersonalEvent ? nil : selectedCommunityId,
                    iconName: iconForCategory(category)
                )

                isLoading = false
                if result.success {
                    showSuccessAlert = true
                } else {
                    errorMessage = result.message
                }
            } catch {
                isLoading = false
                errorMessage = "Failed to create event: \(error.localizedDescription)"
            }
        }
    }

    private func loadCreationAllowance() async {
        isCheckingAllowance = true
        do {
            let result = try await EventService.shared.canCreateEvent()
            creationAllowed = result.allowed
            creationLimitMessage = result.allowed
                ? "You have created \(result.currentCount)/\(result.maxAllowed) events this week."
                : (result.reason ?? "You have reached your weekly event limit.")
        } catch {
            creationAllowed = true
            creationLimitMessage = "Could not verify the weekly event limit right now."
        }
        isCheckingAllowance = false
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "cleanup": return "leaf.fill"
        case "workshop": return "hammer.fill"
        case "competition": return "trophy.fill"
        case "education": return "book.fill"
        default: return "calendar"
        }
    }
}
