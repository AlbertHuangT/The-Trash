//
//  EventModels.swift
//  Smart Sort
//
//  Created by OpenAI Codex on 3/6/26.
//

import CoreLocation
import SwiftUI

enum EventSortOption: String, CaseIterable {
    case date = "Date"
    case distance = "Distance"
    case participants = "Popularity"

    var icon: String {
        switch self {
        case .date: return "calendar"
        case .distance: return "location.fill"
        case .participants: return "person.2.fill"
        }
    }
}

struct CommunityEvent: Identifiable, Hashable, Equatable {
    var id: UUID
    let title: String
    let organizer: String
    let description: String
    let date: Date
    let location: String
    let latitude: Double
    let longitude: Double
    let imageSystemName: String
    let category: EventCategory
    var participantCount: Int
    let maxParticipants: Int
    let communityId: String?
    var communityName: String?
    var distanceKm: Double?
    var isRegistered: Bool = false
    var isPersonal: Bool = false

    enum EventCategory: String, CaseIterable, Codable {
        case cleanup = "Cleanup"
        case workshop = "Workshop"
        case competition = "Competition"
        case education = "Education"

        var color: Color {
            switch self {
            case .cleanup: return .green
            case .workshop: return .blue
            case .competition: return .orange
            case .education: return .purple
            }
        }

        var icon: String {
            switch self {
            case .cleanup: return "leaf.fill"
            case .workshop: return "hammer.fill"
            case .competition: return "trophy.fill"
            case .education: return "book.fill"
            }
        }
    }

    static func == (lhs: CommunityEvent, rhs: CommunityEvent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func distance(from userLocation: UserLocation?, preciseLocation: CLLocation? = nil) -> Double {
        if let distanceKm {
            return distanceKm
        }

        if let preciseLocation {
            let eventLocation = CLLocation(latitude: latitude, longitude: longitude)
            return eventLocation.distance(from: preciseLocation) / 1000.0
        }

        guard let userLocation else { return 0 }
        let eventLocation = CLLocation(latitude: latitude, longitude: longitude)
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        return eventLocation.distance(from: userCLLocation) / 1000.0
    }

    init(from response: EventResponse) {
        self.id = response.id
        self.title = response.title
        self.organizer = response.organizer
        self.description = response.description ?? ""
        self.date = response.eventDate
        self.location = response.location
        self.latitude = response.latitude
        self.longitude = response.longitude
        self.imageSystemName = response.iconName ?? "calendar"
        self.category = EventCategory(rawValue: response.category.capitalized) ?? .cleanup
        self.participantCount = response.participantCount
        self.maxParticipants = response.maxParticipants
        self.communityId = response.communityId
        self.communityName = response.communityName
        self.distanceKm = response.distanceKm
        self.isRegistered = response.isRegistered ?? false
        self.isPersonal = response.isPersonal ?? false
    }

    init(
        id: UUID = UUID(),
        title: String,
        organizer: String,
        description: String,
        date: Date,
        location: String,
        latitude: Double,
        longitude: Double,
        imageSystemName: String,
        category: EventCategory,
        participantCount: Int,
        maxParticipants: Int,
        communityId: String?,
        communityName: String? = nil,
        distanceKm: Double? = nil,
        isRegistered: Bool = false,
        isPersonal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.organizer = organizer
        self.description = description
        self.date = date
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.imageSystemName = imageSystemName
        self.category = category
        self.participantCount = participantCount
        self.maxParticipants = maxParticipants
        self.communityId = communityId
        self.communityName = communityName
        self.distanceKm = distanceKm
        self.isRegistered = isRegistered
        self.isPersonal = isPersonal
    }
}
