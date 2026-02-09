//
//  EnhancedEventCard.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import CoreLocation
import Combine

struct EnhancedEventCard: View {
    let event: CommunityEvent
    let userLocation: UserLocation?
    let preciseLocation: CLLocation?
    let onTap: () -> Void
    
    @State private var imageURL: URL? // For future image loading
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }
    
    private var isAlmostFull: Bool {
        event.participantCount >= Int(Double(event.maxParticipants) * 0.8) && event.participantCount < event.maxParticipants
    }
    
    private var isFull: Bool {
        event.participantCount >= event.maxParticipants
    }
    
    private var distanceText: String {
        let dist = event.distance(from: userLocation, preciseLocation: preciseLocation)
        if dist <= 0 { return "" }
        if dist < 1 {
            return String(format: "%.0f m", dist * 1000)
        } else {
            return String(format: "%.1f km", dist)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header Image / Gradient
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [event.category.color.opacity(0.8), event.category.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: event.imageSystemName)
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    
                    // Badges
                    HStack {
                        Text(event.category.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(event.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        
                        Spacer()
                        
                        if isAlmostFull {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("Filling Fast")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        } else if isFull {
                            Text("Full")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(12)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 10) {
                    // Title & Distance
                    HStack(alignment: .top) {
                        Text(event.title)
                            .font(.title3.bold())
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if !distanceText.isEmpty {
                            Label(distanceText, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Info Rows
                    HStack(spacing: 16) {
                        Label(dateFormatter.string(from: event.date), systemImage: "calendar")
                        Spacer()
                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Footer
                    HStack {
                        // Organizer
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.secondary)
                            Text(event.organizer)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Participants
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(event.participantCount)/\(event.maxParticipants)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(isFull ? .red : .blue)
                        
                        if event.isRegistered {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                                .padding(.leading, 8)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
