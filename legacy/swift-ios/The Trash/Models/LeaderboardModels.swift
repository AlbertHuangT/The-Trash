//
//  LeaderboardModels.swift
//  The Trash
//
//  Extracted from LeaderboardView.swift
//

import Foundation

// MARK: - Leaderboard Type

enum LeaderboardType: String, CaseIterable {
    case friends = "Friends"
    case community = "Community"

    var icon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .community: return "building.2.fill"
        }
    }
}

// MARK: - Community Leaderboard User Model

struct CommunityLeaderboardUser: Identifiable, Decodable {
    let id: UUID
    let username: String
    let credits: Int
    let communityName: String?
    let achievementIcon: String?

    enum CodingKeys: String, CodingKey {
        case id, username, credits
        case communityName = "community_name"
        case achievementIcon = "achievement_icon"
    }
}
