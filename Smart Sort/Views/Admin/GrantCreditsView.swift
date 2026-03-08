//
//  GrantCreditsView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import SwiftUI

struct GrantCreditsView: View {
    let event: CommunityEvent
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: GrantCreditsViewModel
    @State private var creditsAmount: Int = 20
    @State private var reason: String = ""
    @State private var selectedUserIds: Set<UUID> = []
    @State private var selectAll = false
    @State private var isProcessing = false
    @State private var showSuccessAlert = false
    @State private var grantedCount = 0
    private let theme = TrashTheme()

    init(event: CommunityEvent) {
        self.event = event
        _viewModel = StateObject(wrappedValue: GrantCreditsViewModel(eventId: event.id))
        _reason = State(initialValue: "Participated in \(event.title)")
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Event Info")
                        Text(event.title)
                            .font(theme.typography.headline)
                            .foregroundColor(theme.palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            TrashPill(
                                title: "\(viewModel.participants.count) Participants",
                                icon: "person.2.fill",
                                color: theme.accents.blue,
                                isSelected: false
                            )
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Credits Settings")
                        TrashFormStepper(
                            title: "Amount per user",
                            value: $creditsAmount,
                            range: 1...100
                        )
                        TrashFormTextField(
                            title: "Reason",
                            text: $reason,
                            textInputAutocapitalization: .sentences
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Recipients")
                        TrashFormToggle(
                            title: "Select All",
                            isOn: Binding(
                                get: { selectAll },
                                set: { newValue in
                                    selectAll = newValue
                                    if newValue {
                                        selectedUserIds = Set(viewModel.participants.map { $0.userId })
                                    } else {
                                        selectedUserIds.removeAll()
                                    }
                                }
                            )
                        )

                        if !viewModel.participants.isEmpty {
                            LazyVStack(spacing: theme.layout.elementSpacing) {
                                ForEach(viewModel.participants) { participant in
                                    participantRow(participant)
                                }
                            }
                        } else {
                            Text("No registered participants yet.")
                                .font(theme.typography.caption)
                                .foregroundColor(theme.palette.textSecondary)
                        }
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Grant Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadParticipants()
            }
            .safeAreaInset(edge: .bottom) {
                TrashButton(baseColor: theme.accents.blue, action: grantCredits) {
                    HStack(spacing: theme.spacing.sm) {
                        if isProcessing {
                            ProgressView()
                                .tint(theme.onAccentForeground)
                        } else {
                            Text("Grant \(creditsAmount * selectedUserIds.count) Credits Total")
                                .font(theme.typography.subheadline.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .trashOnAccentForeground()
                }
                .disabled(selectedUserIds.isEmpty || reason.isEmpty || isProcessing)
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.elementSpacing)
                .padding(.bottom, theme.layout.elementSpacing)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showSuccessAlert) {
                TrashNoticeSheet(
                    title: "Success",
                    message:
                        "Successfully granted \(creditsAmount) credits to \(grantedCount) users.",
                    buttonTitle: "Done",
                    onClose: {
                        showSuccessAlert = false
                        dismiss()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
        }
    }

    private func participantRow(_ participant: EventParticipantResponse) -> some View {
        TrashTapArea(action: { toggleSelection(for: participant.userId) }) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                TrashIcon(
                    systemName: selectedUserIds.contains(participant.userId)
                        ? "checkmark.circle.fill" : "circle"
                )
                .foregroundColor(
                    selectedUserIds.contains(participant.userId)
                        ? theme.accents.blue : theme.palette.textSecondary
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.username)
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textPrimary)
                    Text(
                        "Registered: \(participant.registeredAt.formatted(date: .abbreviated, time: .shortened))"
                    )
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                    .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.vertical, theme.layout.elementSpacing)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.palette.card.opacity(0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.75), lineWidth: 1)
                    )
            )
        }
    }

    private func toggleSelection(for userId: UUID) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
            selectAll = false
        } else {
            selectedUserIds.insert(userId)
            if selectedUserIds.count == viewModel.participants.count {
                selectAll = true
            }
        }
    }

    private func grantCredits() {
        isProcessing = true
        Task {
            let result = await viewModel.grantCredits(
                userIds: Array(selectedUserIds),
                amount: creditsAmount,
                reason: reason
            )

            isProcessing = false
            if result.success {
                grantedCount = result.grantedCount
                showSuccessAlert = true
            }
        }
    }
}

@MainActor
class GrantCreditsViewModel: ObservableObject {
    @Published var participants: [EventParticipantResponse] = []
    @Published var isLoading = false

    let eventId: UUID
    private let eventService = EventService.shared

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func loadParticipants() async {
        isLoading = true
        do {
            participants = try await eventService.getEventParticipants(eventId: eventId)
        } catch {
            print("❌ Get event participants error: \(error)")
        }
        isLoading = false
    }

    func grantCredits(userIds: [UUID], amount: Int, reason: String) async -> GrantCreditsResult {
        do {
            return try await eventService.grantEventCredits(
                eventId: eventId,
                userIds: userIds,
                creditsPerUser: amount,
                reason: reason
            )
        } catch {
            print("❌ Grant credits error: \(error)")
            return GrantCreditsResult(success: false, message: "Grant failed", grantedCount: 0)
        }
    }
}
