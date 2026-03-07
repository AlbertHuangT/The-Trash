//
//  EventService.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import Foundation
import Supabase

@MainActor
final class EventService {
    static let shared = EventService()

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    func getNearbyEvents(
        latitude: Double,
        longitude: Double,
        maxDistanceKm: Double = 50,
        category: String? = nil,
        onlyJoinedCommunities: Bool = false,
        sortBy: String = "date"
    ) async throws -> [EventResponse] {
        let params = NearbyEventsParams(
            p_latitude: latitude,
            p_longitude: longitude,
            p_max_distance_km: maxDistanceKm,
            p_category: category,
            p_only_joined_communities: onlyJoinedCommunities,
            p_sort_by: sortBy
        )
        return try await client
            .rpc("get_nearby_events", params: params)
            .execute()
            .value
    }

    func registerForEvent(_ eventId: UUID) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("register_for_event", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return result.success
    }

    func cancelEventRegistration(_ eventId: UUID) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("cancel_event_registration", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
        return result.success
    }

    func getMyRegistrations() async throws -> [MyRegistrationResponse] {
        return try await client
            .rpc("get_my_registrations")
            .execute()
            .value
    }

    func getCommunityEvents(communityId: String) async throws -> [EventResponse] {
        return try await client
            .rpc("get_community_events", params: ["p_community_id": communityId])
            .execute()
            .value
    }

    func canCreateEvent() async throws -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        let result: CanCreateResult = try await client
            .rpc("can_user_create_event")
            .execute()
            .value
        return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
    }

    func createEvent(
        title: String,
        description: String,
        category: String,
        eventDate: Date,
        location: String,
        latitude: Double,
        longitude: Double,
        maxParticipants: Int = 50,
        communityId: String? = nil,
        iconName: String = "calendar"
    ) async throws -> (success: Bool, message: String, eventId: UUID?) {
        let params = CreateEventParams(
            p_title: title,
            p_description: description,
            p_category: category,
            p_event_date: ISO8601DateFormatter().string(from: eventDate),
            p_location: location,
            p_latitude: latitude,
            p_longitude: longitude,
            p_max_participants: maxParticipants,
            p_community_id: communityId,
            p_icon_name: iconName
        )
        let result: APIResult = try await client
            .rpc("create_event", params: params)
            .execute()
            .value
        return (result.success, result.message, result.eventId)
    }

    func grantEventCredits(
        eventId: UUID,
        userIds: [UUID],
        creditsPerUser: Int,
        reason: String
    ) async throws -> GrantCreditsResult {
        let params = GrantCreditsParams(
            p_event_id: eventId.uuidString,
            p_user_ids: userIds.map { $0.uuidString },
            p_credits_per_user: creditsPerUser,
            p_reason: reason
        )
        return try await client
            .rpc("grant_event_credits", params: params)
            .execute()
            .value
    }

    func getEventParticipants(eventId: UUID) async throws -> [EventParticipantResponse] {
        return try await client
            .rpc("get_event_participants", params: ["p_event_id": eventId.uuidString])
            .execute()
            .value
    }
}
