//
//  BugReportView.swift
//  Smart Sort
//
//  Created by Albert Huang on 3/5/26.
//

import SwiftUI

struct BugReportView: View {
    private let theme = TrashTheme()
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var attachLog = true
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    // Header
                    Text("Report a Bug")
                        .font(theme.typography.headline)
                        .foregroundColor(theme.palette.textPrimary)

                    Text("Describe the issue you encountered. We'll look into it as soon as possible.")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textSecondary)
                }

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        Text("Title")
                            .font(theme.typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(theme.palette.textPrimary)

                        TrashFormTextField(
                            title: "Brief summary of the issue",
                            text: $title,
                            textInputAutocapitalization: .sentences
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        Text("Description")
                            .font(theme.typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(theme.palette.textPrimary)

                        TrashFormTextEditor(text: $description, minHeight: 120)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashFormToggle(title: "Attach App Logs", isOn: $attachLog)
                        .padding(theme.components.cardPadding)
                        .surfaceCard(cornerRadius: theme.corners.large)

                    if attachLog {
                        HStack(spacing: theme.spacing.sm) {
                            TrashIcon(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(theme.palette.textSecondary)
                            Text("Logs help us diagnose your issue faster. They do not contain passwords or personal data.")
                                .font(.caption)
                                .foregroundColor(theme.palette.textSecondary)
                        }
                        .padding(theme.components.cardPadding)
                        .surfaceCard(cornerRadius: theme.corners.large)
                    }

                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("Submitting...")
                                .foregroundColor(theme.palette.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, theme.spacing.sm)
                    } else {
                        TrashButton(baseColor: theme.accents.blue, action: submit) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.screenInset)
            .padding(.bottom, theme.spacing.xxl)
            }
        .trashScreenBackground()
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank You!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your feedback has been submitted. We appreciate your help improving Smart Sort!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title for your report."
            showError = true
            return
        }

        isSubmitting = true
        Task {
            do {
                try await BugReportService.shared.submitReport(
                    title: trimmedTitle,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    attachLog: attachLog
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
