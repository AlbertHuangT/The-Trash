//
//  ChallengeAcceptView.swift
//  The Trash
//
//  Deep link landing page for accepting/declining a challenge.
//

import SwiftUI
import Supabase

struct ChallengeAcceptView: View {
    let challengeId: UUID
    let onDismiss: () -> Void

    @State private var isLoading = true
    @State private var challenge: ArenaChallenge?
    @State private var errorMessage: String?
    @State private var showDuel = false

    private let client = SupabaseManager.shared.client
    private let arenaService = ArenaService.shared

    var body: some View {
        ZStack {
            Color.neuBackground
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

                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom)
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
                Button(action: {
                    showDuel = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Accept")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
                }

                Button(action: {
                    Task {
                        try? await arenaService.declineChallenge(challengeId: challengeId)
                        onDismiss()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.neuBackground)
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

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onDismiss) {
                Text("Go Back")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.neuAccentBlue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }
}
