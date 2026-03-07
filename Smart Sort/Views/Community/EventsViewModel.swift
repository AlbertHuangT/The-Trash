//
//  EventsViewModel.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [CommunityEvent] = []
    @Published var isLoading = false
    @Published var selectedCategory: CommunityEvent.EventCategory?
    @Published var sortOption: EventSortOption = .distance
    @Published var showOnlyJoinedCommunities = false
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?
    private let minLoadInterval: TimeInterval = 0.5

    private var userSettings: UserSettings {
        UserSettings.shared
    }

    private var eventService: EventService {
        EventService.shared
    }

    var hasLocation: Bool {
        userSettings.selectedLocation != nil
    }

    var locationName: String {
        userSettings.selectedLocation?.city ?? ""
    }

    private var currentCoordinates: (latitude: Double, longitude: Double)? {
        if let preciseLocation = userSettings.preciseLocation {
            return (preciseLocation.coordinate.latitude, preciseLocation.coordinate.longitude)
        }

        if let location = userSettings.selectedLocation {
            return (location.latitude, location.longitude)
        }

        return nil
    }

    func requestPreciseLocation() {
        if userSettings.hasLocationPermission {
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            userSettings.requestLocationPermission()
        }
    }

    func sortEventsByPreciseDistance() {
        guard sortOption == .distance, let preciseLocation = userSettings.preciseLocation else { return }

        events.sort { event1, event2 in
            let distance1 = event1.distance(
                from: userSettings.selectedLocation,
                preciseLocation: preciseLocation
            )
            let distance2 = event2.distance(
                from: userSettings.selectedLocation,
                preciseLocation: preciseLocation
            )
            return distance1 < distance2
        }
    }

    func loadEvents() async {
        loadTask?.cancel()

        if let lastLoadTime, Date().timeIntervalSince(lastLoadTime) < minLoadInterval {
            try? await Task.sleep(nanoseconds: UInt64(minLoadInterval * 1_000_000_000))
        }

        guard let currentCoordinates else {
            events = []
            return
        }

        if events.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        lastLoadTime = Date()

        let categoryParam = selectedCategory?.rawValue.lowercased()
        let sortByParam: String
        switch sortOption {
        case .date: sortByParam = "date"
        case .distance: sortByParam = "distance"
        case .participants: sortByParam = "popularity"
        }

        do {
            let response = try await eventService.getNearbyEvents(
                latitude: currentCoordinates.latitude,
                longitude: currentCoordinates.longitude,
                maxDistanceKm: 50,
                category: categoryParam,
                onlyJoinedCommunities: showOnlyJoinedCommunities,
                sortBy: sortByParam
            )

            guard !Task.isCancelled else { return }
            events = response.map(CommunityEvent.init(from:))
        } catch {
            guard !Task.isCancelled else { return }
            print("❌ Get nearby events error: \(error)")
            errorMessage = error.localizedDescription
        }

        if sortOption == .distance, userSettings.preciseLocation != nil {
            sortEventsByPreciseDistance()
        }

        isLoading = false
    }

    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.registerForEvent(event.id)
            if success, let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = true
                events[index].participantCount += 1
            }
            return success
        } catch {
            print("❌ Register for event error: \(error)")
            return false
        }
    }

    func cancelRegistration(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.cancelEventRegistration(event.id)
            if success, let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = false
                events[index].participantCount = max(0, events[index].participantCount - 1)
            }
            return success
        } catch {
            print("❌ Cancel registration error: \(error)")
            return false
        }
    }

    func toggleRegistration(for event: CommunityEvent) async {
        if event.isRegistered {
            _ = await cancelRegistration(event)
        } else {
            _ = await registerForEvent(event)
        }
    }
}
