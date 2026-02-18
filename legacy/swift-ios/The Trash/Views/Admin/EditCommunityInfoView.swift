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
    @Environment(\.trashTheme) private var theme

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
                TrashFormTextEditor(text: $description, minHeight: 100)
            }

            Section("Welcome Message") {
                TrashFormTextEditor(text: $welcomeMessage, minHeight: 80)
                Text("This message will be shown to new members when they join.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Community Rules") {
                TrashFormTextEditor(text: $rules, minHeight: 120)
            }

            Section {
                TrashFormToggle(title: "Require Approval to Join", isOn: $requiresApproval)
            } footer: {
                Text("If enabled, new members must be approved by an admin before joining.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                TrashButton(baseColor: .blue, action: saveChanges) {
                    if isSaving {
                        ProgressView()
                            .tint(theme.onAccentForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    } else {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity)
                            .trashOnAccentForeground()
                            .padding(.vertical, 6)
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Edit Community Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoadingSettings = true
            do {
                if let settings = try await CommunityService.shared.getCommunitySettings(communityId: community.id) {
                    description = settings.description ?? community.description
                    welcomeMessage = settings.welcomeMessage ?? ""
                    rules = settings.rules ?? ""
                    requiresApproval = settings.requiresApproval ?? false
                }
            } catch {
                print("❌ Get community settings error: \(error)")
            }
            isLoadingSettings = false
        }
        .sheet(isPresented: $showSuccessAlert) {
            TrashNoticeSheet(
                title: "Saved Successfully",
                message: "Community information has been updated.",
                onClose: {
                    showSuccessAlert = false
                    dismiss()
                }
            )
            .presentationDetents([.fraction(0.3), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.appearance.sheetBackground)
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                let result = try await CommunityService.shared.updateCommunityInfo(
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
            } catch {
                isSaving = false
                print("❌ Update community error: \(error)")
            }
        }
    }
}
