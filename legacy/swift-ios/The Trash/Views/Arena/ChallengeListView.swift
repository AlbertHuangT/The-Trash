//
//  ChallengeListView.swift
//  The Trash
//
//  Challenge inbox: pending challenges received, in-progress, and completed.
//

import Combine
import Supabase
import SwiftUI

struct ChallengeListView: View {
    @StateObject private var viewModel = ChallengeListViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: ArenaChallenge?
    @State private var showDuel = false
    @Environment(\.trashTheme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()

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
                                            Task {
                                                await viewModel.decline(challengeId: challenge.id)
                                            }
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
                    TrashTextButton(title: "Done", variant: .accent) { dismiss() }
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
                        isAccepting: challenge.status == "pending"
                            && challenge.opponentId == viewModel.currentUserId
                    )
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            TrashIcon(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(theme.palette.textSecondary)
            Text("No challenges yet")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)
            Text("Challenge a friend to start a duel!")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
        }
    }
}

// MARK: - Challenge Row

struct ChallengeRow: View {
    let challenge: ArenaChallenge
    let currentUserId: UUID?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    @Environment(\.trashTheme) private var theme

    var isChallenger: Bool {
        challenge.challengerId == currentUserId
    }

    var opponentName: String {
        isChallenger
            ? (challenge.opponentName ?? "Opponent") : (challenge.challengerName ?? "Challenger")
    }

    var statusColor: Color {
        switch challenge.status {
        case "pending": return theme.semanticWarning
        case "accepted", "in_progress": return theme.accents.blue
        case "completed":
            return challenge.winnerId == currentUserId
                ? theme.semanticSuccess : theme.semanticDanger
        case "declined", "cancelled", "expired": return theme.palette.textSecondary
        default: return theme.palette.textSecondary
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
                    TrashIcon(systemName: "person.fill")
                        .foregroundColor(statusColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(opponentName)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                Text(statusText)
                    .font(theme.typography.caption)
                    .foregroundColor(statusColor)
            }

            Spacer()

            // Score (if completed)
            if challenge.status == "completed" {
                let myScore =
                    isChallenger ? (challenge.challengerScore ?? 0) : (challenge.opponentScore ?? 0)
                let theirScore =
                    isChallenger ? (challenge.opponentScore ?? 0) : (challenge.challengerScore ?? 0)
                Text("\(myScore) - \(theirScore)")
                    .font(theme.typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
            }

            // Action buttons
            if challenge.status == "pending" && !isChallenger {
                HStack(spacing: 8) {
                    if let onAccept = onAccept {
                        TrashButton(
                            baseColor: theme.accents.green, cornerRadius: 15, action: onAccept
                        ) {
                            Text("Accept")
                                .font(theme.typography.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                    }
                    if let onDecline = onDecline {
                        TrashTapArea(action: onDecline) {
                            TrashIcon(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(theme.semanticDanger)
                                .padding(6)
                                .background(theme.semanticDanger.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .trashCard(cornerRadius: 16)
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
        let removed = challenges.filter { $0.id == challengeId }
        challenges.removeAll { $0.id == challengeId }
        do {
            try await arenaService.declineChallenge(challengeId: challengeId)
        } catch {
            challenges.append(contentsOf: removed)
            print("❌ [ChallengeList] Decline failed: \(error)")
        }
    }
}
