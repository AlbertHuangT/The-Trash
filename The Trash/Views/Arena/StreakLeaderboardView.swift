//
//  StreakLeaderboardView.swift
//  The Trash
//
//  Leaderboard for Streak Mode showing top streaks.
//

import SwiftUI
import Supabase
import Combine

struct StreakLeaderboardView: View {
    @StateObject private var viewModel = StreakLeaderboardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.neuBackground
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    EnhancedLoadingView()
                } else if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
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
        VStack(spacing: 16) {
            TrashIcon(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.neuSecondaryText)
            Text("No streak records yet")
                .font(.headline)
                .foregroundColor(.neuText)
            Text("Be the first to set a record!")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// MARK: - Row

struct StreakLeaderboardRow: View {
    let rank: Int
    let entry: StreakLeaderboardEntry

    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .neuSecondaryText
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
                        .foregroundColor(.neuSecondaryText)
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)
                Text("\(entry.totalGames) games played")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.bestStreak)")
                    .font(.title3.bold())
                    .foregroundColor(.neuAccentPurple)
                Text("best streak")
                    .font(.caption2)
                    .foregroundColor(.neuSecondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.neuBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
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
