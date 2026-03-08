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
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showAdminDashboard = false
    @State private var showApprovalAlert = false

    var isMember: Bool {
        userSettings.isMember(of: community)
    }

    var isPending: Bool {
        userSettings.isPending(of: community)
    }

    var currentCommunity: Community {
        userSettings.joinedCommunities.first(where: { $0.id == community.id })
            ?? userSettings.communitiesInCity.first(where: { $0.id == community.id })
            ?? community
    }

    var isAdmin: Bool {
        userSettings.isAdmin(of: currentCommunity)
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
                    EventDetailSheetForCommunity(
                        event: event, viewModel: viewModel,
                        userLocation: userSettings.selectedLocation)
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
                        _ = await userSettings.leaveCommunity(community)
                    } else {
                        let result = await userSettings.joinCommunity(community)
                        if result.requiresApproval {
                            showApprovalAlert = true
                        }
                    }
                }
            }
        ) {
            HStack(spacing: theme.spacing.sm) {
                if userSettings.isLoadingCommunities {
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
    private let theme = TrashTheme()

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

// MARK: - CommunityEventCard

private struct CommunityEventCard: View {
    let event: CommunityEvent
    let onTap: () -> Void
    private let theme = TrashTheme()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }

    private var isPast: Bool {
        event.date < Date()
    }

    var body: some View {
        TrashTapArea(action: onTap) {
            VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                HStack(spacing: theme.layout.rowContentSpacing) {
                    ZStack {
                        Circle()
                            .fill(event.category.color.opacity(isPast ? 0.1 : 0.15))
                            .frame(
                                width: theme.components.minimumHitTarget,
                                height: theme.components.minimumHitTarget
                            )
                        TrashIcon(systemName: event.imageSystemName)
                            .font(.system(size: 18))
                            .foregroundColor(
                                isPast ? theme.palette.textSecondary : event.category.color
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TrashPill(
                                title: event.category.rawValue.capitalized,
                                color: isPast ? theme.palette.textSecondary : event.category.color,
                                isSelected: false
                            )

                            if isPast {
                                TrashPill(
                                    title: "Past",
                                    color: theme.semanticWarning,
                                    isSelected: false
                                )
                            }

                            Spacer()

                            if event.isRegistered {
                                TrashIcon(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.semanticSuccess)
                            }
                        }

                        Text(event.title)
                            .font(theme.typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(
                                isPast ? theme.palette.textSecondary : theme.palette.textPrimary
                            )
                            .lineLimit(2)
                    }
                }

                HStack(spacing: theme.layout.rowContentSpacing) {
                    TrashLabel(dateFormatter.string(from: event.date), icon: "calendar")
                    Spacer()
                    TrashLabel(
                        "\(event.participantCount)/\(event.maxParticipants)",
                        icon: "person.2.fill"
                    )
                }
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
            }
            .padding(theme.components.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
            )
        }
        .opacity(isPast ? 0.7 : 1)
    }
}

// MARK: - ViewModel

@MainActor
class CommunityDetailViewModel: ObservableObject {
    @Published var allEvents: [CommunityEvent] = []
    @Published var isLoading = false

    private var eventService: EventService {
        EventService.shared
    }

    var upcomingEvents: [CommunityEvent] {
        allEvents
            .filter { $0.date >= Date() }
            .sorted { $0.date < $1.date }
    }

    var pastEvents: [CommunityEvent] {
        allEvents
            .filter { $0.date < Date() }
            .sorted { $0.date > $1.date }  // Most recent first
    }

    func loadEvents(communityId: String) async {
        isLoading = true
        do {
            let response = try await eventService.getCommunityEvents(communityId: communityId)
            allEvents = response.map { CommunityEvent(from: $0) }
        } catch {
            print("❌ Get community events error: \(error)")
        }
        isLoading = false
    }

    /// Register for an event
    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.registerForEvent(event.id)
            if success {
                if let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                    allEvents[index].isRegistered = true
                    allEvents[index].participantCount += 1
                }
            }
            return success
        } catch {
            print("❌ Register for event error: \(error)")
            return false
        }
    }

    /// Cancel event registration
    func cancelRegistration(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await eventService.cancelEventRegistration(event.id)
            if success {
                if let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                    allEvents[index].isRegistered = false
                    allEvents[index].participantCount = max(
                        0, allEvents[index].participantCount - 1)
                }
            }
            return success
        } catch {
            print("❌ Cancel registration error: \(error)")
            return false
        }
    }

    /// Toggle registration state
    func toggleRegistration(for event: CommunityEvent) async {
        if event.isRegistered {
            _ = await cancelRegistration(event)
        } else {
            _ = await registerForEvent(event)
        }
    }
}

// MARK: - Event Detail Sheet (for Community Detail)

struct EventDetailSheetForCommunity: View {
    let event: CommunityEvent
    @ObservedObject var viewModel: CommunityDetailViewModel
    let userLocation: UserLocation?
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }

    private var currentEvent: CommunityEvent {
        viewModel.allEvents.first(where: { $0.id == event.id }) ?? event
    }

    private var isPast: Bool {
        currentEvent.date < Date()
    }

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                        ZStack {
                            LinearGradient(
                                colors: [currentEvent.category.color.opacity(0.8), currentEvent.category.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 156)

                            VStack(spacing: theme.layout.elementSpacing) {
                                TrashIcon(systemName: currentEvent.imageSystemName)
                                    .font(.system(size: 40))
                                    .trashOnAccentForeground()
                                Text(currentEvent.category.rawValue.capitalized)
                                    .font(theme.typography.subheadline)
                                    .foregroundColor(theme.onAccentForeground.opacity(0.9))

                                if isPast {
                                    TrashPill(
                                        title: "Past Event", color: theme.palette.textPrimary.opacity(0.45),
                                        isSelected: true)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous))
                        .padding(.horizontal, theme.layout.screenInset)

                        VStack(alignment: .leading, spacing: theme.spacing.sm) {
                            Text(currentEvent.title)
                                .font(theme.typography.title)
                                .foregroundColor(theme.palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack {
                                TrashIcon(systemName: "building.2.fill")
                                    .foregroundColor(theme.palette.textSecondary)
                                Text(currentEvent.organizer)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                            .font(theme.typography.subheadline)
                        }
                        .padding(.horizontal, theme.layout.screenInset)

                        VStack(spacing: theme.layout.elementSpacing) {
                            InfoRowForCommunity(
                                icon: "calendar", title: "Date & Time",
                                value: dateFormatter.string(from: currentEvent.date))
                            InfoRowForCommunity(
                                icon: "mappin.circle.fill", title: "Location", value: currentEvent.location
                            )
                            InfoRowForCommunity(
                                icon: "person.2.fill", title: "Participants",
                                value: "\(currentEvent.participantCount) / \(currentEvent.maxParticipants)")
                        }
                        .padding(.horizontal, theme.layout.screenInset)

                        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                            Text("About")
                                .font(theme.typography.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.palette.textPrimary)
                            Text(
                                currentEvent.description.isEmpty
                                    ? "No description available." : currentEvent.description
                            )
                            .font(theme.typography.body)
                            .foregroundColor(theme.palette.textSecondary)
                        }
                        .padding(theme.components.cardPadding)
                        .surfaceCard(cornerRadius: theme.corners.large)
                        .padding(.horizontal, theme.layout.screenInset)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, theme.layout.screenInset)
                    .padding(.bottom, theme.spacing.xxl)
                }
            }
            .trashScreenBackground()
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close", variant: .accent) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isPast {
                    VStack {
                        TrashButton(
                            baseColor: currentEvent.isRegistered
                                ? theme.accents.green
                                : (currentEvent.participantCount >= currentEvent.maxParticipants
                                    ? theme.palette.textSecondary : currentEvent.category.color),
                            cornerRadius: theme.corners.medium,
                            action: {
                                Task {
                                    await viewModel.toggleRegistration(for: currentEvent)
                                }
                            }
                        ) {
                            HStack(spacing: theme.spacing.sm) {
                                TrashIcon(
                                    systemName: currentEvent.isRegistered
                                        ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(currentEvent.isRegistered ? "Registered" : "Register Now")
                            }
                            .font(theme.typography.button)
                            .fontWeight(.semibold)
                            .trashOnAccentForeground()
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(
                            currentEvent.participantCount >= currentEvent.maxParticipants
                                && !currentEvent.isRegistered
                        )
                        .padding(.horizontal, theme.layout.screenInset)
                        .padding(.top, theme.layout.elementSpacing)
                        .padding(.bottom, theme.layout.elementSpacing)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

private struct InfoRowForCommunity: View {
    let icon: String
    let title: String
    let value: String
    private let theme = TrashTheme()

    var body: some View {
        HStack(spacing: theme.layout.rowContentSpacing) {
            TrashIcon(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.accents.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                Text(value)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(theme.components.cardPadding)
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
