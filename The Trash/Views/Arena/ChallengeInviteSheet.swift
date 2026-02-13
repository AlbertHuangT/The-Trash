//
//  ChallengeInviteSheet.swift
//  The Trash
//
//  Select a friend or community member to challenge to a duel.
//

import Combine
import Supabase
import SwiftUI

struct ChallengeInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trashTheme) private var theme
    @StateObject private var viewModel = ChallengeInviteViewModel()
    let onChallenge: (UUID) -> Void

    init(onChallenge: @escaping (UUID) -> Void = { _ in }) {
        self.onChallenge = onChallenge
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.members.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.members) { member in
                                InviteMemberRow(member: member) {
                                    onChallenge(member.id)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Challenge Someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel", variant: .accent) { dismiss() }
                }
            }
            .task {
                await viewModel.fetchMembers()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            TrashIcon(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.neuSecondaryText)
            Text("No members found")
                .font(.headline)
                .foregroundColor(.neuText)
            Text("Join a community to find opponents!")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// MARK: - Member Row

struct InviteMemberRow: View {
    let member: InvitableMember
    let onChallenge: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.neuAccentBlue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundColor(.neuAccentBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)
            }

            Spacer()

            TrashButton(baseColor: theme.semanticDanger, cornerRadius: 999, action: onChallenge) {
                HStack(spacing: 4) {
                    TrashIcon(systemName: "bolt.fill")
                    Text("Challenge")
                }
                .font(.caption.bold())
                .trashOnAccentForeground()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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

// MARK: - Models & ViewModel

private struct RawProfile: Codable {
    let id: UUID
    let username: String?
}

struct InvitableMember: Identifiable {
    let id: UUID
    let displayName: String
}

@MainActor
class ChallengeInviteViewModel: ObservableObject {
    @Published var members: [InvitableMember] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchMembers() async {
        isLoading = true
        defer { isLoading = false }

        guard let myId = client.auth.currentUser?.id else { return }

        do {
            // Fetch profiles (excluding self) — simple approach
            // username is nullable, so decode as optional first then filter
            let raw: [RawProfile] =
                try await client
                .from("profiles")
                .select("id, username")
                .neq("id", value: myId)
                .limit(50)
                .execute()
                .value

            self.members = raw.compactMap { p in
                guard let name = p.username, !name.isEmpty else { return nil }
                return InvitableMember(id: p.id, displayName: name)
            }
        } catch {
            print("❌ [ChallengeInvite] Failed: \(error)")
        }
    }
}
