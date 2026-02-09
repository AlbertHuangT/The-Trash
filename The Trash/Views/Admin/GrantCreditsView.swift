//
//  GrantCreditsView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine

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
                        Label("\(viewModel.participants.count) Participants", systemImage: "person.2.fill")
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        }
                    }
                }
                
                Section("Credits Settings") {
                    Stepper("Amount per user: \(creditsAmount)", value: $creditsAmount, in: 1...100)
                    TextField("Reason", text: $reason)
                }
                
                Section("Recipients") {
                    Toggle("Select All", isOn: Binding(
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
                            Button(action: { toggleSelection(for: participant.userId) }) {
                                HStack {
                                    Image(systemName: selectedUserIds.contains(participant.userId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedUserIds.contains(participant.userId) ? .blue : .secondary)

                                    VStack(alignment: .leading) {
                                        Text(participant.username)
                                            .foregroundColor(.primary)
                                        Text("Registered: \(participant.registeredAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("No registered participants yet.")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: grantCredits) {
                        HStack {
                            if isProcessing {
                                Spacer()
                                ProgressView()
                                Spacer()
                            } else {
                                Text("Grant \(creditsAmount * selectedUserIds.count) Credits Total")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .disabled(selectedUserIds.isEmpty || reason.isEmpty || isProcessing)
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Grant Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadParticipants()
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("Successfully granted \(creditsAmount) credits to \(grantedCount) users.")
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
        participants = await service.getEventParticipants(eventId: eventId)
        isLoading = false
    }
    
    func grantCredits(userIds: [UUID], amount: Int, reason: String) async -> GrantCreditsResult {
        return await service.grantEventCredits(
            eventId: eventId,
            userIds: userIds,
            creditsPerUser: amount,
            reason: reason
        )
    }
}
