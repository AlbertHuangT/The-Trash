//
//  CommunityMembersListView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import SwiftUI

struct CommunityMembersListView: View {
    let communityId: String
    @StateObject private var viewModel: MembersListViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: MembersListViewModel(communityId: communityId))
    }

    var body: some View {
        List {
            ForEach(viewModel.members) { member in
                MemberRow(member: member) {
                    viewModel.selectedMember = member
                }
            }
        }
        .navigationTitle("Community Members")
        .refreshable {
            await viewModel.loadMembers()
        }
        .task {
            await viewModel.loadMembers()
        }
        .sheet(item: $viewModel.selectedMember) { member in
            MemberActionSheet(
                member: member,
                onRemove: { reason in
                    await viewModel.removeMember(member.userId, reason: reason)
                }
            )
        }
        .overlay {
            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.members.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Members",
                    subtitle: "This community has no members yet."
                )
            }
        }
    }
}

@MainActor
class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMemberResponse] = []
    @Published var selectedMember: CommunityMemberResponse?
    @Published var isLoading = false

    let communityId: String
    private let service = AdminService.shared

    init(communityId: String) {
        self.communityId = communityId
    }

    func loadMembers() async {
        isLoading = true
        do {
            members = try await service.getCommunityMembersAdmin(communityId: communityId)
        } catch {
            print("❌ Get members error: \(error)")
        }
        isLoading = false
    }

    func removeMember(_ userId: UUID, reason: String?) async {
        do {
            let result = try await service.removeMember(
                communityId: communityId, userId: userId, reason: reason)
            if result.success {
                members.removeAll { $0.userId == userId }
            }
        } catch {
            print("❌ Remove member error: \(error)")
        }
    }
}

struct MemberRow: View {
    let member: CommunityMemberResponse
    let onTap: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                UserAvatarView(
                    name: member.username,
                    color: member.isAdmin ? .orange : .blue
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.username)
                            .font(.headline)
                        if member.isAdmin {
                            Text("Admin")
                                .badgeStyle(background: .orange)
                        }
                    }

                    HStack(spacing: 12) {
                        TrashLabel("\(member.credits) Credits", icon: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(
                            "Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.75), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct MemberActionSheet: View {
    let member: CommunityMemberResponse
    let onRemove: (String?) async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var showRemoveConfirmation = false
    @State private var removalReason = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(member.username)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Credits")
                        Spacer()
                        Text("\(member.credits)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Joined")
                        Spacer()
                        Text(member.joinedAt.formatted())
                            .foregroundColor(.secondary)
                    }
                }

                if !member.isAdmin {
                    Section {
                        TrashTextButton(
                            title: "Remove Member", variant: .destructive
                        ) {
                            showRemoveConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showRemoveConfirmation) {
                RemoveMemberSheet(
                    username: member.username,
                    removalReason: $removalReason,
                    onConfirm: {
                        isProcessing = true
                        Task {
                            await onRemove(removalReason.isEmpty ? nil : removalReason)
                            isProcessing = false
                            dismiss()
                        }
                    }
                )
            }
            .disabled(isProcessing)
        }
    }
}

// MARK: - Remove Member Sheet

struct RemoveMemberSheet: View {
    let username: String
    @Binding var removalReason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(
                        "Are you sure you want to remove \(username) from the community? This action cannot be undone."
                    )
                    .foregroundColor(.secondary)
                }

                Section("Reason (Optional)") {
                    TrashFormTextEditor(text: $removalReason, minHeight: 100)
                }

                Section {
                    TrashTextButton(
                        title: "Remove Member", variant: .destructive
                    ) {
                        onConfirm()
                    }
                }
            }
            .navigationTitle("Remove Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") { dismiss() }
                }
            }
        }
    }
}
