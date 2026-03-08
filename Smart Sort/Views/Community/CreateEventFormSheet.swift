//
//  CreateEventFormSheet.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import CoreLocation
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Event Host")

                        TrashSegmentedControl(
                        options: [
                            TrashSegmentOption(
                                value: true,
                                title: "Personal",
                                icon: "person.crop.circle"
                            ),
                            TrashSegmentOption(
                                value: false,
                                title: "Community",
                                icon: "person.3.fill"
                            ),
                        ],
                        selection: $isPersonalEvent
                    )

                    if !isPersonalEvent {
                        if userSettings.adminCommunities.isEmpty {
                            messageCard(
                                "You need to be a community admin to create community events",
                                color: theme.semanticWarning,
                                icon: "exclamationmark.triangle.fill"
                            )
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
                    Text(
                        isPersonalEvent
                            ? "You will be shown as the organizer"
                            : "Only community admins can create community events"
                    )
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Event Details")
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
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Settings")
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
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        HStack(spacing: theme.spacing.sm) {
                            TrashIcon(systemName: "info.circle.fill")
                                .foregroundColor(theme.accents.blue)
                            Text("Weekly Allowance")
                                .font(theme.typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.palette.textPrimary)
                            Spacer()
                            if isCheckingAllowance {
                                ProgressView()
                            }
                        }

                        Text(creationLimitMessage)
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    if let errorMessage {
                        messageCard(errorMessage, color: theme.semanticDanger, icon: "exclamationmark.triangle.fill")
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
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
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            TrashTextButton(title: "Create", variant: .accent, action: createEvent)
                                .disabled(!canSubmit)
                        }
                    }
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
                .presentationDetents([.medium, .large])
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

    private func messageCard(_ message: String, color: Color, icon: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            TrashIcon(systemName: icon)
                .foregroundColor(color)
            Text(message)
                .foregroundColor(theme.palette.textPrimary)
                .font(theme.typography.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
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
                let coordinates = try await resolveEventCoordinates(
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    userLocation: userLocation
                )
                let result = try await EventService.shared.createEvent(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description,
                    category: category,
                    eventDate: eventDate,
                    location: location.trimmingCharacters(in: .whitespaces),
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude,
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

    private func resolveEventCoordinates(
        location: String,
        userLocation: UserLocation
    ) async throws -> CLLocationCoordinate2D {
        let geocoder = CLGeocoder()
        let candidateQueries = [
            location,
            "\(location), \(userLocation.city), \(userLocation.state)",
        ]

        for query in candidateQueries {
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let placemarks = try? await geocoder.geocodeAddressString(query)
            if let coordinate = placemarks?.first?.location?.coordinate {
                return coordinate
            }
        }

        throw NSError(
            domain: "CreateEventFormSheet",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Couldn't find that event location. Please enter a more specific address."
            ]
        )
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
