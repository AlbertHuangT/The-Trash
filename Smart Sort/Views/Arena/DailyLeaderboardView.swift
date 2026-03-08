//
//  DailyLeaderboardView.swift
//  Smart Sort
//
//  Leaderboard for Daily Challenge.
//

import Combine
import Supabase
import SwiftUI

struct DailyLeaderboardView: View {
    @StateObject private var viewModel = DailyLeaderboardViewModel()
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
                        LazyVStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                            Text("Top Runs Today")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(theme.palette.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.6)

                            ForEach(viewModel.entries) { entry in
                                DailyLeaderboardRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, theme.layout.screenInset)
                        .padding(.top, theme.layout.elementSpacing)
                        .padding(.bottom, theme.layout.sectionSpacing)
                    }
                }
            }
            .trashScreenBackground()
            .navigationTitle("Today's Leaderboard")
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
            icon: "calendar.badge.clock",
            title: "No Results Yet",
            subtitle: "Be the first to complete today's challenge."
        )
    }
}

// MARK: - Row

struct DailyLeaderboardRow: View {
    let entry: DailyLeaderboardEntry
    private let theme = TrashTheme()

    var rankColor: Color {
        switch entry.rank {
        case 1: return theme.medalGold
        case 2: return theme.medalSilver
        case 3: return theme.medalBronze
        default: return theme.palette.textSecondary
        }
    }

    var formattedTime: String {
        let totalSeconds = entry.timeSeconds
        let mins = Int(totalSeconds) / 60
        let secs = Int(totalSeconds) % 60
        if mins > 0 {
            return String(format: "%d:%02ds", mins, secs)
        }
        return String(format: "%ds", secs)
    }

    var body: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                    Text("\(entry.rank)")
                        .font(.headline.bold())
                        .foregroundColor(rankColor)
                } else {
                    Text("\(entry.rank)")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.palette.textSecondary)
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    TrashLabel("\(entry.correctCount)/10", icon: "checkmark.circle")
                    TrashLabel(formattedTime, icon: "timer")
                }
                .font(.caption)
                .foregroundColor(theme.palette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.score)")
                    .font(.title3.bold())
                    .foregroundColor(theme.accents.green)
                Text("pts")
                    .font(.caption2)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
        .padding(.horizontal, theme.components.contentInset)
        .padding(.vertical, theme.layout.elementSpacing)
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
}

// MARK: - ViewModel

@MainActor
class DailyLeaderboardViewModel: ObservableObject {
    @Published var entries: [DailyLeaderboardEntry] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchLeaderboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: [DailyLeaderboardEntry] =
                try await client
                .rpc("get_daily_leaderboard", params: ["p_limit": 50])
                .execute()
                .value
            self.entries = result
        } catch {
            print("❌ [DailyLeaderboard] Failed: \(error)")
        }
    }
}
