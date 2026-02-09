//
//  UserSettings.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine
import CoreLocation

// MARK: - User Settings Manager

@MainActor
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    // 用户选择的位置
    @Published var selectedLocation: UserLocation?
    
    // 🚀 新增：精确定位相关
    @Published var preciseLocation: CLLocation?
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequestingLocation = false
    
    // 用户已加入的社区 ID 集合 (本地缓存)
    @Published var joinedCommunityIds: Set<String> = []
    
    // 当前城市的社区列表 (从后端获取)
    @Published var communitiesInCity: [Community] = []
    
    // 用户已加入的社区列表 (从后端获取)
    @Published var joinedCommunities: [Community] = []
    
    // 加载状态
    @Published var isLoadingCommunities = false
    
    private let locationKey = "selectedLocation"
    private let joinedCommunitiesKey = "joinedCommunityIds"
    
    // 🚀 新增：定位管理器
    private let locationManager = LocationManager()
    
    private var communityService: CommunityService {
        CommunityService.shared
    }
    
    private init() {
        loadSavedData()
        setupLocationManager()
    }
    
    // 🚀 新增：设置定位管理器
    private func setupLocationManager() {
        locationManager.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.locationPermissionStatus = status
            }
        }
        locationManager.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.preciseLocation = location
                self?.isRequestingLocation = false
            }
        }
        locationManager.onLocationError = { [weak self] _ in
            Task { @MainActor in
                self?.isRequestingLocation = false
            }
        }
        locationPermissionStatus = locationManager.authorizationStatus
    }
    
    // 🚀 新增：请求定位权限
    func requestLocationPermission() {
        locationManager.requestPermission()
    }
    
    // 🚀 新增：获取当前位置
    func requestCurrentLocation() {
        isRequestingLocation = true
        locationManager.requestLocation()
    }
    
    // 🚀 新增：检查是否有定位权限
    var hasLocationPermission: Bool {
        locationPermissionStatus == .authorizedWhenInUse || locationPermissionStatus == .authorizedAlways
    }
    
    private func loadSavedData() {
        // 加载位置
        if let data = UserDefaults.standard.data(forKey: locationKey),
           let location = try? JSONDecoder().decode(UserLocation.self, from: data) {
            selectedLocation = location
        }
        
        // 加载已加入的社区 ID (本地缓存)
        if let ids = UserDefaults.standard.array(forKey: joinedCommunitiesKey) as? [String] {
            joinedCommunityIds = Set(ids)
        }
    }
    
    // MARK: - Location Methods
    
    func selectLocation(_ location: UserLocation?) async {
        selectedLocation = location
        
        if let location = location {
            // 保存到本地
            if let data = try? JSONEncoder().encode(location) {
                UserDefaults.standard.set(data, forKey: locationKey)
            }
            
            // 同步到后端
            _ = await communityService.updateUserLocation(
                city: location.city,
                state: location.state,
                latitude: location.latitude,
                longitude: location.longitude
            )
            
            // 加载该城市的社区
            await loadCommunitiesForCity(location.city)
        } else {
            UserDefaults.standard.removeObject(forKey: locationKey)
            communitiesInCity = []
        }
    }
    
    // 同步版本 (用于 UI 绑定)
    func selectLocationSync(_ location: UserLocation?) {
        Task {
            await selectLocation(location)
        }
    }
    
    // MARK: - Community Methods
    
    /// 加载指定城市的社区
    func loadCommunitiesForCity(_ city: String) async {
        isLoadingCommunities = true
        let response = await communityService.getCommunitiesByCity(city)
        communitiesInCity = response.map { Community(from: $0) }
        
        // 更新本地缓存
        for community in communitiesInCity where community.isMember {
            joinedCommunityIds.insert(community.id)
        }
        saveJoinedCommunities()
        
        isLoadingCommunities = false
    }
    
    /// 加载用户已加入的社区
    func loadMyCommunities() async {
        // 只在列表为空时显示 loading 状态，避免刷新时闪烁
        let showLoading = joinedCommunities.isEmpty
        if showLoading {
            isLoadingCommunities = true
        }
        
        let response = await communityService.getMyCommunities()
        joinedCommunities = response.map { resp in
            Community(
                id: resp.id,
                name: resp.name,
                city: resp.city,
                state: resp.state ?? "",
                description: resp.description ?? "",
                memberCount: resp.memberCount,
                latitude: 0,
                longitude: 0,
                isMember: true,
                isAdmin: resp.isAdmin  // 🚀 设置管理员状态
            )
        }
        
        // 更新本地缓存
        joinedCommunityIds = Set(joinedCommunities.map { $0.id })
        saveJoinedCommunities()
        
        isLoadingCommunities = false
    }
    
    // 🚀 新增：获取用户管理的社区
    var adminCommunities: [Community] {
        joinedCommunities.filter { $0.isAdmin }
    }
    
    /// 加入社区（支持审批流程）- Optimistic UI
    func joinCommunity(_ community: Community) async -> (success: Bool, requiresApproval: Bool) {
        // 1. Optimistic Update
        let originalIds = joinedCommunityIds
        let originalCommunities = communitiesInCity
        let originalJoined = joinedCommunities
        
        joinedCommunityIds.insert(community.id)
        saveJoinedCommunities()
        
        // Update local list status
        if let index = communitiesInCity.firstIndex(where: { $0.id == community.id }) {
            communitiesInCity[index].isMember = true
            communitiesInCity[index].memberCount += 1
        }
        
        // Add to joined list
        var newCommunity = community
        newCommunity.isMember = true
        // If we don't have the member count correct from the list, increment it
        if !communitiesInCity.contains(where: { $0.id == community.id }) {
             newCommunity.memberCount += 1
        }
        joinedCommunities.append(newCommunity)
        
        // 2. Perform Network Request
        let result = await communityService.joinCommunity(community.id)
        
        // 3. Handle Result
        if result.success && !result.requiresApproval {
            // Success: Keep optimistic state (maybe update with fresh data if needed, but simple counter is fine)
            // No action needed
        } else {
            // Failure or Approval Required: Revert Optimistic State
            // If approval is required, user is not yet a member, so revert "isMember" to false.
            joinedCommunityIds = originalIds
            communitiesInCity = originalCommunities
            joinedCommunities = originalJoined
            saveJoinedCommunities()
        }
        
        return (result.success, result.requiresApproval)
    }
    
    /// 离开社区 - Optimistic UI
    func leaveCommunity(_ community: Community) async -> Bool {
        // 1. Optimistic Update
        let originalIds = joinedCommunityIds
        let originalCommunities = communitiesInCity
        let originalJoined = joinedCommunities
        
        joinedCommunityIds.remove(community.id)
        saveJoinedCommunities()
        
        if let index = communitiesInCity.firstIndex(where: { $0.id == community.id }) {
            communitiesInCity[index].isMember = false
            communitiesInCity[index].memberCount = max(0, communitiesInCity[index].memberCount - 1)
        }
        
        joinedCommunities.removeAll { $0.id == community.id }
        
        // 2. Perform Network Request
        let success = await communityService.leaveCommunity(community.id)
        
        // 3. Revert on Failure
        if !success {
            joinedCommunityIds = originalIds
            communitiesInCity = originalCommunities
            joinedCommunities = originalJoined
            saveJoinedCommunities()
        }
        
        return success
    }
    
    /// 检查是否是社区成员
    func isMember(of community: Community) -> Bool {
        joinedCommunityIds.contains(community.id)
    }
    
    /// 检查是否是社区管理员
    func isAdmin(of community: Community) -> Bool {
        joinedCommunities.first(where: { $0.id == community.id })?.isAdmin ?? false
    }
    
    /// 获取已加入的社区 (本地缓存)
    func getJoinedCommunities() -> [Community] {
        joinedCommunities
    }
    
    /// 获取当前城市的社区
    func getCommunitiesNearLocation(_ location: UserLocation? = nil) -> [Community] {
        communitiesInCity
    }
    
    private func saveJoinedCommunities() {
        UserDefaults.standard.set(Array(joinedCommunityIds), forKey: joinedCommunitiesKey)
    }
    
    // MARK: - Search (本地)
    
    func searchCommunities(query: String, inCity: String? = nil) -> [Community] {
        var results = communitiesInCity
        
        if !query.isEmpty {
            let q = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
            }
        }
        
        return results
    }
}
