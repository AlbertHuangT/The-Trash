//
//  ReportView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct ReportView: View {
    let predictedResult: TrashAnalysisResult
    let image: UIImage
    let userId: UUID?

    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    let bins = ["Recycle (Blue Bin)", "Compost (Green Bin)", "Landfill (Black Bin)", "Hazardous"]

    @State private var selectedBin = "Landfill (Black Bin)"
    @State private var itemName = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    // Error presentation state
    @State private var showError = false
    @State private var errorMessage = ""

    private var reportRows: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            reportRow(
                label: "Recognized Item",
                value: predictedResult.itemName,
                valueColor: theme.palette.textPrimary
            )
            reportRow(
                label: "Category",
                value: predictedResult.category,
                valueColor: predictedResult.color
            )
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "AI Prediction Result")
                        reportRows
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Human Feedback")
                        TrashFormPicker(
                            title: "Actual Category",
                            selection: $selectedBin,
                            options: bins.map { TrashPickerOption(value: $0, title: $0, icon: nil) }
                        )

                        TrashFormTextField(
                            title: "Correct Item Name (optional)",
                            text: $itemName,
                            textInputAutocapitalization: .never
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Report Error")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel", variant: .accent) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TrashButton(baseColor: theme.accents.blue, action: submit) {
                    if isSubmitting {
                        ProgressView()
                            .tint(theme.onAccentForeground)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit Feedback")
                            .font(theme.typography.subheadline.weight(.bold))
                            .trashOnAccentForeground()
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting)
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.elementSpacing)
                .padding(.bottom, theme.layout.elementSpacing)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showSuccess) {
                TrashNoticeSheet(
                    title: "Submit Success",
                    message: "Thank you for your feedback. This will help make the AI smarter!",
                    onClose: {
                        showSuccess = false
                        dismiss()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .sheet(isPresented: $showError) {
                TrashNoticeSheet(
                    title: "Submit Failed",
                    message: errorMessage,
                    buttonColor: theme.semanticDanger,
                    onClose: { showError = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .onAppear {
                if bins.contains(predictedResult.category) {
                    selectedBin = predictedResult.category
                }
            }
        }
    }

    func submit() {
        isSubmitting = true
        Task {
            do {
                try await FeedbackService.shared.submitFeedback(
                    image: image,
                    predictedLabel: predictedResult.itemName,
                    predictedCategory: predictedResult.category,
                    correctedName: itemName,
                    userId: userId
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                print("Feedback Error: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    // Surface the submission error to the user
                    errorMessage = "Failed to submit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func reportRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sm) {
            Text(label)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: theme.components.minimumHitTarget, alignment: .center)
    }
}
