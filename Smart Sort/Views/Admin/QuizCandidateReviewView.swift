//
//  QuizCandidateReviewView.swift
//  Smart Sort
//

import SwiftUI
import Combine

struct QuizCandidateReviewView: View {
    @StateObject private var viewModel = QuizCandidateReviewViewModel()
    @State private var selectedCandidate: QuizQuestionCandidateResponse?
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.isLoading && viewModel.candidates.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.candidates.isEmpty {
                EmptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: "No Candidates",
                    subtitle: "There are no quiz image candidates for this filter."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: theme.layout.elementSpacing) {
                        ForEach(viewModel.candidates) { candidate in
                            candidateRow(candidate)
                                .onTapGesture {
                                    selectedCandidate = candidate
                                }
                        }
                    }
                    .padding(.horizontal, theme.layout.screenInset)
                    .padding(.top, theme.layout.elementSpacing)
                    .padding(.bottom, theme.spacing.xxl)
                }
            }
        }
        .trashScreenBackground()
        .navigationTitle("Quiz Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadCandidates()
        }
        .refreshable {
            await viewModel.loadCandidates(force: true)
        }
        .sheet(item: $selectedCandidate) { candidate in
            QuizCandidateDetailView(candidate: candidate) {
                await viewModel.loadCandidates(force: true)
            }
        }
        .alert("Review Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var filterBar: some View {
        Picker("Status", selection: $viewModel.selectedFilter) {
            ForEach(QuizCandidateFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.top, theme.layout.elementSpacing)
        .padding(.bottom, theme.spacing.sm)
        .onChange(of: viewModel.selectedFilter) { _ in
            Task { await viewModel.loadCandidates(force: true) }
        }
    }

    private func candidateRow(_ candidate: QuizQuestionCandidateResponse) -> some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(statusColor(for: candidate.status).opacity(0.15))
                .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                .overlay(
                    TrashIcon(systemName: iconName(for: candidate.status))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(statusColor(for: candidate.status))
                )

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(candidate.predictedLabel)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(candidate.predictedCategory)
                    .font(theme.typography.caption.weight(.semibold))
                    .foregroundColor(theme.accents.blue)
                    .lineLimit(1)

                Text("By \(candidate.username) • \(relativeTime(candidate.createdAt))")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: theme.spacing.xs) {
                TrashPill(
                    title: candidate.status.capitalized,
                    color: statusColor(for: candidate.status),
                    isSelected: false
                )

                if candidate.publishedQuestionId != nil {
                    Text("Published")
                        .font(.caption2)
                        .foregroundColor(theme.accents.green)
                }
            }
        }
        .padding(theme.components.cardPadding)
        .frame(minHeight: theme.components.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "approved":
            return theme.accents.green
        case "rejected":
            return theme.semanticDanger
        default:
            return theme.semanticWarning
        }
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "approved":
            return "checkmark.seal.fill"
        case "rejected":
            return "xmark.seal.fill"
        default:
            return "clock.badge.questionmark.fill"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum QuizCandidateFilter: String, CaseIterable, Identifiable {
    case pending
    case approved
    case rejected
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .all: return "All"
        }
    }
}

@MainActor
final class QuizCandidateReviewViewModel: ObservableObject {
    @Published var candidates: [QuizQuestionCandidateResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var selectedFilter: QuizCandidateFilter = .pending

    private let adminService = AdminService.shared

    func loadCandidates(force: Bool = false) async {
        if isLoading && !force { return }

        isLoading = true
        defer { isLoading = false }

        do {
            candidates = try await adminService.getQuizQuestionCandidates(
                status: selectedFilter.rawValue,
                limit: 100
            )
            errorMessage = nil
            showError = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct QuizCandidateDetailView: View {
    let candidate: QuizQuestionCandidateResponse
    let onReviewed: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuizCandidateDetailViewModel()
    @State private var itemName: String
    @State private var category: String
    @State private var reviewNotes: String
    private let theme = TrashTheme()

    init(candidate: QuizQuestionCandidateResponse, onReviewed: @escaping () async -> Void) {
        self.candidate = candidate
        self.onReviewed = onReviewed
        _itemName = State(initialValue: candidate.predictedLabel)
        _category = State(initialValue: candidate.predictedCategory)
        _reviewNotes = State(initialValue: candidate.reviewNotes ?? "")
    }

    private let categories = ["Recyclable", "Compostable", "Landfill", "Hazardous"]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    imageSection
                    metadataSection
                    editorSection
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionSection
                    .padding(.horizontal, theme.layout.screenInset)
                    .padding(.top, theme.layout.elementSpacing)
                    .padding(.bottom, theme.layout.elementSpacing)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle("Candidate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close") { dismiss() }
                }
            }
            .task {
                await viewModel.loadPreview(for: candidate)
            }
            .alert("Review Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("Preview")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.palette.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack {
                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                    .fill(theme.surfaceBackground)

                if let previewURL = viewModel.previewURL {
                    AsyncImage(url: previewURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            candidatePlaceholder("Failed to load preview")
                        default:
                            ProgressView()
                        }
                    }
                } else if viewModel.isLoadingPreview {
                    ProgressView()
                } else {
                    candidatePlaceholder("Preview unavailable")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous))
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("Candidate Info")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.palette.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            detailLine("Predicted Label", candidate.predictedLabel)
            detailLine("Predicted Category", candidate.predictedCategory)
            detailLine("Uploader", candidate.username)
            detailLine("Status", candidate.status.capitalized)
            detailLine("Created", formatted(date: candidate.createdAt))

            if let reviewedAt = candidate.reviewedAt {
                detailLine("Reviewed", formatted(date: reviewedAt))
            }
            if let publishedQuestionId = candidate.publishedQuestionId {
                detailLine("Published Question", publishedQuestionId.uuidString)
            }
        }
        .padding(theme.components.cardPadding)
        .background(cardBackground)
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Text("Review")
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.palette.textSecondary)
                .textCase(.uppercase)
                .tracking(0.8)

            TrashFormTextField(
                title: "Item Name",
                text: $itemName,
                textInputAutocapitalization: .words
            )

            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .pickerStyle(.segmented)

            TrashFormTextField(
                title: "Review Notes",
                text: $reviewNotes,
                textInputAutocapitalization: .sentences
            )
        }
        .padding(theme.components.cardPadding)
        .background(cardBackground)
    }

    private var actionSection: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            TrashButton(
                baseColor: theme.accents.green,
                cornerRadius: theme.corners.medium,
                action: {
                    Task { await approveCandidate() }
                }
            ) {
                HStack(spacing: 10) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(theme.onAccentForeground)
                    } else {
                        TrashIcon(systemName: "checkmark.circle.fill")
                    }
                    Text("Approve And Publish")
                        .font(theme.typography.button)
                }
                .trashOnAccentForeground()
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing || candidate.status != "pending")

            TrashButton(
                baseColor: theme.semanticDanger,
                cornerRadius: theme.corners.medium,
                action: {
                    Task { await rejectCandidate() }
                }
            ) {
                HStack(spacing: 10) {
                    TrashIcon(systemName: "xmark.circle.fill")
                    Text("Reject")
                        .font(theme.typography.button)
                }
                .trashOnAccentForeground()
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isProcessing || candidate.status != "pending")
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
            )
    }

    private func approveCandidate() async {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            viewModel.errorMessage = "Item name cannot be empty."
            viewModel.showError = true
            return
        }

        let success = await viewModel.approveCandidate(
            candidate: candidate,
            itemName: trimmedName,
            category: category,
            reviewNotes: reviewNotes
        )

        if success {
            await onReviewed()
            dismiss()
        }
    }

    private func rejectCandidate() async {
        let success = await viewModel.rejectCandidate(
            candidate: candidate,
            reviewNotes: reviewNotes
        )

        if success {
            await onReviewed()
            dismiss()
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.palette.textPrimary)
            Spacer(minLength: 16)
            Text(value)
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func candidatePlaceholder(_ title: String) -> some View {
        VStack(spacing: 10) {
            TrashIcon(systemName: "photo.fill")
                .font(.system(size: 30))
                .foregroundColor(theme.palette.textSecondary)
            Text(title)
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
        }
    }
}

@MainActor
private final class QuizCandidateDetailViewModel: ObservableObject {
    @Published var previewURL: URL?
    @Published var isLoadingPreview = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let adminService = AdminService.shared

    func loadPreview(for candidate: QuizQuestionCandidateResponse) async {
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        do {
            previewURL = try await adminService.createQuizCandidatePreviewURL(path: candidate.imagePath)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func approveCandidate(
        candidate: QuizQuestionCandidateResponse,
        itemName: String,
        category: String,
        reviewNotes: String
    ) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let publishedImage = try await adminService.publishQuizCandidateImage(
                candidateId: candidate.id,
                sourcePath: candidate.imagePath
            )

            do {
                _ = try await adminService.reviewQuizQuestionCandidate(
                    candidateId: candidate.id,
                    decision: "approved",
                    reviewNotes: reviewNotes.isEmpty ? nil : reviewNotes,
                    itemName: itemName,
                    category: category,
                    publicImageURL: publishedImage.publicURL
                )
                return true
            } catch {
                await adminService.deletePublishedQuizCandidateImage(path: publishedImage.path)
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }

    func rejectCandidate(
        candidate: QuizQuestionCandidateResponse,
        reviewNotes: String
    ) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }

        do {
            _ = try await adminService.reviewQuizQuestionCandidate(
                candidateId: candidate.id,
                decision: "rejected",
                reviewNotes: reviewNotes.isEmpty ? nil : reviewNotes
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}
