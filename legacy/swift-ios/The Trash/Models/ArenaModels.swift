//
//  ArenaModels.swift
//  The Trash
//

import Foundation

// MARK: - Game Modes

enum ArenaGameMode: String, Hashable, CaseIterable, Identifiable {
    case classic
    case speedSort
    case streak
    case dailyChallenge
    case duel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic Quiz"
        case .speedSort: return "Speed Sort"
        case .streak: return "Streak Mode"
        case .dailyChallenge: return "Daily Challenge"
        case .duel: return "1v1 Duel"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: return "10 questions, test your knowledge"
        case .speedSort: return "Race against the clock!"
        case .streak: return "How far can you go?"
        case .dailyChallenge: return "Same questions for everyone"
        case .duel: return "Challenge your friends"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "flame.fill"
        case .speedSort: return "bolt.fill"
        case .streak: return "arrow.up.right"
        case .dailyChallenge: return "calendar.circle.fill"
        case .duel: return "person.2.fill"
        }
    }

    var gradientColors: [String] {
        switch self {
        case .classic: return ["neuAccentBlue", "cyan"]
        case .speedSort: return ["orange", "yellow"]
        case .streak: return ["purple", "pink"]
        case .dailyChallenge: return ["green", "mint"]
        case .duel: return ["red", "orange"]
        }
    }

    var isAvailable: Bool {
        return true
    }
}

// MARK: - Streak Models

struct StreakRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let streakCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case streakCount = "streak_count"
        case createdAt = "created_at"
    }
}

struct StreakLeaderboardEntry: Codable, Identifiable {
    let userId: UUID
    let displayName: String
    let bestStreak: Int
    let totalGames: Int

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case bestStreak = "best_streak"
        case totalGames = "total_games"
    }
}
