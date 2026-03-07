//
//  CommunityService.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Foundation
import Supabase

// MARK: - Community Service

@MainActor
class CommunityService {
    static let shared = CommunityService()

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {}

    // MARK: - Community Methods

    /// 获取指定城市的社区列表
    func getCommunitiesByCity(_ city: String) async throws -> [CommunityResponse] {
        return try await client
            .rpc("get_communities_by_city", params: ["p_city": city])
            .execute()
            .value
    }

    /// 获取用户已加入的社区
    func getMyCommunities() async throws -> [MyCommunityResponse] {
        return try await client
            .rpc("get_my_communities")
            .execute()
            .value
    }

    /// 加入社区（支持审批流程）
    func joinCommunity(_ communityId: String, message: String? = nil) async throws -> JoinCommunityResult {
        let params = JoinCommunityParams(
            p_community_id: communityId,
            p_message: message
        )
        return try await client
            .rpc("apply_to_join_community", params: params)
            .execute()
            .value
    }

    /// 离开社区
    func leaveCommunity(_ communityId: String) async throws -> Bool {
        let result: APIResult = try await client
            .rpc("leave_community", params: ["p_community_id": communityId])
            .execute()
            .value
        return result.success
    }

    // MARK: - Location Methods

    /// 更新用户位置
    func updateUserLocation(city: String, state: String, latitude: Double, longitude: Double) async throws -> Bool {
        let params = LocationParams(
            p_city: city,
            p_state: state,
            p_latitude: latitude,
            p_longitude: longitude
        )
        let result: APIResult = try await client
            .rpc("update_user_location", params: params)
            .execute()
            .value
        return result.success
    }

    // MARK: - Direct Table Access (for communities list)

    /// 获取所有社区列表
    func getAllCommunities() async throws -> [CommunityResponse] {
        return try await client
            .from("communities")
            .select("id, name, city, state, description, member_count, latitude, longitude")
            .eq("is_active", value: true)
            .order("member_count", ascending: false)
            .execute()
            .value
    }

    // MARK: - Create Content Methods

    /// 检查用户是否可以创建社区（最多3个）
    func canCreateCommunity() async throws -> (allowed: Bool, currentCount: Int, maxAllowed: Int, reason: String?) {
        let result: CanCreateResult = try await client
            .rpc("can_user_create_community")
            .execute()
            .value
        return (result.allowed, result.currentCount, result.maxAllowed, result.reason)
    }

    /// 创建社区
    func createCommunity(
        id: String,
        name: String,
        city: String,
        state: String,
        description: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> (success: Bool, message: String, communityId: String?) {
        let params = CreateCommunityParams(
            p_id: id,
            p_name: name,
            p_city: city,
            p_state: state,
            p_description: description,
            p_latitude: latitude,
            p_longitude: longitude
        )
        let result: APIResult = try await client
            .rpc("create_community", params: params)
            .execute()
            .value
        return (result.success, result.message, result.success ? id : nil)
    }

}
