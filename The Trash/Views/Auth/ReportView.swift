//
//  ReportView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct ReportView: View {
    let predictedResult: TrashAnalysisResult
    let image: UIImage
    let userId: UUID?

    @Environment(\.dismiss) var dismiss
    @Environment(\.trashTheme) private var theme

    let bins = ["Recycle (Blue Bin)", "Compost (Green Bin)", "Landfill (Black Bin)", "Hazardous"]

    @State private var selectedBin = "Landfill (Black Bin)"
    @State private var itemName = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    // 🔥 FIX: 添加错误状态
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // AI Result Section
                Section(header: Text("AI Prediction Result")) {
                    HStack {
                        Text("Recognized Item")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(predictedResult.itemName)
                            .bold()
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Text("Category")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(predictedResult.category)
                            .bold()
                            .foregroundColor(predictedResult.color)
                    }
                }

                // Human Feedback Section
                Section(header: Text("Human Feedback")) {
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

                // Submit Button
                Section {
                    if isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView("Submitting...")
                            Spacer()
                        }
                    } else {
                        TrashButton(baseColor: theme.accents.blue, action: submit) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                                .trashOnAccentForeground()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Report Error")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel", variant: .accent) { dismiss() }
                }
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
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .sheet(isPresented: $showError) {
                TrashNoticeSheet(
                    title: "Submit Failed",
                    message: errorMessage,
                    buttonColor: .red,
                    onClose: { showError = false }
                )
                .presentationDetents([.fraction(0.3), .medium])
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
                    // 🔥 FIX: 显示错误信息给用户
                    errorMessage = "Failed to submit: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
