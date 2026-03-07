//
//  EnhancedEventCard.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import CoreLocation
import SwiftUI

struct EnhancedEventCard: View {
    let event: CommunityEvent
    let userLocation: UserLocation?
    let preciseLocation: CLLocation?
    let onTap: () -> Void

    @State private var imageURL: URL?  // For future image loading
    private let theme = TrashTheme()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }

    private var isAlmostFull: Bool {
        event.participantCount >= Int(Double(event.maxParticipants) * 0.8)
            && event.participantCount < event.maxParticipants
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
        TrashTapArea(action: onTap) {
            ecoEventCard
        }
    }

    private var ecoEventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(theme.typography.headline)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        StampedIcon(
                            systemName: event.imageSystemName, size: 14, weight: .semibold,
                            color: event.category.color)
                        Text(event.category.rawValue.uppercased())
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }

                Spacer()

                if !distanceText.isEmpty {
                    Text(distanceText)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(theme.surfaceBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(theme.palette.divider.opacity(0.72))
                .frame(height: 1)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 9) {
                TrashLabel(dateFormatter.string(from: event.date), icon: "calendar")
                    .font(theme.typography.body)
                    .foregroundColor(theme.palette.textSecondary)
                TrashLabel(event.location, icon: "mappin.and.ellipse")
                    .font(theme.typography.body)
                    .foregroundColor(theme.palette.textSecondary)
                    .lineLimit(1)

                HStack {
                    HStack(spacing: 6) {
                        StampedIcon(
                            systemName: "person.crop.circle", size: 13, weight: .semibold,
                            color: theme.palette.textSecondary)
                        Text(event.organizer)
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        StampedIcon(
                            systemName: "person.2.fill", size: 12, weight: .semibold,
                            color: isFull ? .red : theme.accents.blue)
                        Text("\(event.participantCount)/\(event.maxParticipants)")
                            .font(theme.typography.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(isFull ? .red : theme.accents.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            HStack {
                if isAlmostFull && !isFull {
                    Text("Filling Fast")
                        .font(theme.typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.accents.orange)
                } else if isFull {
                    Text("Event Full")
                        .font(theme.typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textSecondary)
                }

                Spacer()

                ecoJoinTag
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var ecoJoinTag: some View {
        let tagColor =
            event.isRegistered
            ? theme.accents.green
            : (isFull ? theme.palette.textSecondary.opacity(0.7) : theme.accents.green)

        return HStack(spacing: 6) {
            StampedIcon(
                systemName: event.isRegistered ? "checkmark.seal.fill" : "tag.fill",
                size: 12,
                weight: .bold,
                color: theme.onAccentForeground
            )
            Text(event.isRegistered ? "Registered" : (isFull ? "Full" : "Join Event"))
                .font(theme.typography.caption)
                .fontWeight(.bold)
                .foregroundColor(theme.onAccentForeground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tagColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.palette.textPrimary.opacity(0.25), lineWidth: 1)
                )
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(theme.surfaceBackground.opacity(0.98))
                .frame(width: 7, height: 7)
                .offset(x: 8, y: -3)
        }
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(theme.palette.divider.opacity(0.8))
                .frame(width: 1, height: 12)
                .offset(x: 11, y: -12)
        }
    }
}
