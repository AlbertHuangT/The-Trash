//
//  EditCommunityInfoView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI

struct EditCommunityInfoView: View {
    let community: Community
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    TrashSectionTitle(title: "Community Description")
                    TrashFormTextEditor(text: $description, minHeight: 100)
                }
                .padding(theme.components.cardPadding)
                .surfaceCard(cornerRadius: theme.corners.large)

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    TrashSectionTitle(title: "Welcome Message")
                    TrashFormTextEditor(text: $welcomeMessage, minHeight: 80)
                    Text("This message will be shown to new members when they join.")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
                .padding(theme.components.cardPadding)
                .surfaceCard(cornerRadius: theme.corners.large)

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    TrashSectionTitle(title: "Community Rules")
                    TrashFormTextEditor(text: $rules, minHeight: 120)
                }
                .padding(theme.components.cardPadding)
                .surfaceCard(cornerRadius: theme.corners.large)

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    TrashFormToggle(title: "Require Approval to Join", isOn: $requiresApproval)
                    Text("If enabled, new members must be approved by an admin before joining.")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
                .padding(theme.components.cardPadding)
                .surfaceCard(cornerRadius: theme.corners.large)
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.screenInset)
            .padding(.bottom, theme.spacing.xxl)
        }
        .trashScreenBackground()
        .navigationTitle("Edit Community Info")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            TrashButton(baseColor: theme.accents.blue, action: saveChanges) {
                if isSaving {
                    ProgressView()
                        .tint(theme.onAccentForeground)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save Changes")
                        .font(theme.typography.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .trashOnAccentForeground()
                }
            }
            .disabled(isSaving)
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.elementSpacing)
            .padding(.bottom, theme.layout.elementSpacing)
            .background(.ultraThinMaterial)
        }
        .task {
            isLoadingSettings = true
            do {
                if let settings = try await AdminService.shared.getCommunitySettings(communityId: community.id) {
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.appBackground)
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                let result = try await AdminService.shared.updateCommunityInfo(
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
