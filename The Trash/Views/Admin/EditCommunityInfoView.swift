//
//  EditCommunityInfoView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI

struct EditCommunityInfoView: View {
    let community: Community
    @Environment(\.dismiss) var dismiss
    
    @State private var description: String
    @State private var welcomeMessage: String
    @State private var rules: String
    @State private var requiresApproval: Bool
    @State private var isSaving = false
    @State private var isLoadingSettings = false
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
            Section("Community Description") {
                TextEditor(text: $description)
                    .frame(height: 100)
            }
            
            Section("Welcome Message") {
                TextEditor(text: $welcomeMessage)
                    .frame(height: 80)
                Text("This message will be shown to new members when they join.")
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
                Text("If enabled, new members must be approved by an admin before joining.")
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
        .navigationTitle("Edit Community Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoadingSettings = true
            if let settings = await CommunityService.shared.getCommunitySettings(communityId: community.id) {
                description = settings.description ?? community.description
                welcomeMessage = settings.welcomeMessage ?? ""
                rules = settings.rules ?? ""
                requiresApproval = settings.requiresApproval ?? false
            }
            isLoadingSettings = false
        }
        .alert("Saved Successfully", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
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
