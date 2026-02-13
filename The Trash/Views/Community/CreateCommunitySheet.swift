//
//  CreateCommunitySheet.swift
//  The Trash
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI

struct CreateCommunitySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.trashTheme) private var theme

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
            Form {
                Section {
                    if userSettings.selectedLocation != nil {
                        HStack(spacing: 12) {
                            TrashIcon(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(theme.semanticInfo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCity)
                                    .font(.headline)
                                Text(selectedState)
                                    .font(.caption)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                            Spacer()
                            TrashIcon(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.semanticSuccess)
                        }
                    } else {
                        HStack {
                            TrashIcon(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.semanticWarning)
                            Text("Please select a location first")
                                .foregroundColor(theme.palette.textSecondary)
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Your community will be created in this city")
                }

                Section("Community Details") {
                    TrashFormTextField(
                        title: "Community Name",
                        text: $name,
                        textInputAutocapitalization: .words
                    )
                    TrashFormTextEditor(text: $description, minHeight: 80)
                }

                Section {
                    HStack(spacing: 12) {
                        TrashIcon(systemName: "info.circle.fill")
                            .foregroundColor(theme.accents.blue)
                        Text(
                            "You can create up to 3 communities. You will automatically become the admin of this community."
                        )
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            TrashIcon(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.semanticDanger)
                            Text(error)
                                .foregroundColor(theme.semanticDanger)
                        }
                    }
                }
            }
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
                    TrashTextButton(title: "Create", variant: .accent, action: createCommunity)
                        .overlay { if isLoading { ProgressView() } }
                        .disabled(!canCreate || isLoading)
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
                .presentationDetents([.fraction(0.32), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
        }
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
