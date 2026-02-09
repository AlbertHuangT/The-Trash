//
//  CommunityAdminDashboard.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine

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
                                onReject: { reason in await viewModel.rejectApplication(application.id, reason: reason) }
                            )
                        }
                    } header: {
                        HStack {
                            Text("Pending Applications")
                            Spacer()
                            Text("\(viewModel.pendingApplications.count)")
                                .foregroundColor(.white)
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
                        Label("Edit Community Info", systemImage: "pencil")
                    }
                    
                    NavigationLink(destination: CommunityMembersListView(communityId: community.id)) {
                        Label("Manage Members", systemImage: "person.2.fill")
                    }
                    
                    NavigationLink(destination: AdminLogsView(communityId: community.id)) {
                        Label("Audit Logs", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    NavigationLink(destination: ManageAchievementsView(communityId: community.id)) {
                        Label("Manage Achievements", systemImage: "trophy")
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
                    Button("Close") { dismiss() }
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
        pendingApplications = await service.getPendingApplications(communityId: communityId)
        isLoading = false
    }
    
    func approveApplication(_ id: UUID) async {
        let result = await service.reviewApplication(applicationId: id, approve: true)
        if result.success {
            pendingApplications.removeAll { $0.id == id }
        }
    }
    
    func rejectApplication(_ id: UUID, reason: String?) async {
        let result = await service.reviewApplication(applicationId: id, approve: false, rejectionReason: reason)
        if result.success {
            pendingApplications.removeAll { $0.id == id }
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
                        Label("\(application.userCredits) Credits", systemImage: "star.fill")
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
                Button(action: {
                    isProcessing = true
                    Task {
                        await onApprove()
                        isProcessing = false
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                
                Button(action: { showRejectSheet = true }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
                    TextEditor(text: $rejectionReason)
                        .frame(height: 100)
                }
                
                Section {
                    Button("Reject Application", role: .destructive) {
                        onConfirm()
                    }
                }
            }
            .navigationTitle("Reject Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
