//
//  CommunityModels.swift
//  The Trash
//
//  Extracted from CommunityService.swift
//

import Foundation
import Combine

// MARK: - API Response Models

struct CommunityResponse: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let latitude: Double?
    let longitude: Double?
    let isMember: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude
        case memberCount = "member_count"
        case isMember = "is_member"
    }
}

struct EventResponse: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let organizer: String
    let category: String
    let eventDate: Date
    let location: String
    let latitude: Double
    let longitude: Double
    let iconName: String?
    let maxParticipants: Int
    let participantCount: Int
    let communityId: String?
    let communityName: String?
    let distanceKm: Double?
    let isRegistered: Bool?
    let isPersonal: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, description, organizer, category, location, latitude, longitude
        case eventDate = "event_date"
        case iconName = "icon_name"
        case maxParticipants = "max_participants"
        case participantCount = "participant_count"
        case communityId = "community_id"
        case communityName = "community_name"
        case distanceKm = "distance_km"
        case isRegistered = "is_registered"
        case isPersonal = "is_personal"
    }
}

struct MyRegistrationResponse: Codable, Identifiable {
    let registrationId: UUID
    let eventId: UUID
    let eventTitle: String
    let eventDate: Date
    let eventLocation: String
    let eventCategory: String
    let communityName: String
    let registrationStatus: String
    let registeredAt: Date

    var id: UUID { registrationId }

    enum CodingKeys: String, CodingKey {
        case registrationId = "registration_id"
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventDate = "event_date"
        case eventLocation = "event_location"
        case eventCategory = "event_category"
        case communityName = "community_name"
        case registrationStatus = "registration_status"
        case registeredAt = "registered_at"
    }
}

struct MyCommunityResponse: Codable, Identifiable {
    let id: String
    let name: String
    let city: String
    let state: String?
    let description: String?
    let memberCount: Int
    let joinedAt: Date
    let status: String

    var isAdmin: Bool {
        status == "admin"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, status
        case memberCount = "member_count"
        case joinedAt = "joined_at"
    }
}

struct APIResult: Codable {
    let success: Bool
    let message: String
}

struct CanCreateResult: Codable {
    let allowed: Bool
    let reason: String?
    let currentCount: Int
    let maxAllowed: Int

    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case currentCount = "current_count"
        case maxAllowed = "max_allowed"
    }
}

// MARK: - Admin Feature Models

struct JoinCommunityResult: Codable {
    let success: Bool
    let message: String
    let requiresApproval: Bool

    enum CodingKeys: String, CodingKey {
        case success, message
        case requiresApproval = "requires_approval"
    }
}

struct JoinApplicationResponse: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let userCredits: Int
    let message: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case userCredits = "user_credits"
        case message
        case createdAt = "created_at"
    }
}

struct CommunityMemberResponse: Identifiable, Codable {
    let userId: UUID
    let username: String
    let credits: Int
    let status: String
    let joinedAt: Date
    let isAdmin: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username, credits, status
        case joinedAt = "joined_at"
        case isAdmin = "is_admin"
    }
}

struct AdminActionLogResponse: Identifiable, Codable {
    let id: UUID
    let adminUsername: String
    let actionType: String
    let targetUsername: String?
    let createdAt: Date

    var actionDescription: String {
        switch actionType {
        case "approve_member": return "Approved member"
        case "reject_member": return "Rejected application"
        case "remove_member": return "Removed member"
        case "grant_credits": return "Granted credits"
        case "edit_community": return "Edited community"
        case "edit_event": return "Edited event"
        case "delete_event": return "Deleted event"
        default: return actionType
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case adminUsername = "admin_username"
        case actionType = "action_type"
        case targetUsername = "target_username"
        case createdAt = "created_at"
    }
}

struct GrantCreditsResult: Codable {
    let success: Bool
    let message: String
    let grantedCount: Int

    enum CodingKeys: String, CodingKey {
        case success, message
        case grantedCount = "granted_count"
    }
}

struct EventParticipantResponse: Identifiable, Codable {
    let userId: UUID
    let username: String
    let credits: Int
    let registeredAt: Date

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username, credits
        case registeredAt = "registered_at"
    }
}

struct CommunitySettingsResponse: Codable {
    let id: String
    let description: String?
    let welcomeMessage: String?
    let rules: String?
    let requiresApproval: Bool?

    enum CodingKeys: String, CodingKey {
        case id, description, rules
        case welcomeMessage = "welcome_message"
        case requiresApproval = "requires_approval"
    }
}
