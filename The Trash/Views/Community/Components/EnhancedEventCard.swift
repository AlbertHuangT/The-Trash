//
//  EnhancedEventCard.swift
//  The Trash
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
            Group {
                if theme.visualStyle == .ecoPaper {
                    ecoEventCard
                } else {
                    legacyEventCard
                }
            }
        }
    }

    private var legacyEventCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.neuBackground
                    .frame(height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.neuBackground, lineWidth: 3)
                            .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .neuLightShadow, radius: 4, x: -3, y: -3)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .overlay(
                        TrashIcon(systemName: event.imageSystemName)
                            .font(.system(size: 60))
                            .foregroundColor(.neuSecondaryText.opacity(0.3))
                    )

                HStack {
                    Text(event.category.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(event.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.neuBackground)
                        .cornerRadius(8)
                        .shadow(color: .neuDarkShadow, radius: 2, x: 1, y: 1)
                        .shadow(color: .neuLightShadow, radius: 2, x: -1, y: -1)

                    Spacer()

                    if isAlmostFull {
                        HStack(spacing: 4) {
                            TrashIcon(systemName: "flame.fill")
                            Text("Filling Fast")
                        }
                        .font(.caption.bold())
                        .trashOnAccentForeground()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.semanticWarning)
                        .cornerRadius(8)
                    } else if isFull {
                        Text("Full")
                            .font(.caption.bold())
                            .trashOnAccentForeground()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.semanticDanger)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .foregroundColor(.neuText)

                    Spacer()

                    if !distanceText.isEmpty {
                        TrashLabel(distanceText, icon: "location.fill")
                            .font(.caption)
                            .foregroundColor(.neuSecondaryText)
                    }
                }

                HStack(spacing: 16) {
                    TrashLabel(dateFormatter.string(from: event.date), icon: "calendar")
                    Spacer()
                    TrashLabel(event.location, icon: "mappin.and.ellipse")
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)

                Color.neuDivider.frame(height: 1)
                    .padding(.vertical, 4)

                HStack {
                    HStack(spacing: 6) {
                        TrashIcon(systemName: "person.circle.fill")
                            .foregroundColor(.neuSecondaryText)
                        Text(event.organizer)
                            .font(.caption)
                            .foregroundColor(.neuSecondaryText)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        TrashIcon(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(event.participantCount)/\(event.maxParticipants)")
                            .font(.caption.bold())
                    }
                    .foregroundColor(isFull ? .red : .neuAccentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .neumorphicConcave(cornerRadius: 6)

                    if event.isRegistered {
                        TrashIcon(systemName: "checkmark.circle.fill")
                            .foregroundColor(.neuAccentGreen)
                            .font(.title3)
                            .padding(.leading, 8)
                    }
                }
            }
            .padding(16)
            .background(Color.neuBackground)
        }
        .cornerRadius(16)
        .shadow(color: .neuDarkShadow, radius: 8, x: 5, y: 5)
        .shadow(color: .neuLightShadow, radius: 8, x: -4, y: -4)
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
                            .foregroundColor(event.category.color)
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
                                .fill(theme.palette.background.opacity(0.85))
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
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.palette.divider.opacity(0.58))
                    .offset(x: 0, y: 3)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.palette.card)
                    .overlay(
                        PaperTextureView(baseColor: theme.palette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .opacity(0.38)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.88), lineWidth: 1)
                    )
            }
        }
        .shadow(color: theme.shadows.dark.opacity(0.42), radius: 8, x: 0, y: 4)
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
                .fill(theme.palette.card.opacity(0.95))
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
