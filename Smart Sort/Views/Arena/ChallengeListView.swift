//
//  ChallengeListView.swift
//  Smart Sort
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
    private let theme = TrashTheme()

    var body: some View {
        NavigationStack {
            ZStack {

                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.challenges.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                            // Pending section
                            if !viewModel.pendingChallenges.isEmpty {
                                sectionHeader("Pending")
                                VStack(spacing: theme.layout.elementSpacing) {
                                    ForEach(viewModel.pendingChallenges) { challenge in
                                        ChallengeRow(
                                            challenge: challenge,
                                            displayStatus: viewModel.effectiveStatus(for: challenge),
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
                            }

                            if !viewModel.activeChallenges.isEmpty {
                                sectionHeader("In Progress")
                                VStack(spacing: theme.layout.elementSpacing) {
                                    ForEach(viewModel.activeChallenges) { challenge in
                                        ChallengeRow(
                                            challenge: challenge,
                                            displayStatus: viewModel.effectiveStatus(for: challenge),
                                            currentUserId: viewModel.currentUserId,
                                            onAccept: {
                                                selectedChallenge = challenge
                                                showDuel = true
                                            },
                                            onDecline: nil
                                        )
                                    }
                                }
                            }

                            if !viewModel.completedChallenges.isEmpty {
                                sectionHeader("History")
                                VStack(spacing: theme.layout.elementSpacing) {
                                    ForEach(viewModel.completedChallenges) { challenge in
                                        ChallengeRow(
                                            challenge: challenge,
                                            displayStatus: viewModel.effectiveStatus(for: challenge),
                                            currentUserId: viewModel.currentUserId,
                                            onAccept: nil,
                                            onDecline: nil
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, theme.layout.screenInset)
                        .padding(.top, theme.layout.screenInset)
                        .padding(.bottom, theme.layout.sectionSpacing)
                    }
                }
            }
            .trashScreenBackground()
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
        TrashSectionTitle(title: title)
            .padding(.bottom, theme.spacing.xs)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tray",
            title: "No Challenges Yet",
            subtitle: "Challenge a friend to start a duel."
        )
    }
}

// MARK: - Challenge Row

struct ChallengeRow: View {
    let challenge: ArenaChallenge
    let displayStatus: String
    let currentUserId: UUID?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    private let theme = TrashTheme()

    var isChallenger: Bool {
        challenge.challengerId == currentUserId
    }

    var opponentName: String {
        isChallenger
            ? (challenge.opponentName ?? "Opponent") : (challenge.challengerName ?? "Challenger")
    }

    var statusColor: Color {
        switch displayStatus {
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
        switch displayStatus {
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
        HStack(spacing: theme.layout.rowContentSpacing) {
            Circle()
                .fill(statusColor.opacity(0.16))
                .frame(
                    width: theme.components.minimumHitTarget,
                    height: theme.components.minimumHitTarget
                )
                .overlay(
                    TrashIcon(systemName: "person.fill")
                        .foregroundColor(statusColor)
                )

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(opponentName)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(statusText)
                    .font(theme.typography.caption)
                    .foregroundColor(statusColor)
            }

            Spacer(minLength: theme.spacing.sm)

            trailingContent
        }
        .padding(.horizontal, theme.components.cardPadding)
        .padding(.vertical, theme.layout.elementSpacing)
        .frame(minHeight: theme.components.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var trailingContent: some View {
        if displayStatus == "completed" {
            let myScore =
                isChallenger ? (challenge.challengerScore ?? 0) : (challenge.opponentScore ?? 0)
            let theirScore =
                isChallenger ? (challenge.opponentScore ?? 0) : (challenge.challengerScore ?? 0)

            TrashPill(
                title: "\(myScore)-\(theirScore)",
                color: theme.accents.blue,
                isSelected: false
            )
        } else if displayStatus == "pending" && !isChallenger {
            HStack(spacing: theme.spacing.sm) {
                if let onAccept = onAccept {
                    TrashPill(
                        title: "Accept",
                        color: theme.accents.green,
                        isSelected: true,
                        action: onAccept
                    )
                }

                if let onDecline = onDecline {
                    TrashTapArea(action: onDecline) {
                        TrashIcon(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundColor(theme.semanticDanger)
                            .frame(
                                width: theme.components.minimumHitTarget,
                                height: theme.components.minimumHitTarget
                            )
                            .background(theme.semanticDanger.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
        } else {
            TrashPill(
                title: statusText,
                color: statusColor,
                isSelected: false
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class ChallengeListViewModel: ObservableObject {
    @Published var challenges: [ArenaChallenge] = []
    @Published var isLoading = false

    private let staleActiveWindow: TimeInterval = 30 * 60

    private let arenaService = ArenaService.shared
    private let client = SupabaseManager.shared.client

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    var pendingChallenges: [ArenaChallenge] {
        challenges.filter { effectiveStatus(for: $0) == "pending" }
    }

    var activeChallenges: [ArenaChallenge] {
        challenges.filter {
            let status = effectiveStatus(for: $0)
            return status == "accepted" || status == "in_progress"
        }
    }

    var completedChallenges: [ArenaChallenge] {
        challenges.filter {
            ["completed", "declined", "cancelled", "expired"].contains(effectiveStatus(for: $0))
        }
    }

    func effectiveStatus(for challenge: ArenaChallenge) -> String {
        guard ["accepted", "in_progress"].contains(challenge.status) else {
            return challenge.status
        }
        guard let lastActivityDate = challenge.lastActivityDate else {
            return challenge.status
        }
        if lastActivityDate < Date().addingTimeInterval(-staleActiveWindow) {
            return "expired"
        }
        return challenge.status
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
