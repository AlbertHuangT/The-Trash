//
//  AchievementModels.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import Foundation

struct Achievement: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let iconName: String
    let communityId: UUID?
    let isHidden: Bool
    
    var isOfficial: Bool {
        communityId == nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconName = "icon_name"
        case communityId = "community_id"
        case isHidden = "is_hidden"
    }
}

struct UserAchievement: Codable, Identifiable, Hashable {
    let id: UUID // user_achievement id
    let achievementId: UUID
    let name: String
    let description: String?
    let iconName: String
    let communityId: UUID?
    let communityName: String?
    let grantedAt: Date
    let isEquipped: Bool
    
    var isOfficial: Bool {
        communityId == nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "user_achievement_id"
        case achievementId = "achievement_id"
        case name, description
        case iconName = "icon_name"
        case communityId = "community_id"
        case communityName = "community_name"
        case grantedAt = "granted_at"
        case isEquipped = "is_equipped"
    }
}

// MARK: - API Params

struct AchievementGrantParams: Codable, Sendable {
    let user_id: UUID
    let achievement_id: UUID
    let community_id: UUID
}

struct AchievementEquipParams: Sendable {
    let achievement_id: UUID
}
extension AchievementEquipParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(achievement_id, forKey: .achievement_id)
    }
    
    private enum CodingKeys: String, CodingKey {
        case achievement_id
    }
}

