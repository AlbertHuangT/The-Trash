//
//  CommunityAdminDashboard.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import SwiftUI

struct CommunityAdminDashboard: View {
    let community: Community
    @StateObject private var viewModel: AdminDashboardViewModel
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    init(community: Community) {
        self.community = community
        _viewModel = StateObject(wrappedValue: AdminDashboardViewModel(communityId: community.id))
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    if !viewModel.pendingApplications.isEmpty {
                        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                            HStack {
                                TrashSectionTitle(title: "Pending Applications")
                                Spacer()
                                TrashPill(
                                    title: "\(viewModel.pendingApplications.count)",
                                    color: theme.semanticDanger,
                                    isSelected: true
                                )
                            }

                            LazyVStack(spacing: theme.layout.elementSpacing) {
                                ForEach(viewModel.pendingApplications) { application in
                                    ApplicationRow(
                                        application: application,
                                        onApprove: { await viewModel.approveApplication(application.id) },
                                        onReject: { reason in
                                            await viewModel.rejectApplication(
                                                application.id,
                                                reason: reason
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Management")

                        adminLinkRow(
                            title: "Edit Community Info",
                            icon: "pencil",
                            destination: EditCommunityInfoView(community: community)
                        )

                        adminLinkRow(
                            title: "Manage Members",
                            icon: "person.2.fill",
                            destination: CommunityMembersListView(communityId: community.id)
                        )

                        adminLinkRow(
                            title: "Audit Logs",
                            icon: "doc.text.magnifyingglass",
                            destination: AdminLogsView(communityId: community.id)
                        )

                        adminLinkRow(
                            title: "Manage Achievements",
                            icon: "trophy",
                            destination: ManageAchievementsView(communityId: community.id)
                        )
                    }

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Statistics")

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 120), spacing: theme.layout.elementSpacing)],
                            spacing: theme.layout.elementSpacing
                        ) {
                            adminStatCard(
                                title: "Total Members",
                                value: "\(community.memberCount)",
                                color: theme.accents.blue
                            )
                            adminStatCard(
                                title: "Pending",
                                value: "\(viewModel.pendingApplications.count)",
                                color: theme.semanticWarning
                            )
                        }
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close") { dismiss() }
                }
            }
            .refreshable {
                await viewModel.loadApplications()
            }
            .task {
                await viewModel.loadApplications()
            }
        }
    }

    private func adminLinkRow<Destination: View>(
        title: String,
        icon: String,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                TrashIcon(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.accents.blue)
                    .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                    .background(theme.palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous))

                Text(title)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(theme.components.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func adminStatCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)

            Text(value)
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(theme.components.cardPadding)
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

// MARK: - ViewModel

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var pendingApplications: [JoinApplicationResponse] = []
    @Published var isLoading = false

    let communityId: String
    private let service = AdminService.shared

    init(communityId: String) {
        self.communityId = communityId
    }

    func loadApplications() async {
        isLoading = true
        do {
            pendingApplications = try await service.getPendingApplications(communityId: communityId)
        } catch {
            print("❌ Get applications error: \(error)")
        }
        isLoading = false
    }

    func approveApplication(_ id: UUID) async {
        do {
            let result = try await service.reviewApplication(applicationId: id, approve: true)
            if result.success {
                pendingApplications.removeAll { $0.id == id }
            }
        } catch {
            print("❌ Review application error: \(error)")
        }
    }

    func rejectApplication(_ id: UUID, reason: String?) async {
        do {
            let result = try await service.reviewApplication(
                applicationId: id, approve: false, rejectionReason: reason)
            if result.success {
                pendingApplications.removeAll { $0.id == id }
            }
        } catch {
            print("❌ Review application error: \(error)")
        }
    }
}

// MARK: - Application Row

struct ApplicationRow: View {
    let application: JoinApplicationResponse
    let onApprove: () async -> Void
    let onReject: (String?) async -> Void

    @State private var showRejectSheet = false
    @State private var rejectionReason = ""
    @State private var isProcessing = false
    private let theme = TrashTheme()

    var body: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                UserAvatarView(name: application.username)

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.username)
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                    HStack(spacing: 12) {
                        TrashLabel("\(application.userCredits) Credits", icon: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(timeAgo(from: application.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if let message = application.message, !message.isEmpty {
                Text(message)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textPrimary)
                    .padding(theme.components.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .fill(theme.palette.card.opacity(0.42))
                    )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.layout.elementSpacing) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    actionButtons
                }
            }
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showRejectSheet) {
            RejectApplicationSheet(
                username: application.username,
                rejectionReason: $rejectionReason,
                onConfirm: {
                    isProcessing = true
                    Task {
                        await onReject(rejectionReason.isEmpty ? nil : rejectionReason)
                        isProcessing = false
                        showRejectSheet = false
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        TrashPill(
            title: "Approve",
            icon: "checkmark.circle.fill",
            color: .green,
            isSelected: true,
            action: {
                isProcessing = true
                Task {
                    await onApprove()
                    isProcessing = false
                }
            }
        )
        .disabled(isProcessing)

        TrashPill(
            title: "Reject",
            icon: "xmark.circle.fill",
            color: .red,
            isSelected: false,
            action: { showRejectSheet = true }
        )
        .disabled(isProcessing)
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Reject Sheet

struct RejectApplicationSheet: View {
    let username: String
    @Binding var rejectionReason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Confirmation")
                        Text("Are you sure you want to reject the application from \(username)?")
                            .font(theme.typography.body)
                            .foregroundColor(theme.palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Rejection Reason")
                        TrashFormTextEditor(text: $rejectionReason, minHeight: 100)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(baseColor: theme.semanticDanger, action: onConfirm) {
                        Text("Reject Application")
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
            .navigationTitle("Reject Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") { dismiss() }
                }
            }
        }
    }
}
