//
//  GrantCreditsView.swift
//  The Trash
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
    @Environment(\.trashTheme) private var theme

    init(event: CommunityEvent) {
        self.event = event
        _viewModel = StateObject(wrappedValue: GrantCreditsViewModel(eventId: event.id))
        _reason = State(initialValue: "Participated in \(event.title)")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Event Info") {
                    Text(event.title)
                        .font(.headline)
                    HStack {
                        TrashLabel(
                            "\(viewModel.participants.count) Participants", icon: "person.2.fill")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                }

                Section("Credits Settings") {
                    TrashFormStepper(
                        title: "Amount per user", value: $creditsAmount, range: 1...100)
                    TrashFormTextField(
                        title: "Reason", text: $reason, textInputAutocapitalization: .sentences)
                }

                Section("Recipients") {
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
                        ))

                    if !viewModel.participants.isEmpty {
                        ForEach(viewModel.participants) { participant in
                            TrashTapArea(action: { toggleSelection(for: participant.userId) }) {
                                HStack {
                                    TrashIcon(
                                        systemName: selectedUserIds.contains(participant.userId)
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .foregroundColor(
                                        selectedUserIds.contains(participant.userId)
                                            ? .blue : .secondary)

                                    VStack(alignment: .leading) {
                                        Text(participant.username)
                                            .foregroundColor(.primary)
                                        Text(
                                            "Registered: \(participant.registeredAt.formatted(date: .abbreviated, time: .shortened))"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No registered participants yet.")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    TrashButton(baseColor: theme.accents.blue, action: grantCredits) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(theme.onAccentForeground)
                            } else {
                                Text("Grant \(creditsAmount * selectedUserIds.count) Credits Total")
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .trashOnAccentForeground()
                        .padding(.vertical, 8)
                    }
                    .disabled(selectedUserIds.isEmpty || reason.isEmpty || isProcessing)
                }
            }
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
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
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
    private let service = CommunityService.shared

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func loadParticipants() async {
        isLoading = true
        do {
            participants = try await service.getEventParticipants(eventId: eventId)
        } catch {
            print("❌ Get event participants error: \(error)")
        }
        isLoading = false
    }

    func grantCredits(userIds: [UUID], amount: Int, reason: String) async -> GrantCreditsResult {
        do {
            return try await service.grantEventCredits(
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
