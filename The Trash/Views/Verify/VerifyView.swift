//
//  VerifyView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//

import SwiftUI

struct VerifyView: View {
    @EnvironmentObject var viewModel: TrashViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var cameraManager = CameraManager()
    
    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var showingFeedbackForm = false
    @State private var isCameraActive = false
    @State private var pulseAnimation = false
    @State private var showAccountSheet = false
    
    // Form Data
    @State private var feedbackItemName = ""
    
    var showFeedbackForm: Bool {
        if case .collectingFeedback = viewModel.appState, showingFeedbackForm { return true }
        return false
    }
    
    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && viewModel.appState == .idle
    }

    var body: some View {
        ZStack {
            // 🎨 渐变背景
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 🎨 App Store 风格头部
                appStoreHeader(title: "The Trash")
                
                // 🎨 AI 状态指示器
                aiStatusIndicator
                
                // --- Camera/Image Area ---
                cameraArea
                
                // --- Dynamic Interaction Area ---
                interactionArea
                
                Spacer(minLength: 10)
                
                // --- Main Action Button ---
                mainActionButton
            }
            
            // 🎨 分析中的全屏 overlay
            if viewModel.appState == .analyzing {
                analyzingOverlay
            }
        }
        // 🎨 景深效果：当账户页面打开时，主页面缩小并后退
        .scaleEffect(showAccountSheet ? 0.92 : 1.0)
        .offset(y: showAccountSheet ? -20 : 0)
        .blur(radius: showAccountSheet ? 2 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showAccountSheet)
        .onAppear {
            // 如果相机之前是激活状态，重新启动相机会话
            if isCameraActive && cameraManager.capturedImage == nil {
                cameraManager.start()
            }
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img, viewModel.appState == .idle {
                viewModel.analyzeImage(image: img)
            }
        }
    }
    
    // MARK: - 🎨 App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
            
            Spacer()
            
            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authVM)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - 🎨 AI Status Indicator
    private var aiStatusIndicator: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(RealClassifierService.shared.isReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                Text(RealClassifierService.shared.isReady ? "Ready" : "Loading")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(20)
            .onAppear { pulseAnimation = true }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 🎨 Camera Area
    private var cameraArea: some View {
        GeometryReader { geo in
            ZStack {
                // 🎨 美化相机容器
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 15, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                
                if let image = cameraManager.capturedImage {
                    // 🎨 显示拍摄的照片带动画
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .transition(.scale.combined(with: .opacity))
                        
                } else if isCameraActive {
                    // 相机预览
                    CameraPreview(cameraManager: cameraManager)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            // 🎨 扫描线动画
                            ScanLineOverlay()
                        )
                } else {
                    // 🎨 美化占位符
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue.opacity(0.2), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        
                        VStack(spacing: 6) {
                            Text("Identify Trash")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Point your camera at any item")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 340)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 🎨 Interaction Area
    private var interactionArea: some View {
        ZStack {
            if case .finished(let result) = viewModel.appState, !showingFeedbackForm {
                EnhancedSwipeableCard(result: result, offset: $cardOffset) { direction in
                    handleSwipe(direction: direction, result: result)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            if case .error(let message) = viewModel.appState {
                ErrorCard(message: message) {
                    finishFlowAndReset(closeCamera: false)
                    cameraManager.start()
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            if showFeedbackForm {
                EnhancedFeedbackForm(itemName: $feedbackItemName)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 220)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.appState)
    }
    
    // MARK: - 🎨 Main Action Button
    private var mainActionButton: some View {
        Button(action: handleMainButtonTap) {
            HStack(spacing: 12) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 18, weight: .semibold))
                Text(buttonText)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: showFeedbackForm ? [.green, .mint] : [.blue, .cyan],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: (showFeedbackForm ? Color.green : Color.blue).opacity(0.4), radius: 12, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .disabled(viewModel.appState == .analyzing)
    }
    
    // MARK: - 🎨 Analyzing Overlay
    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 🎨 动态加载动画
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulseAnimation)
                    
                    Image(systemName: "brain")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                
                Text("Analyzing...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("AI is identifying the item")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
        .transition(.opacity)
    }
    
    // MARK: - Button State
    private var buttonIcon: String {
        if showFeedbackForm { return "paperplane.fill" }
        if isCameraActive && !isPreviewState { return "arrow.clockwise" }
        return isCameraActive ? "camera.shutter.button.fill" : "camera.fill"
    }
    
    private var buttonText: String {
        if showFeedbackForm { return "Submit Correction" }
        if isCameraActive && !isPreviewState { return "Retake Photo" }
        return isCameraActive ? "Capture & Identify" : "Open Camera"
    }
    
    // MARK: - Handlers
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        let generator = UINotificationFeedbackGenerator()
        if direction == .right {
            generator.notificationOccurred(.success)
            viewModel.handleCorrectFeedback()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = 500
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset(closeCamera: true)
            }
        } else {
            generator.notificationOccurred(.warning)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = -500
            }
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.showingFeedbackForm = true
                    self.cardOffset = .zero
                }
            }
        }
    }
    
    private func handleMainButtonTap() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isCameraActive = true
            }
            cameraManager.start()
        } else if isPreviewState {
            cameraManager.takePhoto()
        } else {
            finishFlowAndReset(closeCamera: false)
            cameraManager.start()
        }
    }
    
    private func submitFeedback() {
        guard case .collectingFeedback(let originalResult) = viewModel.appState,
              let currentImage = cameraManager.capturedImage else { return }
        Task {
            await viewModel.submitCorrection(
                image: currentImage,
                originalResult: originalResult,
                correctedName: feedbackItemName
            )
            if viewModel.appState == .idle {
                finishFlowAndReset(closeCamera: true)
            } else if case .error = viewModel.appState {
                withAnimation {
                    showingFeedbackForm = false
                    cardOffset = .zero
                }
            }
        }
    }
    
    private func finishFlowAndReset(closeCamera: Bool = true) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingFeedbackForm = false
            cardOffset = .zero
            feedbackItemName = ""
            if closeCamera {
                isCameraActive = false
            }
        }
        viewModel.reset()
        cameraManager.reset()
    }
}
