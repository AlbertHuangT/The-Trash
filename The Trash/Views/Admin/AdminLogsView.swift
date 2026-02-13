//
//  AdminLogsView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine

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
        .navigationTitle("Audit Logs")
        .refreshable {
            await viewModel.loadLogs()
        }
        .task {
            await viewModel.loadLogs()
        }
        .overlay {
            if viewModel.isLoading && viewModel.logs.isEmpty {
                ProgressView()
            } else if !viewModel.isLoading && viewModel.logs.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Logs",
                    subtitle: "No administrative actions have been recorded yet."
                )
            }
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
        do {
            logs = try await service.getAdminLogs(communityId: communityId)
        } catch {
            print("❌ Get admin logs error: \(error)")
        }
        isLoading = false
    }
}

struct AdminLogRow: View {
    let log: AdminActionLogResponse
    
    var actionColor: Color {
        switch log.actionType {
        case "approve_member", "grant_credits": return .green
        case "reject_member", "remove_member", "delete_event": return .red
        case "edit_community", "edit_event": return .blue
        default: return .secondary
        }
    }
    
    var actionIcon: String {
        switch log.actionType {
        case "approve_member": return "person.badge.plus"
        case "reject_member", "remove_member": return "person.badge.minus"
        case "grant_credits": return "star.circle.fill"
        case "edit_community": return "pencil.circle.fill"
        case "edit_event": return "calendar.badge.clock"
        case "delete_event": return "calendar.badge.minus"
        default: return "doc.text"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TrashIcon(systemName: actionIcon)
                .font(.title2)
                .foregroundColor(actionColor)
                .frame(width: 32)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(log.actionDescription)
                    .font(.headline)
                
                HStack {
                    Text("By: \(log.adminUsername)")
                        .badgeStyle(foreground: .secondary, background: Color(.secondarySystemBackground))

                    if let target = log.targetUsername {
                        Text("Target: \(target)")
                            .badgeStyle(foreground: .secondary, background: Color(.secondarySystemBackground))
                    }
                }
                
                Text(log.createdAt.formatted())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
