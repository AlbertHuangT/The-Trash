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
                    Picker("Actual Category", selection: $selectedBin) {
                        ForEach(bins, id: \.self) { bin in
                            Text(bin)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Correct Item Name (optional)", text: $itemName)
                        .autocapitalization(.none)
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
                        Button(action: submit) {
                            Text("Submit Feedback")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.blue) // Blue button background
                    }
                }
            }
            .navigationTitle("Report Error")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Submit Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you for your feedback. This will help make the AI smarter!")
            }
            // 🔥 FIX: 添加错误提示
            .alert("Submit Failed", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
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
