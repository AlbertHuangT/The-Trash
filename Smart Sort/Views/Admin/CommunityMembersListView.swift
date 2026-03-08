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
    private let theme = TrashTheme()

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: MembersListViewModel(communityId: communityId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: theme.layout.elementSpacing) {
                ForEach(viewModel.members) { member in
                    MemberRow(member: member) {
                        viewModel.selectedMember = member
                    }
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.screenInset)
            .padding(.bottom, theme.spacing.xxl)
        }
        .trashScreenBackground()
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
            HStack(spacing: theme.layout.rowContentSpacing) {
                UserAvatarView(
                    name: member.username,
                    color: member.isAdmin ? .orange : .blue
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.username)
                            .font(theme.typography.subheadline)
                            .fontWeight(.bold)
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
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.vertical, theme.layout.elementSpacing)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
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
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        detailRow(label: "Username", value: member.username)
                        detailRow(label: "Credits", value: "\(member.credits)")
                        detailRow(label: "Joined", value: member.joinedAt.formatted())
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    if !member.isAdmin {
                        TrashButton(baseColor: theme.semanticDanger, action: {
                            showRemoveConfirmation = true
                        }) {
                            Text("Remove Member")
                                .font(theme.typography.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .trashOnAccentForeground()
                        }
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .disabled(isProcessing)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            Text(label)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: theme.components.minimumHitTarget)
    }
}

// MARK: - Remove Member Sheet

struct RemoveMemberSheet: View {
    let username: String
    @Binding var removalReason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Confirmation")
                        Text(
                            "Are you sure you want to remove \(username) from the community? This action cannot be undone."
                        )
                        .font(theme.typography.body)
                        .foregroundColor(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Reason")
                        TrashFormTextEditor(text: $removalReason, minHeight: 100)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(baseColor: theme.semanticDanger, action: onConfirm) {
                        Text("Remove Member")
                            .font(theme.typography.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .trashOnAccentForeground()
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
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
