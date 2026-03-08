//
//  CommunityModels.swift
//  Smart Sort
//
//  Extracted from CommunityService.swift
//

import Foundation

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
    let membershipStatus: MembershipStatus?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude
        case memberCount = "member_count"
        case isMember = "is_member"
        case membershipStatus = "membership_status"
        case isAdmin = "is_admin"
    }
}

struct EventResponse: Codable, Identifiable, Hashable, Equatable {
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

    static func == (lhs: EventResponse, rhs: EventResponse) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
    let eventId: UUID?

    enum CodingKeys: String, CodingKey {
        case success, message
        case eventId = "event_id"
    }
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

struct QuizQuestionCandidateResponse: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let username: String
    let imagePath: String
    let predictedLabel: String
    let predictedCategory: String
    let status: String
    let reviewNotes: String?
    let createdAt: Date
    let reviewedAt: Date?
    let publishedQuestionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case imagePath = "image_path"
        case predictedLabel = "predicted_label"
        case predictedCategory = "predicted_category"
        case status
        case reviewNotes = "review_notes"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
        case publishedQuestionId = "published_question_id"
    }
}

struct QuizCandidateQueryParams: Sendable {
    let p_status: String?
    let p_limit: Int
}

extension QuizCandidateQueryParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(p_status, forKey: .p_status)
        try container.encode(p_limit, forKey: .p_limit)
    }

    private enum CodingKeys: String, CodingKey {
        case p_status, p_limit
    }
}

struct ReviewQuizQuestionCandidateParams: Sendable {
    let p_candidate_id: String
    let p_decision: String
    let p_review_notes: String?
    let p_item_name: String?
    let p_category: String?
    let p_public_image_url: String?
}

extension ReviewQuizQuestionCandidateParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_candidate_id, forKey: .p_candidate_id)
        try container.encode(p_decision, forKey: .p_decision)
        try container.encodeIfPresent(p_review_notes, forKey: .p_review_notes)
        try container.encodeIfPresent(p_item_name, forKey: .p_item_name)
        try container.encodeIfPresent(p_category, forKey: .p_category)
        try container.encodeIfPresent(p_public_image_url, forKey: .p_public_image_url)
    }

    private enum CodingKeys: String, CodingKey {
        case p_candidate_id, p_decision, p_review_notes, p_item_name, p_category, p_public_image_url
    }
}

struct QuizCandidateReviewResult: Codable {
    let success: Bool
    let decision: String
    let publishedQuestionId: UUID?

    enum CodingKeys: String, CodingKey {
        case success
        case decision
        case publishedQuestionId = "published_question_id"
    }
}

// MARK: - RPC Parameter Structs (Sendable for safe cross-actor usage)

struct NearbyEventsParams: Sendable {
    let p_latitude: Double
    let p_longitude: Double
    let p_max_distance_km: Double
    let p_category: String?
    let p_only_joined_communities: Bool
    let p_sort_by: String
}

struct JoinCommunityParams: Sendable {
    let p_community_id: String
    let p_message: String?
}

extension JoinCommunityParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encodeIfPresent(p_message, forKey: .p_message)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_message
    }
}

extension NearbyEventsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_max_distance_km, forKey: .p_max_distance_km)
        try container.encodeIfPresent(p_category, forKey: .p_category)
        try container.encode(p_only_joined_communities, forKey: .p_only_joined_communities)
        try container.encode(p_sort_by, forKey: .p_sort_by)
    }

    private enum CodingKeys: String, CodingKey {
        case p_latitude, p_longitude, p_max_distance_km, p_category, p_only_joined_communities, p_sort_by
    }
}

struct CreateCommunityParams: Sendable {
    let p_id: String
    let p_name: String
    let p_city: String
    let p_state: String
    let p_description: String?
    let p_latitude: Double?
    let p_longitude: Double?
}

extension CreateCommunityParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_id, forKey: .p_id)
        try container.encode(p_name, forKey: .p_name)
        try container.encode(p_city, forKey: .p_city)
        try container.encode(p_state, forKey: .p_state)
        try container.encodeIfPresent(p_description, forKey: .p_description)
        try container.encodeIfPresent(p_latitude, forKey: .p_latitude)
        try container.encodeIfPresent(p_longitude, forKey: .p_longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case p_id, p_name, p_city, p_state, p_description, p_latitude, p_longitude
    }
}

struct CreateEventParams: Sendable {
    let p_title: String
    let p_description: String
    let p_category: String
    let p_event_date: String
    let p_location: String
    let p_latitude: Double
    let p_longitude: Double
    let p_max_participants: Int
    let p_community_id: String?
    let p_icon_name: String
}

extension CreateEventParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_title, forKey: .p_title)
        try container.encode(p_description, forKey: .p_description)
        try container.encode(p_category, forKey: .p_category)
        try container.encode(p_event_date, forKey: .p_event_date)
        try container.encode(p_location, forKey: .p_location)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
        try container.encode(p_max_participants, forKey: .p_max_participants)
        try container.encodeIfPresent(p_community_id, forKey: .p_community_id)
        try container.encode(p_icon_name, forKey: .p_icon_name)
    }

    private enum CodingKeys: String, CodingKey {
        case p_title, p_description, p_category, p_event_date, p_location
        case p_latitude, p_longitude, p_max_participants, p_community_id, p_icon_name
    }
}

struct LocationParams: Sendable {
    let p_city: String
    let p_state: String
    let p_latitude: Double
    let p_longitude: Double
}

extension LocationParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_city, forKey: .p_city)
        try container.encode(p_state, forKey: .p_state)
        try container.encode(p_latitude, forKey: .p_latitude)
        try container.encode(p_longitude, forKey: .p_longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case p_city, p_state, p_latitude, p_longitude
    }
}

// MARK: - Admin RPC Parameter Structs

struct UpdateCommunityInfoParams: Sendable {
    let p_community_id: String
    let p_description: String?
    let p_welcome_message: String?
    let p_rules: String?
    let p_requires_approval: Bool?
}

extension UpdateCommunityInfoParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encodeIfPresent(p_description, forKey: .p_description)
        try container.encodeIfPresent(p_welcome_message, forKey: .p_welcome_message)
        try container.encodeIfPresent(p_rules, forKey: .p_rules)
        try container.encodeIfPresent(p_requires_approval, forKey: .p_requires_approval)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_description, p_welcome_message, p_rules, p_requires_approval
    }
}

struct ReviewApplicationParams: Sendable {
    let p_application_id: String
    let p_approve: Bool
    let p_rejection_reason: String?
}

extension ReviewApplicationParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_application_id, forKey: .p_application_id)
        try container.encode(p_approve, forKey: .p_approve)
        try container.encodeIfPresent(p_rejection_reason, forKey: .p_rejection_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_application_id, p_approve, p_rejection_reason
    }
}

struct RemoveMemberParams: Sendable {
    let p_community_id: String
    let p_user_id: String
    let p_reason: String?
}

extension RemoveMemberParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encode(p_user_id, forKey: .p_user_id)
        try container.encodeIfPresent(p_reason, forKey: .p_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_user_id, p_reason
    }
}

struct GrantCreditsParams: Sendable {
    let p_event_id: String
    let p_user_ids: [String]
    let p_credits_per_user: Int
    let p_reason: String
}

extension GrantCreditsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_event_id, forKey: .p_event_id)
        try container.encode(p_user_ids, forKey: .p_user_ids)
        try container.encode(p_credits_per_user, forKey: .p_credits_per_user)
        try container.encode(p_reason, forKey: .p_reason)
    }

    private enum CodingKeys: String, CodingKey {
        case p_event_id, p_user_ids, p_credits_per_user, p_reason
    }
}

struct GetAdminLogsParams: Sendable {
    let p_community_id: String
    let p_limit: Int
}

extension GetAdminLogsParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_community_id, forKey: .p_community_id)
        try container.encode(p_limit, forKey: .p_limit)
    }

    private enum CodingKeys: String, CodingKey {
        case p_community_id, p_limit
    }
}

// MARK: - Community (UI Working Model)
// Mutable working model used by UserSettings for optimistic UI updates.
// Constructed from CommunityResponse via init(from:).

struct Community: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let city: String
    let state: String
    let description: String
    var memberCount: Int
    let latitude: Double
    let longitude: Double
    var isMember: Bool = false
    var isAdmin: Bool = false

    var displayName: String { name }
    var fullLocation: String { "\(city), \(state)" }

    init(from response: CommunityResponse) {
        self.id = response.id
        self.name = response.name
        self.city = response.city
        self.state = response.state ?? ""
        self.description = response.description ?? ""
        self.memberCount = response.memberCount
        self.latitude = response.latitude ?? 0
        self.longitude = response.longitude ?? 0
        self.isMember = response.membershipStatus == .member || response.membershipStatus == .admin || response.isMember == true
        self.isAdmin = response.membershipStatus == .admin || response.isAdmin == true
    }

    init(id: String, name: String, city: String, state: String, description: String, memberCount: Int, latitude: Double, longitude: Double, isMember: Bool = false, isAdmin: Bool = false) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state
        self.description = description
        self.memberCount = memberCount
        self.latitude = latitude
        self.longitude = longitude
        self.isMember = isMember
        self.isAdmin = isAdmin
    }
}

// MARK: - Membership Status

enum MembershipStatus: String, Codable {
    case none = "none"
    case pending = "pending"
    case member = "member"
    case admin = "admin"
}
