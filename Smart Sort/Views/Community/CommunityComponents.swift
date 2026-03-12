//
//  CommunityComponents.swift
//  Smart Sort
//

import SwiftUI

// MARK: - Location Row View
struct LocationRowView: View {
    let location: UserLocation
    let onSelect: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TrashTapArea(action: onSelect) {
            HStack(spacing: theme.layout.rowContentSpacing) {
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .frame(
                        width: theme.components.minimumHitTarget,
                        height: theme.components.minimumHitTarget
                    )
                    .overlay(
                        TrashIcon(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accents.blue)
                    )

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(location.city)
                        .trashTextRole(.subheadline, compact: true)
                    Text(location.state)
                        .trashTextRole(.caption, compact: true)
                }

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.vertical, theme.layout.elementSpacing)
            .frame(minHeight: theme.components.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: Community
    var onCreateEvent: (() -> Void)? = nil
    @ObservedObject private var communityStore = CommunityMembershipStore.shared
    @State private var showDetail = false
    @State private var showAdminDashboard = false
    @Environment(\.trashTheme) private var theme

    var isMember: Bool {
        communityStore.isMember(of: community)
    }

    var isPending: Bool {
        communityStore.isPending(of: community)
    }

    var isAdmin: Bool {
        communityStore.isAdmin(of: community)
    }

    var body: some View {
        TrashTapArea(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                        .frame(height: 112)
                        .overlay(
                            TrashIcon(systemName: "person.3.fill")
                                .font(.system(size: 48))
                                .foregroundColor(theme.palette.textSecondary.opacity(0.25))
                        )

                    HStack {
                        Spacer()
                        statusBadge
                    }
                    .padding(12)
                }

                VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                    HStack(alignment: .top) {
                        Text(community.name)
                            .trashTextRole(.headline)
                            .lineLimit(2)

                        Spacer()

                        HStack(spacing: 4) {
                            TrashIcon(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(community.memberCount)")
                                .font(theme.typography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.surfaceBackground)
                        )
                    }

                    TrashLabel(community.fullLocation, icon: "mappin.and.ellipse", iconColor: theme.palette.textSecondary)
                        .trashTextRole(.caption, color: theme.palette.textSecondary, compact: true)

                    if !community.description.isEmpty {
                        Text(community.description)
                            .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isAdmin {
                        theme.palette.divider.frame(height: 1)
                            .padding(.vertical, theme.spacing.xs)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: theme.layout.elementSpacing) {
                                adminActionButtons
                            }

                            VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                                adminActionButtons
                            }
                        }
                    }
                }
                .padding(theme.components.cardPadding)
            }
            .surfaceCard(cornerRadius: theme.corners.medium)
        }
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }

    @ViewBuilder
    private func pillBadge(icon: String, text: String, foreground: Color) -> some View {
        TrashPill(title: text, icon: icon, color: foreground, isSelected: false)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isAdmin {
            pillBadge(icon: "gearshape.fill", text: "Admin", foreground: theme.semanticWarning)
        } else if isPending {
            pillBadge(icon: "clock.badge.exclamationmark.fill", text: "Pending", foreground: theme.semanticWarning)
        } else if isMember {
            pillBadge(icon: "checkmark.circle.fill", text: "Joined", foreground: theme.accents.green)
        }
    }

    @ViewBuilder
    private var adminActionButtons: some View {
        if let onCreateEvent = onCreateEvent {
            TrashPill(
                title: "Event",
                icon: "plus.circle.fill",
                color: theme.accents.green,
                isSelected: true,
                action: onCreateEvent
            )
        }

        TrashPill(
            title: "Manage",
            icon: "gearshape.fill",
            color: theme.semanticWarning,
            isSelected: false,
            action: { showAdminDashboard = true }
        )
    }
}
