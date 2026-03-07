//
//  StreakLeaderboardView.swift
//  Smart Sort
//
//  Leaderboard for Streak Mode showing top streaks.
//

import SwiftUI
import Supabase
import Combine

struct StreakLeaderboardView: View {
    @StateObject private var viewModel = StreakLeaderboardViewModel()
    @Environment(\.dismiss) private var dismiss
    private let theme = TrashTheme()

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.entries.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Best Streaks")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(theme.palette.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.8)

                            ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                                StreakLeaderboardRow(rank: index + 1, entry: entry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Streak Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TrashTextButton(title: "Done", variant: .accent) { dismiss() }
                }
            }
            .task {
                await viewModel.fetchLeaderboard()
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.bar.xaxis",
            title: "No Streak Records Yet",
            subtitle: "Be the first to set a record."
        )
    }
}

// MARK: - Row

struct StreakLeaderboardRow: View {
    let rank: Int
    let entry: StreakLeaderboardEntry
    private let theme = TrashTheme()

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return theme.palette.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text("\(rank)")
                        .font(.headline.bold())
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.palette.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.palette.textPrimary)
                Text("\(entry.totalGames) games played")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.bestStreak)")
                    .font(.title3.bold())
                    .foregroundColor(theme.accents.purple)
                Text("best streak")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }
}

// MARK: - ViewModel

@MainActor
class StreakLeaderboardViewModel: ObservableObject {
    @Published var entries: [StreakLeaderboardEntry] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchLeaderboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: [StreakLeaderboardEntry] = try await client
                .rpc("get_streak_leaderboard", params: ["p_limit": 50])
                .execute()
                .value
            self.entries = result
        } catch {
            print("❌ [StreakLeaderboard] Failed: \(error)")
        }
    }
}
