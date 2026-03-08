//
//  TrashHistoryView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Models
struct HistoryItem: Decodable, Identifiable {
    let id: Int // feedback_logs uses int8
    let createdAt: Date
    let predictedLabel: String
    let predictedCategory: String
    let userCorrection: String
    let imagePath: String
    let userComment: String?
    var signedImageURL: URL? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case predictedLabel = "predicted_label"
        case predictedCategory = "predicted_category"
        case userCorrection = "user_correction"
        case imagePath = "image_path"
        case userComment = "user_comment"
    }
    
    var imageURL: URL? { signedImageURL }
}

// MARK: - ViewModel
@MainActor
class TrashHistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    @Published var isLoading = false
    // Error surface for the UI
    @Published var errorMessage: String?
    
    private let client = SupabaseManager.shared.client
    
    func fetchHistory() async {
        guard let userId = client.auth.currentUser?.id else {
            errorMessage = "Please log in to view history"
            return
        }
        isLoading = true
        errorMessage = nil
        
        do {
            var items: [HistoryItem] = try await client
                .from("feedback_logs")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false) // Newest first
                .limit(50) // Keep the latest 50 entries
                .execute()
                .value

            for index in items.indices {
                items[index].signedImageURL = try? await client.storage
                    .from("feedback_images")
                    .createSignedURL(path: items[index].imagePath, expiresIn: 3600)
            }

            self.historyItems = items
        } catch {
            print("❌ Fetch history error: \(error)")
            // Surface the error to the UI
            errorMessage = "Failed to load history"
        }
        
        isLoading = false
    }
}

// MARK: - Main View
struct TrashHistoryView: View {
    @StateObject private var viewModel = TrashHistoryViewModel()
    private let theme = TrashTheme()
    
    var body: some View {
        ZStack {
            
            if viewModel.isLoading && viewModel.historyItems.isEmpty {
                ProgressView("Loading history...")
            } else if viewModel.historyItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Text("Recent Feedback")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(theme.palette.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        ForEach(viewModel.historyItems) { item in
                            HistoryRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await viewModel.fetchHistory()
                }
            }
        }
        .navigationTitle("Trash History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.fetchHistory() }
        }
    }
    
    // Empty state
    var emptyState: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No History Yet",
            subtitle: "Items you identify and correct will appear here."
        )
    }
}

// MARK: - Subviews
struct HistoryRow: View {
    let item: HistoryItem
    private let theme = TrashTheme()
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Thumbnail
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle().fill(theme.surfaceBackground)
                        .overlay(ProgressView())
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Color.red.opacity(0.1))
                        .overlay(TrashIcon(systemName: "photo.badge.exclamationmark").foregroundColor(.red))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
            )
            
            // 2. Text details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.predictedLabel.capitalized)
                        .font(.headline)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.createdAt.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundColor(theme.palette.textSecondary)
                }
                
                if item.userCorrection.caseInsensitiveCompare(item.predictedLabel) != .orderedSame {
                    HStack(spacing: 4) {
                        Text(item.predictedLabel.capitalized)
                            .strikethrough()
                            .foregroundColor(theme.semanticDanger.opacity(0.7))
                        TrashIcon(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(theme.palette.textSecondary)
                        Text(item.userCorrection.capitalized)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.semanticSuccess)
                    }
                    .font(.caption)
                } else {
                    Text(item.predictedLabel.capitalized)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(theme.surfaceBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                                )
                        )
                }
                
                Text("Category: \(item.predictedCategory)")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)

                if let comment = item.userComment, !comment.isEmpty {
                    Text("\"\(comment)\"")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
    }
}
