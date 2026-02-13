//
//  CommunityAdminDashboard.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import SwiftUI

struct CommunityAdminDashboard: View {
    let community: Community
    @StateObject private var viewModel: AdminDashboardViewModel
    @Environment(\.dismiss) var dismiss

    init(community: Community) {
        self.community = community
        _viewModel = StateObject(wrappedValue: AdminDashboardViewModel(communityId: community.id))
    }

    var body: some View {
        NavigationView {
            List {
                // Pending Applications
                if !viewModel.pendingApplications.isEmpty {
                    Section {
                        ForEach(viewModel.pendingApplications) { application in
                            ApplicationRow(
                                application: application,
                                onApprove: { await viewModel.approveApplication(application.id) },
                                onReject: { reason in
                                    await viewModel.rejectApplication(
                                        application.id, reason: reason)
                                }
                            )
                        }
                    } header: {
                        HStack {
                            Text("Pending Applications")
                            Spacer()
                            Text("\(viewModel.pendingApplications.count)")
                                .trashOnAccentForeground()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                // Management Features
                Section("Management") {
                    NavigationLink(destination: EditCommunityInfoView(community: community)) {
                        TrashLabel("Edit Community Info", icon: "pencil")
                    }

                    NavigationLink(destination: CommunityMembersListView(communityId: community.id))
                    {
                        TrashLabel("Manage Members", icon: "person.2.fill")
                    }

                    NavigationLink(destination: AdminLogsView(communityId: community.id)) {
                        TrashLabel("Audit Logs", icon: "doc.text.magnifyingglass")
                    }

                    NavigationLink(destination: ManageAchievementsView(communityId: community.id)) {
                        TrashLabel("Manage Achievements", icon: "trophy")
                    }
                }

                // Stats
                Section("Statistics") {
                    HStack {
                        Text("Total Members")
                        Spacer()
                        Text("\(community.memberCount)")
                            .foregroundColor(.blue)
                            .bold()
                    }

                    HStack {
                        Text("Pending Approvals")
                        Spacer()
                        Text("\(viewModel.pendingApplications.count)")
                            .foregroundColor(.orange)
                            .bold()
                    }
                }
            }
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
}

// MARK: - ViewModel

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var pendingApplications: [JoinApplicationResponse] = []
    @Published var isLoading = false

    let communityId: String
    private let service = CommunityService.shared

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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Header
            HStack {
                UserAvatarView(name: application.username)

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.username)
                        .font(.headline)
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

            // Message
            if let message = application.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Action Buttons
            HStack(spacing: 12) {
                TrashButton(
                    baseColor: .green,
                    action: {
                        isProcessing = true
                        Task {
                            await onApprove()
                            isProcessing = false
                        }
                    }
                ) {
                    HStack {
                        TrashIcon(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .trashOnAccentForeground()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(isProcessing)

                TrashButton(baseColor: .red, action: { showRejectSheet = true }) {
                    HStack {
                        TrashIcon(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .trashOnAccentForeground()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
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
        }
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

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Are you sure you want to reject the application from \(username)?")
                        .foregroundColor(.secondary)
                }

                Section("Rejection Reason (Optional)") {
                    TrashFormTextEditor(text: $rejectionReason, minHeight: 100)
                }

                Section {
                    TrashTextButton(
                        title: "Reject Application", role: .destructive, variant: .destructive
                    ) {
                        onConfirm()
                    }
                }
            }
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
