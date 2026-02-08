//
//  CommunityAdminViews.swift
//  The Trash
//
//  Admin dashboard: applications, member management, credits, audit logs
//

import SwiftUI
import Combine

// MARK: - Admin Dashboard

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
                // Pending applications
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
                                .foregroundColor(.red)
                                .bold()
                        }
                    }
                }

                // Management
                Section("Community Management") {
                    NavigationLink(destination: EditCommunityInfoView(community: community)) {
                        Label("Edit Community Info", systemImage: "pencil")
                    }

                    NavigationLink(destination: CommunityMembersListView(communityId: community.id)) {
                        Label("Manage Members", systemImage: "person.2.fill")
                    }

                    NavigationLink(destination: AdminLogsView(communityId: community.id)) {
                        Label("Action Logs", systemImage: "doc.text.fill")
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
                        Text("Pending Applications")
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

// MARK: - Admin Dashboard ViewModel

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
            // User info
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(application.username.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.username)
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label("\(application.userCredits) credits", systemImage: "star.fill")
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
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Action buttons
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
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)

                Button(action: { showRejectSheet = true }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
            .font(.subheadline.bold())
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
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}

// MARK: - Reject Application Sheet

struct RejectApplicationSheet: View {
    let username: String
    @Binding var rejectionReason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Are you sure you want to reject \(username)'s application?")
                        .foregroundColor(.secondary)
                }

                Section("Reason (Optional)") {
                    TextEditor(text: $rejectionReason)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Reject Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Reject") {
                        onConfirm()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Edit Community Info View

struct EditCommunityInfoView: View {
    let community: Community
    @Environment(\.dismiss) var dismiss

    @State private var description: String = ""
    @State private var welcomeMessage: String = ""
    @State private var rules: String = ""
    @State private var requiresApproval: Bool = false
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    @State private var isLoadingSettings = true

    var body: some View {
        Form {
            if isLoadingSettings {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else {
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }

                Section("Welcome Message") {
                    TextEditor(text: $welcomeMessage)
                        .frame(height: 80)
                    Text("Shown to new members when they join")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Community Rules") {
                    TextEditor(text: $rules)
                        .frame(height: 120)
                }

                Section {
                    Toggle("Require Approval to Join", isOn: $requiresApproval)
                } footer: {
                    Text("When enabled, new members must be approved by an admin before joining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("Edit Community")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Saved", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        }
        .task {
            if let settings = await CommunityService.shared.getCommunitySettings(communityId: community.id) {
                description = settings.description ?? community.description
                welcomeMessage = settings.welcomeMessage ?? ""
                rules = settings.rules ?? ""
                requiresApproval = settings.requiresApproval ?? false
            } else {
                description = community.description
            }
            isLoadingSettings = false
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            let result = await CommunityService.shared.updateCommunityInfo(
                communityId: community.id,
                description: description,
                welcomeMessage: welcomeMessage.isEmpty ? nil : welcomeMessage,
                rules: rules.isEmpty ? nil : rules,
                requiresApproval: requiresApproval
            )

            isSaving = false
            if result.success {
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Community Members List View

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
        .navigationTitle("Members")
        .refreshable {
            await viewModel.loadMembers()
        }
        .task {
            await viewModel.loadMembers()
        }
        .sheet(item: $viewModel.selectedMember) { member in
            MemberActionSheet(
                member: member,
                communityId: communityId,
                onRemove: { reason in
                    await viewModel.removeMember(member.userId, reason: reason)
                }
            )
        }
    }
}

@MainActor
class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMemberResponse] = []
    @Published var selectedMember: CommunityMemberResponse?
    @Published var isLoading = false

    let communityId: String
    private let service = CommunityService.shared

    init(communityId: String) {
        self.communityId = communityId
    }

    func loadMembers() async {
        isLoading = true
        members = await service.getCommunityMembersAdmin(communityId: communityId)
        isLoading = false
    }

    func removeMember(_ userId: UUID, reason: String?) async {
        let result = await service.removeMember(communityId: communityId, userId: userId, reason: reason)
        if result.success {
            members.removeAll { $0.userId == userId }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: CommunityMemberResponse
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(member.isAdmin ? Color.orange : Color.blue)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(member.username.prefix(1)))
                            .font(.headline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.username)
                            .font(.headline)
                        if member.isAdmin {
                            Text("Admin")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 12) {
                        Label("\(member.credits)", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(member.joinedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Member Action Sheet

struct MemberActionSheet: View {
    let member: CommunityMemberResponse
    let communityId: String
    let onRemove: (String?) async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var showRemoveConfirmation = false
    @State private var removalReason = ""

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

                    HStack {
                        Text("Role")
                        Spacer()
                        Text(member.isAdmin ? "Admin" : "Member")
                            .foregroundColor(member.isAdmin ? .orange : .secondary)
                    }
                }

                if !member.isAdmin {
                    Section {
                        Button(role: .destructive, action: { showRemoveConfirmation = true }) {
                            Label("Remove Member", systemImage: "person.fill.xmark")
                        }
                    }
                }
            }
            .navigationTitle("Member Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Remove Member", isPresented: $showRemoveConfirmation) {
                TextField("Reason (optional)", text: $removalReason)
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task {
                        await onRemove(removalReason.isEmpty ? nil : removalReason)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to remove \(member.username)? This cannot be undone.")
            }
        }
    }
}

// MARK: - Grant Credits View

struct GrantCreditsView: View {
    let event: CommunityEvent
    @StateObject private var viewModel: GrantCreditsViewModel
    @Environment(\.dismiss) var dismiss

    init(event: CommunityEvent) {
        self.event = event
        _viewModel = StateObject(wrappedValue: GrantCreditsViewModel(eventId: event.id))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Event Info") {
                    Text(event.title)
                        .font(.headline)
                    Label("\(event.participantCount) participants", systemImage: "person.2.fill")
                        .foregroundColor(.secondary)
                }

                Section("Credit Settings") {
                    Stepper("Per person: \(viewModel.creditsPerUser)", value: $viewModel.creditsPerUser, in: 1...100, step: 5)

                    TextField("Reason", text: $viewModel.reason)
                }

                Section {
                    Toggle("Select All", isOn: Binding(
                        get: { viewModel.selectedUserIds.count == viewModel.participants.count && !viewModel.participants.isEmpty },
                        set: { isOn in
                            if isOn {
                                viewModel.selectedUserIds = Set(viewModel.participants.map { $0.userId })
                            } else {
                                viewModel.selectedUserIds.removeAll()
                            }
                        }
                    ))
                } header: {
                    Text("Select Participants")
                } footer: {
                    Text("\(viewModel.selectedUserIds.count) selected")
                }

                if viewModel.isLoadingParticipants {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else {
                    Section {
                        ForEach(viewModel.participants) { participant in
                            Toggle(isOn: Binding(
                                get: { viewModel.selectedUserIds.contains(participant.userId) },
                                set: { isOn in
                                    if isOn {
                                        viewModel.selectedUserIds.insert(participant.userId)
                                    } else {
                                        viewModel.selectedUserIds.remove(participant.userId)
                                    }
                                }
                            )) {
                                HStack {
                                    Text(participant.username)
                                    Spacer()
                                    Text("\(participant.credits) credits")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(viewModel.selectedUserIds.count * viewModel.creditsPerUser) credits")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }

                Section {
                    Button(action: { Task { await viewModel.grantCredits() } }) {
                        if viewModel.isGranting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Grant Credits")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(viewModel.isGranting || viewModel.selectedUserIds.isEmpty || viewModel.reason.isEmpty)
                }
            }
            .navigationTitle("Grant Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Credits Granted", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Credits granted to \(viewModel.grantedCount) participants")
            }
            .task {
                await viewModel.loadParticipants()
            }
        }
    }
}

@MainActor
class GrantCreditsViewModel: ObservableObject {
    @Published var participants: [EventParticipantResponse] = []
    @Published var selectedUserIds: Set<UUID> = []
    @Published var creditsPerUser = 20
    @Published var reason = "Event participation reward"
    @Published var isGranting = false
    @Published var isLoadingParticipants = false
    @Published var showSuccessAlert = false
    @Published var grantedCount = 0

    let eventId: UUID
    private let service = CommunityService.shared

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func loadParticipants() async {
        isLoadingParticipants = true
        participants = await service.getEventParticipants(eventId: eventId)
        isLoadingParticipants = false
    }

    func grantCredits() async {
        guard !selectedUserIds.isEmpty else { return }

        isGranting = true
        let result = await service.grantEventCredits(
            eventId: eventId,
            userIds: Array(selectedUserIds),
            creditsPerUser: creditsPerUser,
            reason: reason
        )

        isGranting = false
        if result.success {
            grantedCount = result.grantedCount
            showSuccessAlert = true
        }
    }
}

// MARK: - Admin Logs View

struct AdminLogsView: View {
    let communityId: String
    @StateObject private var viewModel: AdminLogsViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: AdminLogsViewModel(communityId: communityId))
    }

    var body: some View {
        Group {
            if viewModel.logs.isEmpty && !viewModel.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Logs Yet")
                        .font(.headline)
                    Text("Admin actions will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.logs) { log in
                        AdminLogRow(log: log)
                    }
                }
            }
        }
        .navigationTitle("Action Logs")
        .refreshable {
            await viewModel.loadLogs()
        }
        .task {
            await viewModel.loadLogs()
        }
    }
}

@MainActor
class AdminLogsViewModel: ObservableObject {
    @Published var logs: [AdminActionLogResponse] = []
    @Published var isLoading = false

    let communityId: String
    private let service = CommunityService.shared

    init(communityId: String) {
        self.communityId = communityId
    }

    func loadLogs() async {
        isLoading = true
        logs = await service.getAdminLogs(communityId: communityId)
        isLoading = false
    }
}

// MARK: - Admin Log Row

struct AdminLogRow: View {
    let log: AdminActionLogResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForAction(log.actionType))
                    .foregroundColor(colorForAction(log.actionType))
                Text(log.actionDescription)
                    .font(.headline)
                Spacer()
                Text(timeAgo(from: log.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("By: \(log.adminUsername)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let target = log.targetUsername {
                Text("Target: \(target)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForAction(_ action: String) -> String {
        switch action {
        case "approve_member": return "checkmark.circle.fill"
        case "reject_member": return "xmark.circle.fill"
        case "remove_member": return "person.fill.xmark"
        case "grant_credits": return "star.fill"
        case "edit_community": return "pencil.circle.fill"
        default: return "circle.fill"
        }
    }

    private func colorForAction(_ action: String) -> Color {
        switch action {
        case "approve_member": return .green
        case "reject_member", "remove_member": return .red
        case "grant_credits": return .orange
        case "edit_community": return .blue
        default: return .gray
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}
