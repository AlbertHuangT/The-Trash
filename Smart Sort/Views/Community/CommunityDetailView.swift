//
//  CommunityDetailView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import SwiftUI

// MARK: - CommunityDetailView

struct CommunityDetailView: View {
    let community: Community

    @StateObject private var viewModel = CommunityDetailViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var communityStore = CommunityMembershipStore.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.trashTheme) private var theme
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showAdminDashboard = false
    @State private var showApprovalAlert = false

    var isMember: Bool {
        communityStore.isMember(of: community)
    }

    var isPending: Bool {
        communityStore.isPending(of: community)
    }

    var currentCommunity: Community {
        communityStore.joinedCommunities.first(where: { $0.id == community.id })
            ?? communityStore.communitiesInCity.first(where: { $0.id == community.id })
            ?? community
    }

    var isAdmin: Bool {
        communityStore.isAdmin(of: currentCommunity)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: theme.layout.sectionSpacing) {
                    headerSection
                    descriptionSection
                    if isAdmin {
                        adminSection
                    }
                    statsSection
                    eventsSection
                }
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle(currentCommunity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TrashTextButton(title: "Close", variant: .accent) { dismiss() }
                }
            }
            .task {
                await viewModel.loadEvents(communityId: community.id)
            }
            .sheet(item: $showEventDetail) { event in
                if isAdmin {
                    GrantCreditsView(event: event)
                } else {
                    CommunityEventDetailSheet(
                        event: event,
                        userLocation: userSettings.selectedLocation,
                        resolveCurrentEvent: { selectedEvent in
                            viewModel.allEvents.first(where: { $0.id == selectedEvent.id }) ?? selectedEvent
                        },
                        onToggleRegistration: { selectedEvent in
                            await viewModel.toggleRegistration(for: selectedEvent)
                        }
                    )
                }
            }
            .sheet(isPresented: $showAdminDashboard) {
                CommunityAdminDashboard(community: community)
            }
            .sheet(isPresented: $showApprovalAlert) {
                TrashNoticeSheet(
                    title: "Application Submitted",
                    message:
                        "Your request to join has been submitted. An admin will review it shortly.",
                    onClose: { showApprovalAlert = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accents.blue.opacity(0.65), theme.accents.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)

                TrashIcon(systemName: "person.3.fill")
                    .font(.system(size: 34))
                    .trashOnAccentForeground()
            }
            .shadow(color: theme.accents.blue.opacity(0.3), radius: 10, x: 0, y: 5)

            Text(currentCommunity.name)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)

            HStack(spacing: 6) {
                TrashIcon(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.palette.textSecondary)
                Text(currentCommunity.fullLocation)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .font(theme.typography.subheadline)

            joinButton
        }
        .padding(.vertical, theme.components.cardPadding)
        .padding(.horizontal, theme.components.cardPadding)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: theme.corners.large)
        .padding(.horizontal, theme.layout.screenInset)
    }

    private var joinButton: some View {
        TrashButton(
            baseColor: isPending ? theme.semanticWarning.opacity(0.2) : (isMember ? theme.accents.green.opacity(0.2) : theme.accents.blue),
            cornerRadius: theme.corners.medium,
            action: {
                Task {
                    if isPending {
                        showApprovalAlert = true
                    } else if isMember {
                        _ = await communityStore.leaveCommunity(community)
                    } else {
                        let result = await communityStore.joinCommunity(community)
                        if result.requiresApproval {
                            showApprovalAlert = true
                        }
                    }
                }
            }
        ) {
            HStack(spacing: theme.spacing.sm) {
                if communityStore.isLoadingCommunities {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(isPending ? theme.semanticWarning : (isMember ? theme.accents.green : theme.onAccentForeground))
                } else {
                    TrashIcon(systemName: isPending ? "clock.badge.exclamationmark.fill" : (isMember ? "checkmark.circle.fill" : "plus.circle.fill"))
                }
                Text(isPending ? "Pending Approval" : (isMember ? "Joined" : "Join Community"))
            }
            .font(theme.typography.button)
            .fontWeight(.semibold)
            .foregroundColor(isPending ? theme.semanticWarning : (isMember ? theme.accents.green : theme.onAccentForeground))
            .frame(maxWidth: .infinity)
        }
        .padding(.top, theme.spacing.sm)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            sectionHeader("About")

            Text(
                currentCommunity.description.isEmpty ? "No description available." : currentCommunity.description
            )
            .font(theme.typography.body)
            .foregroundColor(theme.palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.medium)
        .padding(.horizontal, theme.layout.screenInset)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: theme.layout.elementSpacing)],
            spacing: theme.layout.elementSpacing
        ) {
            StatItem(
                value: "\(currentCommunity.memberCount)", label: "Members", icon: "person.2.fill",
                color: theme.accents.blue)

            StatItem(
                value: "\(viewModel.upcomingEvents.count)", label: "Upcoming", icon: "calendar",
                color: theme.accents.green)

            StatItem(
                value: "\(viewModel.pastEvents.count)", label: "Past",
                icon: "clock.arrow.circlepath", color: theme.accents.orange)
        }
        .padding(theme.components.cardPadding)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: theme.corners.medium)
        .padding(.horizontal, theme.layout.screenInset)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(spacing: theme.layout.sectionSpacing) {
            // Upcoming Events
            if !viewModel.upcomingEvents.isEmpty {
                eventListSection(
                    title: "Upcoming Events", events: viewModel.upcomingEvents, iconColor: theme.accents.green)
            }

            // Past Events
            if !viewModel.pastEvents.isEmpty {
                eventListSection(
                    title: "Past Events", events: viewModel.pastEvents, iconColor: theme.accents.orange)
            }

            // Empty State
            if viewModel.upcomingEvents.isEmpty && viewModel.pastEvents.isEmpty
                && !viewModel.isLoading
            {
                emptyEventsView
            }

            // Loading State
            if viewModel.isLoading {
                loadingView
            }
        }
        .padding(.top, theme.spacing.xs)
    }

    private func eventListSection(title: String, events: [CommunityEvent], iconColor: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            sectionHeader(title)
            .padding(.horizontal, theme.layout.screenInset)

            LazyVStack(spacing: theme.spacing.sm + 4) {
                ForEach(events) { event in
                    EnhancedEventCard(
                        event: event,
                        userLocation: userSettings.selectedLocation,
                        preciseLocation: userSettings.preciseLocation
                    ) {
                        showEventDetail = event
                    }
                }
            }
            .padding(.horizontal, theme.layout.screenInset)
        }
    }

    private var emptyEventsView: some View {
        VStack(spacing: theme.spacing.md) {
            TrashIcon(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(theme.palette.textSecondary)

            Text("No Events Yet")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            Text("This community hasn't hosted any events yet.")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: theme.corners.medium)
        .padding(.horizontal, theme.layout.screenInset)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading events...")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(.vertical, 40)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(theme.palette.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Admin Section

    private var adminSection: some View {
        TrashButton(
            baseColor: theme.semanticWarning.opacity(0.18), cornerRadius: theme.corners.medium,
            action: { showAdminDashboard = true }
        ) {
            HStack(spacing: 12) {
                TrashIcon(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.semanticWarning)

                Text("Admin Dashboard")
                    .font(theme.typography.button)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.palette.textPrimary)

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
        }
        .padding(.horizontal, theme.layout.screenInset)
    }
}

// MARK: - StatItem

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @Environment(\.trashTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            HStack(spacing: 4) {
                TrashIcon(systemName: icon)
                    .font(theme.typography.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
            }
            Text(label)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 68)
        .padding(.vertical, theme.spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.palette.card.opacity(0.32))
        )
    }
}

#Preview {
    NavigationStack {
        CommunityDetailView(
            community: Community(
                id: "test-id",
                name: "NYC Trash Cleanup",
                city: "New York",
                state: "NY",
                description:
                    "A community dedicated to cleaning up New York City streets and parks. We organize regular cleanup events and educational workshops.",
                memberCount: 156,
                latitude: 40.7128,
                longitude: -74.0060
            ))
    }
}
