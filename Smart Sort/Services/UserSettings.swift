//
//  UserSettings.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine
import CoreLocation
import Supabase

// MARK: - User Settings Manager

@MainActor
class UserSettings: ObservableObject {
    static let shared = UserSettings()

    // User-selected location
    @Published var selectedLocation: UserLocation?

    // Precise location state
    @Published var preciseLocation: CLLocation?
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var isRequestingLocation = false
    @Published var locationSyncError: String?

    private let locationKey = "selectedLocation"
    private let locationManager = LocationManager()
    private let communityStore = CommunityMembershipStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var locationRequestTimeoutTask: Task<Void, Never>?

    private init() {
        refreshForCurrentUser()
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

    // Configure the location manager callbacks
    private func setupLocationManager() {
        locationManager.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.locationPermissionStatus = status
                if status == .denied || status == .restricted {
                    self?.cancelLocationRequestTimeout()
                    self?.isRequestingLocation = false
                    self?.locationSyncError = "Location access is unavailable. Please choose a city instead."
                }
            }
        }
        locationManager.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.cancelLocationRequestTimeout()
                self?.preciseLocation = location
                self?.locationSyncError = nil
                self?.isRequestingLocation = false
            }
        }
        locationManager.onLocationError = { [weak self] error in
            Task { @MainActor in
                self?.cancelLocationRequestTimeout()
                self?.locationSyncError = Self.message(for: error)
                self?.isRequestingLocation = false
            }
        }
        locationPermissionStatus = locationManager.authorizationStatus
    }

    // Request location permission
    func requestLocationPermission() {
        locationManager.requestPermission()
    }

    // Request the current precise location
    func requestCurrentLocation() {
        guard hasLocationPermission else {
            isRequestingLocation = false
            locationSyncError = "Location permission is required before using your current location."
            return
        }

        locationSyncError = nil
        cancelLocationRequestTimeout()
        isRequestingLocation = true
        locationRequestTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, self.isRequestingLocation else { return }
            self.isRequestingLocation = false
            self.locationSyncError = "Current location timed out. Please try again or pick a city manually."
        }
        locationManager.requestLocation()
    }

    // Whether precise location permission is available
    var hasLocationPermission: Bool {
        locationPermissionStatus == .authorizedWhenInUse || locationPermissionStatus == .authorizedAlways
    }

    private func loadSavedData() {
        // Load the persisted location
        if let data = UserDefaults.standard.data(forKey: scopedLocationKey()),
           let location = try? JSONDecoder().decode(UserLocation.self, from: data) {
            selectedLocation = location
        }

    }

    func refreshForCurrentUser() {
        cancelLocationRequestTimeout()
        selectedLocation = nil
        preciseLocation = nil
        isRequestingLocation = false
        locationSyncError = nil
        communityStore.refreshForCurrentUser()
        loadSavedData()
    }

    // MARK: - Location Methods

    func selectLocation(_ location: UserLocation?) async {
        let previousLocation = selectedLocation
        selectedLocation = location
        locationSyncError = nil

        if let location = location {
            do {
                let success = try await CommunityService.shared.updateUserLocation(
                    city: location.city,
                    state: location.state,
                    latitude: location.latitude,
                    longitude: location.longitude
                )

                guard success else {
                    throw NSError(
                        domain: "UserSettings",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Server rejected location update"]
                    )
                }
            } catch {
                selectedLocation = previousLocation
                locationSyncError = error.localizedDescription
                return
            }

            if let data = try? JSONEncoder().encode(location) {
                UserDefaults.standard.set(data, forKey: scopedLocationKey())
            }

            // Load communities for the selected city
            await loadCommunitiesForCity(location.city)
        } else {
            UserDefaults.standard.removeObject(forKey: scopedLocationKey())
            communityStore.clearCommunitiesInCity()
        }
    }

    // Synchronous wrapper for UI bindings
    func selectLocationSync(_ location: UserLocation?) {
        Task {
            await selectLocation(location)
        }
    }

    // MARK: - Community Methods

    /// Load communities for a specific city
    func loadCommunitiesForCity(_ city: String) async {
        await communityStore.loadCommunitiesForCity(city)
    }

    /// Load the user's joined communities
    func loadMyCommunities() async {
        await communityStore.loadMyCommunities()
    }

    /// Join a community, supporting approval flows, with optimistic UI
    func joinCommunity(_ community: Community) async -> (success: Bool, requiresApproval: Bool) {
        await communityStore.joinCommunity(community)
    }

    /// Leave a community with optimistic UI updates
    func leaveCommunity(_ community: Community) async -> Bool {
        await communityStore.leaveCommunity(community)
    }

    /// Check whether the user is a member of the community
    func isMember(of community: Community) -> Bool {
        communityStore.isMember(of: community)
    }

    /// Check whether the user is an admin of the community
    func isAdmin(of community: Community) -> Bool {
        communityStore.isAdmin(of: community)
    }

    func isPending(of community: Community) -> Bool {
        communityStore.isPending(of: community)
    }

    /// Return joined communities from local cache
    func getJoinedCommunities() -> [Community] {
        communityStore.getJoinedCommunities()
    }

    /// Return communities near the current city selection
    func getCommunitiesNearLocation(_ location: UserLocation? = nil) -> [Community] {
        communityStore.getCommunitiesNearLocation(location)
    }

    // MARK: - Local search

    func searchCommunities(query: String, inCity: String? = nil) -> [Community] {
        communityStore.searchCommunities(query: query, inCity: inCity)
    }

    private func scopedLocationKey() -> String {
        let userNamespace = SupabaseManager.shared.client.auth.currentUser?.id.uuidString ?? "guest"
        return "\(locationKey):\(userNamespace)"
    }

    private func cancelLocationRequestTimeout() {
        locationRequestTimeoutTask?.cancel()
        locationRequestTimeoutTask = nil
    }

    private static func message(for error: Error) -> String {
        guard let clError = error as? CLError else {
            return "Unable to determine your current location right now."
        }

        switch clError.code {
        case .denied:
            return "Location access was denied. Please choose a city instead."
        case .network:
            return "A network issue prevented location lookup. Please try again."
        case .locationUnknown:
            return "Current location is temporarily unavailable. Please try again."
        default:
            return "Unable to determine your current location right now."
        }
    }
}
