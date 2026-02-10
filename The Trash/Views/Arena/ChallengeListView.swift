//
//  ChallengeListView.swift
//  The Trash
//
//  Challenge inbox: pending challenges received, in-progress, and completed.
//

import SwiftUI
import Supabase
import Combine

struct ChallengeListView: View {
    @StateObject private var viewModel = ChallengeListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: ArenaChallenge?
    @State private var showDuel = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.neuBackground
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.challenges.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Pending section
                            if !viewModel.pendingChallenges.isEmpty {
                                sectionHeader("Pending")
                                ForEach(viewModel.pendingChallenges) { challenge in
                                    ChallengeRow(
                                        challenge: challenge,
                                        currentUserId: viewModel.currentUserId,
                                        onAccept: {
                                            selectedChallenge = challenge
                                            showDuel = true
                                        },
                                        onDecline: {
                                            Task { await viewModel.decline(challengeId: challenge.id) }
                                        }
                                    )
                                }
                            }

                            // In progress section
                            if !viewModel.activeChallenges.isEmpty {
                                sectionHeader("In Progress")
                                ForEach(viewModel.activeChallenges) { challenge in
                                    ChallengeRow(
                                        challenge: challenge,
                                        currentUserId: viewModel.currentUserId,
                                        onAccept: {
                                            selectedChallenge = challenge
                                            showDuel = true
                                        },
                                        onDecline: nil
                                    )
                                }
                            }

                            // Completed section
                            if !viewModel.completedChallenges.isEmpty {
                                sectionHeader("Completed")
                                ForEach(viewModel.completedChallenges) { challenge in
                                    ChallengeRow(
                                        challenge: challenge,
                                        currentUserId: viewModel.currentUserId,
                                        onAccept: nil,
                                        onDecline: nil
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.neuAccentBlue)
                }
            }
            .task {
                await viewModel.fetchChallenges()
            }
            .fullScreenCover(isPresented: $showDuel) {
                if let challenge = selectedChallenge {
                    DuelView(
                        challengeId: challenge.id,
                        opponentId: nil,
                        isAccepting: challenge.status == "pending" && challenge.opponentId == viewModel.currentUserId
                    )
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.neuSecondaryText)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.neuSecondaryText)
            Text("No challenges yet")
                .font(.headline)
                .foregroundColor(.neuText)
            Text("Challenge a friend to start a duel!")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// MARK: - Challenge Row

struct ChallengeRow: View {
    let challenge: ArenaChallenge
    let currentUserId: UUID?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?

    var isChallenger: Bool {
        challenge.challengerId == currentUserId
    }

    var opponentName: String {
        isChallenger ? (challenge.opponentName ?? "Opponent") : (challenge.challengerName ?? "Challenger")
    }

    var statusColor: Color {
        switch challenge.status {
        case "pending": return .orange
        case "accepted", "in_progress": return .neuAccentBlue
        case "completed": return challenge.winnerId == currentUserId ? .green : .red
        case "declined", "cancelled", "expired": return .gray
        default: return .neuSecondaryText
        }
    }

    var statusText: String {
        switch challenge.status {
        case "pending":
            return isChallenger ? "Waiting..." : "Incoming!"
        case "accepted", "in_progress":
            return "In Progress"
        case "completed":
            if challenge.winnerId == nil { return "Tie" }
            return challenge.winnerId == currentUserId ? "Won!" : "Lost"
        case "declined": return "Declined"
        case "cancelled": return "Cancelled"
        case "expired": return "Expired"
        default: return challenge.status
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar placeholder
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(statusColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(opponentName)
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()

            // Score (if completed)
            if challenge.status == "completed" {
                let myScore = isChallenger ? (challenge.challengerScore ?? 0) : (challenge.opponentScore ?? 0)
                let theirScore = isChallenger ? (challenge.opponentScore ?? 0) : (challenge.challengerScore ?? 0)
                Text("\(myScore) - \(theirScore)")
                    .font(.headline.bold())
                    .foregroundColor(.neuText)
            }

            // Action buttons
            if challenge.status == "pending" && !isChallenger {
                HStack(spacing: 8) {
                    if let onAccept = onAccept {
                        Button(action: onAccept) {
                            Text("Accept")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.neuAccentGreen)
                                .clipShape(Capsule())
                        }
                    }
                    if let onDecline = onDecline {
                        Button(action: onDecline) {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                                .padding(6)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.neuBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
    }
}

// MARK: - ViewModel

@MainActor
class ChallengeListViewModel: ObservableObject {
    @Published var challenges: [ArenaChallenge] = []
    @Published var isLoading = false

    private let arenaService = ArenaService.shared
    private let client = SupabaseManager.shared.client

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    var pendingChallenges: [ArenaChallenge] {
        challenges.filter { $0.status == "pending" }
    }

    var activeChallenges: [ArenaChallenge] {
        challenges.filter { $0.status == "accepted" || $0.status == "in_progress" }
    }

    var completedChallenges: [ArenaChallenge] {
        challenges.filter { $0.status == "completed" }
    }

    func fetchChallenges() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.challenges = try await arenaService.getMyChallenges()
        } catch {
            print("❌ [ChallengeList] Failed: \(error)")
        }
    }

    func decline(challengeId: UUID) async {
        do {
            try await arenaService.declineChallenge(challengeId: challengeId)
            challenges.removeAll { $0.id == challengeId }
        } catch {
            print("❌ [ChallengeList] Decline failed: \(error)")
        }
    }
}
