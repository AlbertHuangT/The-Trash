//
//  ChallengeInviteSheet.swift
//  Smart Sort
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
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.members.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: theme.layout.elementSpacing) {
                            ForEach(viewModel.members) { member in
                                InviteMemberRow(member: member) {
                                    onChallenge(member.id)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, theme.layout.screenInset)
                        .padding(.top, theme.layout.elementSpacing)
                        .padding(.bottom, theme.layout.sectionSpacing)
                    }
                }
            }
            .trashScreenBackground()
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
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "No Members Found",
            subtitle: "Join a community to find opponents."
        )
    }
}

// MARK: - Member Row

struct InviteMemberRow: View {
    let member: InvitableMember
    let onChallenge: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(
                    width: theme.components.minimumHitTarget,
                    height: theme.components.minimumHitTarget
                )
                .overlay(
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(theme.typography.subheadline.weight(.bold))
                        .foregroundColor(theme.accents.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            TrashPill(
                title: "Challenge",
                icon: "bolt.fill",
                color: theme.semanticDanger,
                isSelected: true,
                action: onChallenge
            )
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
}

// MARK: - Models & ViewModel

struct InvitableMember: Identifiable, Codable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

@MainActor
class ChallengeInviteViewModel: ObservableObject {
    @Published var members: [InvitableMember] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchMembers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let raw: [InvitableMember] =
                try await client
                .rpc("get_invitable_members", params: ["p_limit": 50])
                .execute()
                .value

            self.members = raw.filter { !$0.displayName.isEmpty }
        } catch {
            print("❌ [ChallengeInvite] Failed: \(error)")
        }
    }
}
