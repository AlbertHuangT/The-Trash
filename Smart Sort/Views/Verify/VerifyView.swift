//
//  VerifyView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/4/26.
//

import SwiftUI

private enum VerifyFlowPhase: Equatable {
    case cameraClosed
    case preview
    case reviewingResult
    case collectingFeedback
    case submittingFeedback
}

struct VerifyView: View {
    @EnvironmentObject var viewModel: TrashViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var cameraManager = CameraManager()
    private let theme = TrashTheme()

    // UI State
    @State private var cardOffset: CGSize = .zero
    @State private var flowPhase: VerifyFlowPhase = .cameraClosed
    @State private var isTorchOn = false
    @State private var pulseAnimation = false
    // showAccountSheet is managed by ContentView via environment

    // Form Data
    @State private var feedbackItemName = ""
    @State private var swipeSuccessTrigger = false
    @State private var swipeWarningTrigger = false

    var showFeedbackForm: Bool {
        flowPhase == .collectingFeedback || flowPhase == .submittingFeedback
    }

    var isPreviewState: Bool {
        cameraManager.capturedImage == nil && flowPhase == .preview && viewModel.appState == .idle
    }

    private var isEcoCameraCaptureMode: Bool {
        isCameraActive && isPreviewState && !showFeedbackForm
    }

    private var isCameraActive: Bool {
        flowPhase != .cameraClosed
    }

    private var isSubmittingFeedback: Bool {
        flowPhase == .submittingFeedback
    }

    private var isClassifierPreparing: Bool {
        viewModel.classifierPreparationState == .preparing
    }

    private var isClassifierFailed: Bool {
        if case .failed = viewModel.classifierPreparationState {
            return true
        }
        return false
    }

    private var classifierStatusText: String? {
        switch viewModel.classifierPreparationState {
        case .idle:
            return nil
        case .preparing:
            return "Preparing AI..."
        case .ready:
            return "AI Ready"
        case .failed(let message):
            return message
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                cameraArea

                interactionArea

                Spacer(minLength: 10)

                mainActionButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            if viewModel.appState == .analyzing {
                analyzingOverlay
            }
        }
        .trashScreenBackground()
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountButton()
            }
        }
        .onAppear {
            Task {
                await viewModel.prepareClassifier()
            }

            if isCameraActive && cameraManager.capturedImage == nil {
                cameraManager.start()
            }
        }
        .onDisappear {
            flowPhase = .cameraClosed
            isTorchOn = false
            cameraManager.stop()
            viewModel.reset()
        }
        .onReceive(cameraManager.$capturedImage) { img in
            if let img = img, viewModel.appState == .idle {
                viewModel.analyzeImage(image: img)
            }
        }
        .onChange(of: viewModel.appState) { state in
            switch state {
            case .finished:
                if flowPhase == .preview {
                    flowPhase = .reviewingResult
                }
            case .collectingFeedback:
                flowPhase = .collectingFeedback
            case .submittingFeedback:
                flowPhase = .submittingFeedback
            case .error:
                if flowPhase == .submittingFeedback {
                    flowPhase = .reviewingResult
                }
            case .idle, .analyzing:
                break
            }
        }
        .onReceive(cameraManager.$isTorchOn) { isOn in
            isTorchOn = isOn
        }
        .compatibleSensoryFeedback(.success, trigger: swipeSuccessTrigger)
        .compatibleSensoryFeedback(.warning, trigger: swipeWarningTrigger)
    }

    private var cameraArea: some View {
        GeometryReader { geo in
            ecoCameraArea(size: geo.size)
        }
        .frame(maxHeight: min(340, UIScreen.main.bounds.height * 0.4))
        .padding(.horizontal, theme.spacing.md)
        .padding(.top, theme.spacing.md)
    }

    private func ecoCameraArea(size: CGSize) -> some View {
        let outerRadius = theme.corners.large + 6
        let innerRadius = theme.corners.large
        let inset: CGFloat = 18
        let safeWidth = size.width.isFinite ? size.width : 0
        let safeHeight = size.height.isFinite ? size.height : 0
        let contentWidth = max(safeWidth - inset * 2, 0)
        let contentHeight = max(safeHeight - inset * 2, 0)

        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .padding(inset)
                .blendMode(.multiply)

            Group {
                if let image = cameraManager.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if isCameraActive {
                    CameraPreview(cameraManager: cameraManager)
                        .overlay(ScanLineOverlay())
                } else {
                    VStack(spacing: 12) {
                        StampedIcon(
                            systemName: "camera.viewfinder",
                            size: 40,
                            weight: .semibold,
                            color: theme.palette.textPrimary.opacity(0.62)
                        )
                        Text("Cardboard Viewfinder")
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.palette.textPrimary.opacity(0.85))
                        Text("Point at an item to scan")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)

                        if let classifierStatusText {
                            Text(classifierStatusText)
                                .font(theme.typography.caption)
                                .foregroundColor(isClassifierFailed ? theme.semanticDanger : theme.accents.blue)
                        }
                    }
                    .padding(theme.spacing.lg)
                }
            }
            .frame(width: contentWidth, height: contentHeight)
            .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))

            RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                .stroke(theme.palette.divider.opacity(0.78), lineWidth: 1.8)
                .padding(inset)
                .shadow(color: Color.black.opacity(0.28), radius: 2, x: 0, y: 1)

            if isCameraActive {
                VStack(spacing: 12) {
                    cameraOverlayControls

                    if let classifierStatusText {
                        classifierStatusPill(text: classifierStatusText)
                    }
                }
                .padding(.horizontal, inset + 8)
                .padding(.top, inset + 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - 🎨 Interaction Area
    private var interactionArea: some View {
        ZStack {
            if case .finished(let result) = viewModel.appState, !showFeedbackForm {
                EnhancedSwipeableCard(result: result, offset: $cardOffset) { direction in
                    handleSwipe(direction: direction, result: result)
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            if case .error(let message) = viewModel.appState {
                ErrorCard(message: message) {
                    finishFlowAndReset(closeCamera: false)
                    flowPhase = .preview
                    cameraManager.start()
                }
                .transition(.scale.combined(with: .opacity))
            }

            if showFeedbackForm {
                EnhancedFeedbackForm(itemName: $feedbackItemName)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: isEcoCameraCaptureMode ? 84 : 170)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.appState)
    }

    // MARK: - 🎨 Main Action Button
    private var mainActionButton: some View {
        Group {
            if isEcoCameraCaptureMode {
                Button(action: handleMainButtonTap) {
                    ZStack {
                        Circle()
                            .fill(theme.accents.green.opacity(0.7))
                            .frame(width: 84, height: 84)
                            .offset(y: 3)

                        Circle()
                            .fill(theme.accents.green)
                            .frame(width: 88, height: 88)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 3)

                        StampedIcon(
                            systemName: "camera.fill",
                            size: 24,
                            weight: .bold,
                            color: theme.onAccentForeground
                        )
                    }
                }
                .buttonStyle(.plain)
            } else {
                TrashButton(
                    baseColor: showFeedbackForm ? theme.accents.green : theme.accents.blue,
                    cornerRadius: theme.corners.large,
                    action: handleMainButtonTap
                ) {
                    HStack(spacing: 12) {
                        TrashIcon(systemName: buttonIcon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(buttonText)
                            .font(theme.typography.button.weight(.bold))
                    }
                    .trashOnAccentForeground()
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, theme.spacing.xl)
            }
        }
        .padding(.bottom, 8)
        .disabled(viewModel.appState == .analyzing || isSubmittingFeedback || (isPreviewState && isClassifierPreparing))
    }

    // MARK: - 🎨 Analyzing Overlay
    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated loading indicator
                ZStack {
                    paperIconCircle
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            theme.gradients.primary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                        .animation(
                            .linear(duration: 1).repeatForever(autoreverses: false),
                            value: pulseAnimation)

                    TrashIcon(systemName: "brain")
                        .font(.system(size: 30))
                        .foregroundColor(theme.accents.blue)
                }

                Text("Analyzing...")
                    .font(theme.typography.headline)
                    .foregroundColor(theme.palette.textPrimary)

                Text("AI is identifying the item")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.large + 6, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.large + 6, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Button State
    private var cameraOverlayControls: some View {
        HStack {
            stampedOverlayButton(systemName: "xmark") {
                finishFlowAndReset(closeCamera: true)
            }

            Spacer()

            stampedOverlayButton(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill") {
                cameraManager.setTorch(enabled: !isTorchOn)
            }
        }
    }

    private func stampedOverlayButton(systemName: String, action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            StampedIcon(
                systemName: systemName,
                size: 17,
                weight: .bold,
                color: theme.onAccentForeground.opacity(0.94)
            )
            .padding(8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var buttonIcon: String {
        if showFeedbackForm { return "paperplane.fill" }
        if isClassifierPreparing && isPreviewState { return "sparkles" }
        if isCameraActive && !isPreviewState { return "arrow.clockwise" }
        return isCameraActive ? "camera.shutter.button.fill" : "camera.fill"
    }

    private var buttonText: String {
        if showFeedbackForm { return "Submit Correction" }
        if isClassifierPreparing && isPreviewState { return "Preparing AI..." }
        if isCameraActive && !isPreviewState { return "Retake Photo" }
        return isCameraActive ? "Capture & Identify" : "Open Camera"
    }

    // MARK: - Handlers
    private func handleSwipe(direction: SwipeDirection, result: TrashAnalysisResult) {
        if direction == .right {
            swipeSuccessTrigger.toggle()
            viewModel.handleCorrectFeedback(image: cameraManager.capturedImage)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = 500
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                finishFlowAndReset(closeCamera: true)
            }
        } else {
            swipeWarningTrigger.toggle()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cardOffset.width = -500
            }
            viewModel.prepareForIncorrectFeedback(wrongResult: result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.flowPhase = .collectingFeedback
                    self.cardOffset = .zero
                }
            }
        }
    }

    private func handleMainButtonTap() {
        if showFeedbackForm {
            submitFeedback()
        } else if !isCameraActive {
            Task {
                await viewModel.prepareClassifier()
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                flowPhase = .preview
            }
            cameraManager.start()
        } else if isPreviewState {
            guard !isClassifierPreparing else { return }
            cameraManager.takePhoto()
        } else {
            finishFlowAndReset(closeCamera: false)
            cameraManager.start()
        }
    }

    private func submitFeedback() {
        guard !isSubmittingFeedback else { return }
        guard !feedbackItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard case .collectingFeedback(let originalResult) = viewModel.appState,
            let currentImage = cameraManager.capturedImage
        else { return }
        flowPhase = .submittingFeedback
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
                    flowPhase = .reviewingResult
                    cardOffset = .zero
                }
            }
        }
    }

    private func finishFlowAndReset(closeCamera: Bool = true) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            flowPhase = closeCamera ? .cameraClosed : .preview
            cardOffset = .zero
            feedbackItemName = ""
        }

        if closeCamera {
            isTorchOn = false
            cameraManager.setTorch(enabled: false)
            cameraManager.stop()
        }

        viewModel.reset()
        cameraManager.reset()
    }
}

// MARK: - Helpers
extension VerifyView {
    private var paperIconCircle: some View {
        ZStack {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )

            TrashIcon(systemName: "camera.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(theme.palette.textSecondary)
        }
    }

    private func classifierStatusPill(text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundColor(isClassifierFailed ? theme.semanticDanger : theme.palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(theme.surfaceBackground.opacity(0.94))
                    .overlay(
                        Capsule()
                            .stroke(theme.palette.divider.opacity(0.9), lineWidth: 1)
                    )
            )
    }
}
