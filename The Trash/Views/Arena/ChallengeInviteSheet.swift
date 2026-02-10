//
//  ChallengeInviteSheet.swift
//  The Trash
//
//  Select a friend or community member to challenge to a duel.
//

import SwiftUI
import Supabase
import Combine

struct ChallengeInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChallengeInviteViewModel()
    @State private var showDuel = false
    @State private var selectedOpponentId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.neuBackground
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
                                    selectedOpponentId = member.id
                                    showDuel = true
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
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neuAccentBlue)
                }
            }
            .task {
                await viewModel.fetchMembers()
            }
            .fullScreenCover(isPresented: $showDuel) {
                if let oppId = selectedOpponentId {
                    DuelView(challengeId: nil, opponentId: oppId, isAccepting: false)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
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

            Button(action: onChallenge) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("Challenge")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
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

        guard let myId = client.auth.currentUser?.id else { return }

        do {
            // Fetch profiles (excluding self) — simple approach
            let profiles: [InvitableMember] = try await client
                .from("profiles")
                .select("id, display_name")
                .neq("id", value: myId)
                .limit(50)
                .execute()
                .value

            self.members = profiles.filter { !$0.displayName.isEmpty }
        } catch {
            print("❌ [ChallengeInvite] Failed: \(error)")
        }
    }
}
