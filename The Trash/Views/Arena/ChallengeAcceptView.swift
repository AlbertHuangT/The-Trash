//
//  ChallengeAcceptView.swift
//  The Trash
//
//  Deep link landing page for accepting/declining a challenge.
//

import Supabase
import SwiftUI

struct ChallengeAcceptView: View {
    let challengeId: UUID
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var challenge: ArenaChallenge?
    @State private var errorMessage: String?
    @State private var showDuel = false

    private let client = SupabaseManager.shared.client
    private let arenaService = ArenaService.shared
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            if isLoading {
                EnhancedLoadingView()
            } else if let error = errorMessage {
                errorView(error)
            } else if let challenge = challenge {
                challengeCard(challenge)
            }
        }
        .fullScreenCover(isPresented: $showDuel) {
            DuelView(
                challengeId: challengeId,
                opponentId: nil,
                isAccepting: true
            )
        }
        .task {
            await loadChallenge()
        }
    }

    private func loadChallenge() async {
        do {
            let challenges = try await arenaService.getMyChallenges(status: "pending")
            if let found = challenges.first(where: { $0.id == challengeId }) {
                self.challenge = found
            } else {
                errorMessage = "Challenge not found or already handled."
            }
        } catch {
            errorMessage = "Failed to load challenge: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func challengeCard(_ challenge: ArenaChallenge) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 120, height: 120)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 6, y: 6)
                    .shadow(color: .neuLightShadow, radius: 10, x: -4, y: -4)

                TrashIcon(systemName: "bolt.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.semanticDanger, theme.semanticWarning], startPoint: .top,
                            endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text("Challenge Received!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.neuText)

                Text("\(challenge.challengerName ?? "Someone") wants to duel!")
                    .font(.subheadline)
                    .foregroundColor(.neuSecondaryText)

                Text("10 questions, answer faster and more accurately to win!")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 16) {
                TrashButton(
                    baseColor: theme.semanticSuccess, cornerRadius: 999,
                    action: {
                        showDuel = true
                    }
                ) {
                    HStack(spacing: 8) {
                        TrashIcon(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.headline.bold())
                    .trashOnAccentForeground()
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                }

                TrashTapArea(action: {
                    Task {
                        try? await arenaService.declineChallenge(challengeId: challengeId)
                        onDismiss()
                    }
                }) {
                    HStack(spacing: 8) {
                        TrashIcon(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.headline.bold())
                    .foregroundColor(theme.semanticDanger)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(theme.palette.background)
                    .clipShape(Capsule())
                    .shadow(color: .neuDarkShadow, radius: 8, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 8, x: -3, y: -3)
                }
            }

            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(theme.semanticWarning)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TrashButton(baseColor: theme.semanticInfo, cornerRadius: 999, action: onDismiss) {
                Text("Go Back")
                    .font(.headline.bold())
                    .trashOnAccentForeground()
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }

            Spacer()
        }
    }
}
