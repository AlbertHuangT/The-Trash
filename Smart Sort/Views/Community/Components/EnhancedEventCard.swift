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
    @Environment(\.trashTheme) private var theme

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
            HStack(alignment: .top, spacing: theme.spacing.sm) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(event.title)
                        .trashTextRole(.headline)
                        .lineLimit(2)

                    TrashPill(
                        title: event.category.rawValue,
                        icon: event.imageSystemName,
                        color: event.category.color,
                        isSelected: false
                    )
                }

                Spacer()

                if !distanceText.isEmpty {
                    Text(distanceText)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, theme.layout.compactControlHorizontalInset)
                        .frame(minHeight: 32)
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
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.top, theme.components.cardPadding)
            .padding(.bottom, theme.spacing.sm)

            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(theme.palette.divider.opacity(0.72))
                .frame(height: 1)
                .padding(.horizontal, theme.components.cardPadding)

            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                TrashLabel(dateFormatter.string(from: event.date), icon: "calendar")
                    .trashTextRole(.caption, color: theme.palette.textSecondary, compact: true)
                TrashLabel(event.location, icon: "mappin.and.ellipse")
                    .trashTextRole(.caption, color: theme.palette.textSecondary, compact: true)
                    .lineLimit(1)
            }
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.top, theme.spacing.sm)

            HStack {
                TrashPill(
                    title: "\(event.participantCount)/\(event.maxParticipants)",
                    icon: "person.2.fill",
                    color: isFull ? theme.semanticDanger : theme.accents.blue,
                    isSelected: false
                )

                Spacer()

                ecoJoinTag
            }
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.top, theme.layout.elementSpacing)
            .padding(.bottom, theme.components.cardPadding)
        }
        .background {
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.palette.divider, lineWidth: 1)
                )
        }
        .shadow(color: theme.cardShadow, radius: 8, x: 0, y: 3)
    }

    private var ecoJoinTag: some View {
        let tagColor =
            event.isRegistered
            ? theme.accents.green
            : (isFull ? theme.palette.textSecondary.opacity(0.7) : theme.accents.green)

        return HStack(spacing: theme.spacing.sm) {
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
        .padding(.horizontal, theme.layout.compactControlHorizontalInset)
        .frame(minHeight: theme.components.compactControlHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                .fill(tagColor)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                        .stroke(theme.palette.textPrimary.opacity(0.25), lineWidth: 1)
                )
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(theme.surfaceBackground.opacity(0.98))
                .frame(width: 8, height: 8)
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
