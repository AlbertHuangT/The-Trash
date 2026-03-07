//
//  UserSettings.swift
//  Smart Sort
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

    private let locationKey = "selectedLocation"
    private let locationManager = LocationManager()
    private let communityStore = CommunityMembershipStore.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSavedData()
        setupLocationManager()
        bindCommunityStore()
    }

    var joinedCommunityIds: Set<String> {
        communityStore.joinedCommunityIds
    }

    var communitiesInCity: [Community] {
        communityStore.communitiesInCity
    }

    var joinedCommunities: [Community] {
        communityStore.joinedCommunities
    }

    var isLoadingCommunities: Bool {
        communityStore.isLoadingCommunities
    }

    var adminCommunities: [Community] {
        communityStore.adminCommunities
    }

    private func bindCommunityStore() {
        communityStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
            _ = try? await CommunityService.shared.updateUserLocation(
                city: location.city,
                state: location.state,
                latitude: location.latitude,
                longitude: location.longitude
            )

            // 加载该城市的社区
            await loadCommunitiesForCity(location.city)
        } else {
            UserDefaults.standard.removeObject(forKey: locationKey)
            communityStore.clearCommunitiesInCity()
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
        await communityStore.loadCommunitiesForCity(city)
    }

    /// 加载用户已加入的社区
    func loadMyCommunities() async {
        await communityStore.loadMyCommunities()
    }

    /// 加入社区（支持审批流程）- Optimistic UI
    func joinCommunity(_ community: Community) async -> (success: Bool, requiresApproval: Bool) {
        await communityStore.joinCommunity(community)
    }

    /// 离开社区 - Optimistic UI
    func leaveCommunity(_ community: Community) async -> Bool {
        await communityStore.leaveCommunity(community)
    }

    /// 检查是否是社区成员
    func isMember(of community: Community) -> Bool {
        communityStore.isMember(of: community)
    }

    /// 检查是否是社区管理员
    func isAdmin(of community: Community) -> Bool {
        communityStore.isAdmin(of: community)
    }

    /// 获取已加入的社区 (本地缓存)
    func getJoinedCommunities() -> [Community] {
        communityStore.getJoinedCommunities()
    }

    /// 获取当前城市的社区
    func getCommunitiesNearLocation(_ location: UserLocation? = nil) -> [Community] {
        communityStore.getCommunitiesNearLocation(location)
    }

    // MARK: - Search (本地)

    func searchCommunities(query: String, inCity: String? = nil) -> [Community] {
        communityStore.searchCommunities(query: query, inCity: inCity)
    }
}
