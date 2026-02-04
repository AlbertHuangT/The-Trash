//
//  VerifyView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//

import SwiftUI

// MARK: - Enums
enum SwipeDirection {
    case left
    case right
}

struct VerifyView: View {
    @StateObject private var viewModel = TrashViewModel(classifier: RealClassifierService.shared)
    @StateObject private var cameraManager = CameraManager()
    
    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var showingFeedbackForm = false
    @State private var isCameraActive = false
    
    // Form Data
    @State private var selectedFeedbackCategory = "General Trash"
    @State private var feedbackItemName = ""
    let trashCategories = ["Recyclable", "Hazardous", "Compostable", "General Trash", "Electronic"]
    
    // Computed states
    var showFeedbackForm: Bool {
        if case .collectingFeedback = viewModel.appState, showingFeedbackForm { return true }
        return false
    }
    
    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("The Trash")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- Camera/Image Area ---
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        
                        if let image = cameraManager.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .cornerRadius(24)
                                .clipped()
                        } else if isCameraActive {
                            CameraPreview(cameraManager: cameraManager)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("Tap Button to Open Camera")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // --- Dynamic Interaction Area ---
                ZStack {
                    if case .finished(let result) = viewModel.appState, !showingFeedbackForm {
                        SwipeableResultCard(result: result, offset: $cardOffset) { direction in
                            handleSwipe(direction: direction, result: result)
                        }
                    }
                    
                    if showFeedbackForm {
                        FeedbackFormView(
                            selectedCategory: $selectedFeedbackCategory,
                            itemName: $feedbackItemName,
                            categories: trashCategories
                        )
                    }
                }
                .frame(height: 180)
                
                Spacer(minLength: 10)
                
                // --- Main Action Button ---
                Button(action: handleMainButtonTap) {
                    HStack {
                        if viewModel.appState == .analyzing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                            Text(buttonText)
                        }
                    }
                    .font(.headline).fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(showFeedbackForm ? Color.green : Color.blue)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 15)
                .disabled(viewModel.appState == .analyzing)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 15)
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img { viewModel.analyzeImage(image: img) }
        }
    }
    
    private var buttonIcon: String {
        if showFeedbackForm { return "paperplane.fill" }
        if isCameraActive && !isPreviewState { return "arrow.clockwise" }
        return isCameraActive ? "camera.shutter.button.fill" : "camera.fill"
    }
    
    private var buttonText: String {
        if showFeedbackForm { return "Submit" }
        if isCameraActive && !isPreviewState { return "Retake" }
        return isCameraActive ? "Identify" : "Open Camera"
    }
    
    // MARK: - Handlers
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        let generator = UINotificationFeedbackGenerator()
        if direction == .right {
            generator.notificationOccurred(.success)
            viewModel.handleCorrectFeedback()
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = 500 }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset(closeCamera: true)
            }
        } else {
            generator.notificationOccurred(.warning)
            withAnimation(.easeIn(duration: 0.3)) { cardOffset.width = -500 }
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero
                }
            }
        }
    }
    
    private func handleMainButtonTap() {
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            withAnimation { isCameraActive = true }
            cameraManager.start()
        } else if isPreviewState {
            cameraManager.takePhoto()
        } else {
            finishFlowAndReset(closeCamera: false)
            withAnimation { isCameraActive = true }
            cameraManager.start()
        }
    }
    
    private func submitFeedback() {
        guard case .collectingFeedback(let originalResult) = viewModel.appState,
              let currentImage = cameraManager.capturedImage else { return }
        Task {
            await viewModel.submitCorrection(image: currentImage, originalResult: originalResult, correctedCategory: selectedFeedbackCategory, correctedName: feedbackItemName)
            finishFlowAndReset(closeCamera: true)
        }
    }
    
    private func finishFlowAndReset(closeCamera: Bool = true) {
        withAnimation {
            showingFeedbackForm = false
            cardOffset = .zero
            selectedFeedbackCategory = "General Trash"
            feedbackItemName = ""
            if closeCamera {
                isCameraActive = false
            }
        }
        viewModel.reset()
        cameraManager.reset()
    }
}

// MARK: - Subcomponents (Internal to VerifyView)
struct SwipeableResultCard: View {
    let result: TrashAnalysisResult
    @Binding var offset: CGSize
    var onSwiped: (SwipeDirection) -> Void
    var body: some View {
        ResultCardContent(result: result)
            .offset(x: offset.width)
            .rotationEffect(.degrees(Double(offset.width / 15)))
            .gesture(DragGesture().onChanged { offset = $0.translation }.onEnded { gesture in
                if gesture.translation.width < -100 { onSwiped(.left) }
                else if gesture.translation.width > 100 { onSwiped(.right) }
                else { withAnimation(.spring()) { offset = .zero } }
            })
    }
}

struct ResultCardContent: View {
    let result: TrashAnalysisResult
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.category).font(.headline).foregroundColor(result.color)
                Spacer()
                Text("\(Int(result.confidence * 100))%").font(.caption).bold().padding(4).background(Color.secondary.opacity(0.1)).cornerRadius(4)
            }
            Text(result.itemName).font(.title3).bold()
            Text(result.actionTip).font(.caption).foregroundColor(.secondary)
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal)
    }
}

struct FeedbackFormView: View {
    @Binding var selectedCategory: String
    @Binding var itemName: String
    let categories: [String]
    var body: some View {
        VStack(spacing: 12) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0) }
            }.pickerStyle(.menu)
            TextField("Item Name", text: $itemName).textFieldStyle(.roundedBorder)
        }
        .padding().background(Color(.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal)
    }
}
