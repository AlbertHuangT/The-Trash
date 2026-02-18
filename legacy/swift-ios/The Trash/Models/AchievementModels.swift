//
//  AchievementModels.swift
//  The Trash
//
//  Created by Albert Huang on 2/8/26.
//

import Foundation
import SwiftUI

// MARK: - Achievement Rarity

enum AchievementRarity: String, Codable, CaseIterable {
    case common, rare, epic, legendary

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    var gradient: [Color] {
        switch self {
        case .common: return [.gray, .secondary]
        case .rare: return [.blue, .cyan]
        case .epic: return [.purple, .indigo]
        case .legendary: return [.orange, .yellow]
        }
    }
}

struct Achievement: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let iconName: String
    let communityId: String?
    let isHidden: Bool
    let rarity: AchievementRarity

    var isOfficial: Bool {
        communityId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, rarity
        case iconName = "icon_name"
        case communityId = "community_id"
        case isHidden = "is_hidden"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decode(String.self, forKey: .iconName)
        communityId = try container.decodeIfPresent(String.self, forKey: .communityId)
        isHidden = try container.decode(Bool.self, forKey: .isHidden)
        rarity = try container.decodeIfPresent(AchievementRarity.self, forKey: .rarity) ?? .common
    }

    init(id: UUID, name: String, description: String?, iconName: String, communityId: String?, isHidden: Bool, rarity: AchievementRarity = .common) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.communityId = communityId
        self.isHidden = isHidden
        self.rarity = rarity
    }
}

struct UserAchievement: Codable, Identifiable, Hashable {
    let id: UUID // user_achievement id
    let achievementId: UUID
    let name: String
    let description: String?
    let iconName: String
    let communityId: String?
    let communityName: String?
    let grantedAt: Date
    let isEquipped: Bool
    let rarity: AchievementRarity

    var isOfficial: Bool {
        communityId == nil
    }

    enum CodingKeys: String, CodingKey {
        case id = "user_achievement_id"
        case achievementId = "achievement_id"
        case name, description, rarity
        case iconName = "icon_name"
        case communityId = "community_id"
        case communityName = "community_name"
        case grantedAt = "granted_at"
        case isEquipped = "is_equipped"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        achievementId = try container.decode(UUID.self, forKey: .achievementId)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decode(String.self, forKey: .iconName)
        communityId = try container.decodeIfPresent(String.self, forKey: .communityId)
        communityName = try container.decodeIfPresent(String.self, forKey: .communityName)
        grantedAt = try container.decode(Date.self, forKey: .grantedAt)
        isEquipped = try container.decode(Bool.self, forKey: .isEquipped)
        rarity = try container.decodeIfPresent(AchievementRarity.self, forKey: .rarity) ?? .common
    }
}

// MARK: - Grant Result (from check_and_grant_achievement RPC)

struct AchievementGrantResult: Codable {
    let granted: Bool
    let reason: String?
    let achievementId: UUID?
    let name: String?
    let description: String?
    let iconName: String?
    let rarity: AchievementRarity?

    enum CodingKeys: String, CodingKey {
        case granted, reason, name, description, rarity
        case achievementId = "achievement_id"
        case iconName = "icon_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        granted = try container.decode(Bool.self, forKey: .granted)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        achievementId = try container.decodeIfPresent(UUID.self, forKey: .achievementId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        rarity = try container.decodeIfPresent(AchievementRarity.self, forKey: .rarity)
    }
}

// MARK: - Community Member for Grant UI

struct CommunityMemberForGrant: Codable, Identifiable {
    let userId: UUID
    let username: String
    let alreadyHas: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case alreadyHas = "already_has"
    }
}

// MARK: - API Params

struct AchievementGrantParams: Codable, Sendable {
    let user_id: UUID
    let achievement_id: UUID
    let community_id: String
}

struct AchievementEquipParams: Sendable {
    let achievement_id: UUID?
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

