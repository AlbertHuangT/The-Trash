//
//  CommunityAdminFeatures.swift
//  管理员权限功能实现
//
//  包含：申请审批、社区管理、积分发放、成员管理
//

import SwiftUI
import Supabase

// MARK: - Data Models

struct JoinApplication: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let userCredits: Int
    let message: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case userCredits = "user_credits"
        case message
        case createdAt = "created_at"
    }
}

struct CommunityMember: Identifiable, Codable {
    let userId: UUID
    let username: String
    let credits: Int
    let status: String
    let joinedAt: Date
    let isAdmin: Bool
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case credits
        case status
        case joinedAt = "joined_at"
        case isAdmin = "is_admin"
    }
}

struct AdminActionLog: Identifiable, Codable {
    let id: UUID
    let adminUsername: String
    let actionType: String
    let targetUsername: String?
    let details: [String: AnyCodable]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case adminUsername = "admin_username"
        case actionType = "action_type"
        case targetUsername = "target_username"
        case details
        case createdAt = "created_at"
    }
    
    var actionDescription: String {
        switch actionType {
        case "approve_member": return "批准加入"
        case "reject_member": return "拒绝申请"
        case "remove_member": return "移除成员"
        case "grant_credits": return "发放积分"
        case "edit_community": return "编辑社区"
        case "edit_event": return "编辑活动"
        case "delete_event": return "删除活动"
        default: return actionType
        }
    }
}

// MARK: - CommunityService Extension

extension CommunityService {
    
    // MARK: - Admin Check
    
    func isAdmin(communityId: String) async -> Bool {
        do {
            let result: Bool = try await client
                .rpc("is_community_admin", params: ["p_community_id": communityId])
                .execute()
                .value
            return result
        } catch {
            print("❌ Check admin error: \(error)")
            return false
        }
    }
    
    // MARK: - Applications Management
    
    /// 获取待审批的申请
    func getPendingApplications(communityId: String) async -> [JoinApplication] {
        do {
            let applications: [JoinApplication] = try await client
                .rpc("get_pending_applications", params: ["p_community_id": communityId])
                .execute()
                .value
            return applications
        } catch {
            print("❌ Get applications error: \(error)")
            return []
        }
    }
    
    /// 审批申请
    func reviewApplication(
        applicationId: UUID,
        approve: Bool,
        rejectionReason: String? = nil
    ) async -> (success: Bool, message: String) {
        do {
            struct Response: Codable {
                let success: Bool
                let message: String
            }
            
            let response: Response = try await client
                .rpc("review_join_application", params: [
                    "p_application_id": applicationId,
                    "p_approve": approve,
                    "p_rejection_reason": rejectionReason
                ])
                .execute()
                .value
            
            return (response.success, response.message)
        } catch {
            print("❌ Review application error: \(error)")
            return (false, "操作失败")
        }
    }
    
    // MARK: - Community Management
    
    /// 更新社区信息
    func updateCommunityInfo(
        communityId: String,
        description: String? = nil,
        welcomeMessage: String? = nil,
        rules: String? = nil,
        requiresApproval: Bool? = nil
    ) async -> (success: Bool, message: String) {
        do {
            struct Response: Codable {
                let success: Bool
                let message: String
            }
            
            var params: [String: Any] = ["p_community_id": communityId]
            if let desc = description { params["p_description"] = desc }
            if let welcome = welcomeMessage { params["p_welcome_message"] = welcome }
            if let r = rules { params["p_rules"] = r }
            if let approval = requiresApproval { params["p_requires_approval"] = approval }
            
            let response: Response = try await client
                .rpc("update_community_info", params: params)
                .execute()
                .value
            
            return (response.success, response.message)
        } catch {
            print("❌ Update community error: \(error)")
            return (false, "更新失败")
        }
    }
    
    // MARK: - Member Management
    
    /// 获取社区成员列表（管理员视图）
    func getCommunityMembers(communityId: String) async -> [CommunityMember] {
        do {
            let members: [CommunityMember] = try await client
                .rpc("get_community_members_admin", params: ["p_community_id": communityId])
                .execute()
                .value
            return members
        } catch {
            print("❌ Get members error: \(error)")
            return []
        }
    }
    
    /// 移除成员
    func removeMember(
        communityId: String,
        userId: UUID,
        reason: String? = nil
    ) async -> (success: Bool, message: String) {
        do {
            struct Response: Codable {
                let success: Bool
                let message: String
            }
            
            let response: Response = try await client
                .rpc("remove_community_member", params: [
                    "p_community_id": communityId,
                    "p_user_id": userId,
                    "p_reason": reason
                ])
                .execute()
                .value
            
            return (response.success, response.message)
        } catch {
            print("❌ Remove member error: \(error)")
            return (false, "移除失败")
        }
    }
    
    // MARK: - Credits Management
    
    /// 为活动参与者批量发放积分
    func grantEventCredits(
        eventId: UUID,
        userIds: [UUID],
        creditsPerUser: Int,
        reason: String
    ) async -> (success: Bool, message: String, grantedCount: Int) {
        do {
            struct Response: Codable {
                let success: Bool
                let message: String
                let grantedCount: Int
                
                enum CodingKeys: String, CodingKey {
                    case success
                    case message
                    case grantedCount = "granted_count"
                }
            }
            
            let response: Response = try await client
                .rpc("grant_event_credits", params: [
                    "p_event_id": eventId,
                    "p_user_ids": userIds,
                    "p_credits_per_user": creditsPerUser,
                    "p_reason": reason
                ])
                .execute()
                .value
            
            return (response.success, response.message, response.grantedCount)
        } catch {
            print("❌ Grant credits error: \(error)")
            return (false, "发放失败", 0)
        }
    }
    
    // MARK: - Action Logs
    
    /// 获取管理员操作日志
    func getAdminLogs(communityId: String, limit: Int = 50) async -> [AdminActionLog] {
        do {
            let logs: [AdminActionLog] = try await client
                .rpc("get_admin_action_logs", params: [
                    "p_community_id": communityId,
                    "p_limit": limit
                ])
                .execute()
                .value
            return logs
        } catch {
            print("❌ Get admin logs error: \(error)")
            return []
        }
    }
}

// MARK: - Admin Dashboard View

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
                // 待审批申请
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
                            Text("待审批申请")
                            Spacer()
                            Text("\(viewModel.pendingApplications.count)")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // 管理功能
                Section("社区管理") {
                    NavigationLink(destination: EditCommunityInfoView(community: community)) {
                        Label("编辑社区信息", systemImage: "pencil")
                    }
                    
                    NavigationLink(destination: CommunityMembersListView(communityId: community.id)) {
                        Label("管理成员", systemImage: "person.2.fill")
                    }
                    
                    NavigationLink(destination: AdminLogsView(communityId: community.id)) {
                        Label("操作日志", systemImage: "doc.text.fill")
                    }
                }
                
                // 统计数据
                Section("统计数据") {
                    HStack {
                        Text("总成员数")
                        Spacer()
                        Text("\(community.memberCount)")
                            .foregroundColor(.blue)
                            .bold()
                    }
                    
                    HStack {
                        Text("待审批申请")
                        Spacer()
                        Text("\(viewModel.pendingApplications.count)")
                            .foregroundColor(.orange)
                            .bold()
                    }
                }
            }
            .navigationTitle("管理员面板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
    @Published var pendingApplications: [JoinApplication] = []
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
    let application: JoinApplication
    let onApprove: () async -> Void
    let onReject: (String?) async -> Void
    
    @State private var showRejectSheet = false
    @State private var rejectionReason = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息
            HStack {
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
                        Label("\(application.userCredits) 积分", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(timeAgo(from: application.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // 申请留言
            if let message = application.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
            }
            
            // 操作按钮
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
                        Text("批准")
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
                        Text("拒绝")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
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
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
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
                    Text("确定要拒绝 \(username) 的加入申请吗？")
                        .foregroundColor(.secondary)
                }
                
                Section("拒绝理由（可选）") {
                    TextEditor(text: $rejectionReason)
                        .frame(height: 100)
                }
            }
            .navigationTitle("拒绝申请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认拒绝") {
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
    
    @State private var description: String
    @State private var welcomeMessage: String
    @State private var rules: String
    @State private var requiresApproval: Bool
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    init(community: Community) {
        self.community = community
        _description = State(initialValue: community.description)
        _welcomeMessage = State(initialValue: "")
        _rules = State(initialValue: "")
        _requiresApproval = State(initialValue: false)
    }
    
    var body: some View {
        Form {
            Section("社区描述") {
                TextEditor(text: $description)
                    .frame(height: 100)
            }
            
            Section("欢迎消息") {
                TextEditor(text: $welcomeMessage)
                    .frame(height: 80)
                Text("新成员加入时会看到这条消息")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("社区规则") {
                TextEditor(text: $rules)
                    .frame(height: 120)
            }
            
            Section {
                Toggle("加入需要审批", isOn: $requiresApproval)
            } footer: {
                Text("开启后，新成员需要管理员批准才能加入社区")
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
                        Text("保存更改")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("编辑社区信息")
        .navigationBarTitleDisplayMode(.inline)
        .alert("保存成功", isPresented: $showSuccessAlert) {
            Button("确定") { dismiss() }
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
        .navigationTitle("社区成员")
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
    }
}

@MainActor
class MembersListViewModel: ObservableObject {
    @Published var members: [CommunityMember] = []
    @Published var selectedMember: CommunityMember?
    @Published var isLoading = false
    
    let communityId: String
    private let service = CommunityService.shared
    
    init(communityId: String) {
        self.communityId = communityId
    }
    
    func loadMembers() async {
        isLoading = true
        members = await service.getCommunityMembers(communityId: communityId)
        isLoading = false
    }
    
    func removeMember(_ userId: UUID, reason: String?) async {
        let result = await service.removeMember(communityId: communityId, userId: userId, reason: reason)
        if result.success {
            members.removeAll { $0.userId == userId }
        }
    }
}

struct MemberRow: View {
    let member: CommunityMember
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
                            Text("管理员")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(member.credits) 积分", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("加入于 \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
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

struct MemberActionSheet: View {
    let member: CommunityMember
    let onRemove: (String?) async -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var showRemoveConfirmation = false
    @State private var removalReason = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("用户名")
                        Spacer()
                        Text(member.username)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("积分")
                        Spacer()
                        Text("\(member.credits)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("加入时间")
                        Spacer()
                        Text(member.joinedAt.formatted())
                            .foregroundColor(.secondary)
                    }
                }
                
                if !member.isAdmin {
                    Section {
                        Button(role: .destructive, action: { showRemoveConfirmation = true }) {
                            Label("移除成员", systemImage: "person.fill.xmark")
                        }
                    }
                }
            }
            .navigationTitle("成员详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("移除成员", isPresented: $showRemoveConfirmation) {
                TextField("移除理由（可选）", text: $removalReason)
                Button("取消", role: .cancel) {}
                Button("确认移除", role: .destructive) {
                    Task {
                        await onRemove(removalReason.isEmpty ? nil : removalReason)
                        dismiss()
                    }
                }
            } message: {
                Text("确定要移除 \(member.username) 吗？此操作无法撤销。")
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
                Section("活动信息") {
                    Text(event.title)
                        .font(.headline)
                    Label("\(event.participantCount) 人参加", systemImage: "person.2.fill")
                        .foregroundColor(.secondary)
                }
                
                Section("积分设置") {
                    Stepper("每人发放：\(viewModel.creditsPerUser) 积分", value: $viewModel.creditsPerUser, in: 1...100, step: 5)
                    
                    TextField("发放理由", text: $viewModel.reason)
                }
                
                Section {
                    Toggle("全选所有参与者", isOn: Binding(
                        get: { viewModel.selectedUserIds.count == viewModel.participants.count },
                        set: { isOn in
                            if isOn {
                                viewModel.selectedUserIds = Set(viewModel.participants.map { $0.userId })
                            } else {
                                viewModel.selectedUserIds.removeAll()
                            }
                        }
                    ))
                } header: {
                    Text("选择参与者")
                } footer: {
                    Text("已选择 \(viewModel.selectedUserIds.count) 人")
                }
                
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
                                Text("\(participant.credits) 积分")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("总计发放")
                        Spacer()
                        Text("\(viewModel.selectedUserIds.count * viewModel.creditsPerUser) 积分")
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
                            Text("确认发放")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(viewModel.isGranting || viewModel.selectedUserIds.isEmpty || viewModel.reason.isEmpty)
                }
            }
            .navigationTitle("发放积分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("发放成功", isPresented: $viewModel.showSuccessAlert) {
                Button("确定") { dismiss() }
            } message: {
                Text("已为 \(viewModel.grantedCount) 名参与者发放积分")
            }
            .task {
                await viewModel.loadParticipants()
            }
        }
    }
}

@MainActor
class GrantCreditsViewModel: ObservableObject {
    @Published var participants: [CommunityMember] = []
    @Published var selectedUserIds: Set<UUID> = []
    @Published var creditsPerUser = 20
    @Published var reason = "活动参与奖励"
    @Published var isGranting = false
    @Published var showSuccessAlert = false
    @Published var grantedCount = 0
    
    let eventId: UUID
    private let service = CommunityService.shared
    
    init(eventId: UUID) {
        self.eventId = eventId
    }
    
    func loadParticipants() async {
        // TODO: 实现获取活动参与者列表的API
        // 暂时留空，需要在后端添加相应的RPC函数
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
        List {
            ForEach(viewModel.logs) { log in
                AdminLogRow(log: log)
            }
        }
        .navigationTitle("操作日志")
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
    @Published var logs: [AdminActionLog] = []
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

struct AdminLogRow: View {
    let log: AdminActionLog
    
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
            
            Text("操作者：\(log.adminUsername)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let target = log.targetUsername {
                Text("对象：\(target)")
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
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(Int(seconds / 60))分钟前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))小时前" }
        return "\(Int(seconds / 86400))天前"
    }
}

// MARK: - Helper Type for JSON decoding

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        }
    }
}
