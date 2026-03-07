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
        ZStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Report a Bug")
                        .font(.title2.bold())
                        .foregroundColor(theme.palette.textPrimary)
                        .padding(.top, 8)

                    Text("Describe the issue you encountered. We'll look into it as soon as possible.")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textSecondary)

                    // Title field
                    VStack(alignment: .leading, spacing: 8) {
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

                    // Description field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(theme.typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(theme.palette.textPrimary)

                        TrashFormTextEditor(text: $description, minHeight: 120)
                    }

                    // Attach logs toggle
                    TrashFormToggle(title: "Attach App Logs", isOn: $attachLog)
                        .padding(.vertical, 4)

                    if attachLog {
                        HStack(spacing: 8) {
                            TrashIcon(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(theme.palette.textSecondary)
                            Text("Logs help us diagnose your issue faster. They do not contain passwords or personal data.")
                                .font(.caption)
                                .foregroundColor(theme.palette.textSecondary)
                        }
                    }

                    // Submit button
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("Submitting...")
                                .foregroundColor(theme.palette.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else {
                        TrashButton(baseColor: theme.accents.blue, action: submit) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                                .trashOnAccentForeground()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .padding(16)
            }
        }
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
