//
//  CreateCommunitySheet.swift
//  Smart Sort
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct CreateCommunitySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    private let theme = TrashTheme()

    @State private var name = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    private var selectedCity: String {
        userSettings.selectedLocation?.city ?? ""
    }

    private var selectedState: String {
        userSettings.selectedLocation?.state ?? ""
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedCity.isEmpty
    }

    private var communityId: String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(
                separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
                    .inverted
            )
            .joined()
        return "\(slug)-\(selectedCity.lowercased())"
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    locationCard
                    detailsCard
                    infoCard

                    if let error = errorMessage {
                        messageCard(error, color: theme.semanticDanger, icon: "exclamationmark.triangle.fill")
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            TrashTextButton(title: "Create", variant: .accent, action: createCommunity)
                                .disabled(!canCreate)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSuccessAlert) {
                TrashNoticeSheet(
                    title: "Community Created!",
                    message: "Your community \"\(name)\" has been created. You are now the admin!",
                    onClose: {
                        showSuccessAlert = false
                        isPresented = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            TrashSectionTitle(title: "Location")

            if userSettings.selectedLocation != nil {
                HStack(spacing: theme.layout.rowContentSpacing) {
                    TrashIcon(systemName: "mappin.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.semanticInfo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedCity)
                            .font(theme.typography.headline)
                        Text(selectedState)
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                    Spacer()
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.semanticSuccess)
                }
            } else {
                messageCard("Please select a location first", color: theme.semanticWarning, icon: "exclamationmark.triangle.fill")
            }

            Text("Your community will be created in this city")
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            TrashSectionTitle(title: "Community Details")
            TrashFormTextField(
                title: "Community Name",
                text: $name,
                textInputAutocapitalization: .words
            )
            TrashFormTextEditor(text: $description, minHeight: 80)
        }
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            HStack(spacing: theme.spacing.sm) {
                TrashIcon(systemName: "info.circle.fill")
                    .foregroundColor(theme.accents.blue)
                Text("Community Limits")
                    .font(theme.typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.palette.textPrimary)
            }

            Text(
                "You can create up to 3 communities. You will automatically become the admin of this community."
            )
            .font(theme.typography.caption)
            .foregroundColor(theme.palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private func messageCard(_ message: String, color: Color, icon: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            TrashIcon(systemName: icon)
                .foregroundColor(color)
            Text(message)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func createCommunity() {
        guard canCreate else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await CommunityService.shared.createCommunity(
                    id: communityId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    city: selectedCity,
                    state: selectedState,
                    description: description.isEmpty ? nil : description,
                    latitude: userSettings.selectedLocation?.latitude,
                    longitude: userSettings.selectedLocation?.longitude
                )

                isLoading = false
                if result.success {
                    showSuccessAlert = true
                    Task {
                        await userSettings.loadCommunitiesForCity(selectedCity)
                        await userSettings.loadMyCommunities()
                    }
                } else {
                    errorMessage = result.message
                }
            } catch {
                isLoading = false
                errorMessage = "Failed to create community: \(error.localizedDescription)"
            }
        }
    }
}
