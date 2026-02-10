//
//  DailyLeaderboardView.swift
//  The Trash
//
//  Leaderboard for Daily Challenge.
//

import SwiftUI
import Supabase
import Combine

struct DailyLeaderboardView: View {
    @StateObject private var viewModel = DailyLeaderboardViewModel()
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
                            ForEach(viewModel.entries) { entry in
                                DailyLeaderboardRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Today's Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.neuAccentBlue)
                }
            }
            .task {
                await viewModel.fetchLeaderboard()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(.neuSecondaryText)
            Text("No results yet")
                .font(.headline)
                .foregroundColor(.neuText)
            Text("Be the first to complete today's challenge!")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
        }
    }
}

// MARK: - Row

struct DailyLeaderboardRow: View {
    let entry: DailyLeaderboardEntry

    var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .neuSecondaryText
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
        HStack(spacing: 14) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text("\(entry.rank)")
                        .font(.headline.bold())
                        .foregroundColor(rankColor)
                } else {
                    Text("\(entry.rank)")
                        .font(.subheadline.bold())
                        .foregroundColor(.neuSecondaryText)
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)

                HStack(spacing: 8) {
                    Label("\(entry.correctCount)/10", systemImage: "checkmark.circle")
                    Label(formattedTime, systemImage: "timer")
                }
                .font(.caption)
                .foregroundColor(.neuSecondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.score)")
                    .font(.title3.bold())
                    .foregroundColor(.green)
                Text("pts")
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
class DailyLeaderboardViewModel: ObservableObject {
    @Published var entries: [DailyLeaderboardEntry] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client

    func fetchLeaderboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: [DailyLeaderboardEntry] = try await client
                .rpc("get_daily_leaderboard", params: ["p_limit": 50])
                .execute()
                .value
            self.entries = result
        } catch {
            print("❌ [DailyLeaderboard] Failed: \(error)")
        }
    }
}
