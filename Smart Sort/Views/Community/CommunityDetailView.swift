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

    var isAdmin: Bool {
        community.isAdmin
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    descriptionSection
                    if isAdmin {
                        adminSection
                    }
                    statsSection
                    eventsSection
                }
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle(community.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accents.blue.opacity(0.65), theme.accents.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                TrashIcon(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .trashOnAccentForeground()
            }
            .shadow(color: theme.accents.blue.opacity(0.3), radius: 10, x: 0, y: 5)

            Text(community.name)
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)

            HStack(spacing: 6) {
                TrashIcon(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.palette.textSecondary)
                Text(community.fullLocation)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .font(theme.typography.subheadline)

            joinButton
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 18)
        .padding(.horizontal, 16)
    }

    private var joinButton: some View {
        TrashButton(
            baseColor: isMember ? theme.accents.green.opacity(0.2) : theme.accents.blue,
            cornerRadius: 14,
            action: {
                Task {
                    if isMember {
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
            HStack {
                if userSettings.isLoadingCommunities {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(isMember ? theme.accents.green : theme.onAccentForeground)
                } else {
                    TrashIcon(systemName: isMember ? "checkmark.circle.fill" : "plus.circle.fill")
                }
                Text(isMember ? "Joined" : "Join Community")
            }
            .font(theme.typography.headline)
            .foregroundColor(isMember ? theme.accents.green : theme.onAccentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 40)
        .padding(.top, 8)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("About")

            Text(
                community.description.isEmpty ? "No description available." : community.description
            )
            .font(theme.typography.body)
            .foregroundColor(theme.palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surfaceCard(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(
                value: "\(community.memberCount)", label: "Members", icon: "person.2.fill",
                color: theme.accents.blue)

            Divider()
                .frame(height: 40)

            StatItem(
                value: "\(viewModel.upcomingEvents.count)", label: "Upcoming", icon: "calendar",
                color: theme.accents.green)

            Divider()
                .frame(height: 40)

            StatItem(
                value: "\(viewModel.pastEvents.count)", label: "Past",
                icon: "clock.arrow.circlepath", color: theme.accents.orange)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .surfaceCard(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(spacing: 16) {
            // Upcoming Events
            if !viewModel.upcomingEvents.isEmpty {
                eventListSection(
                    title: "Upcoming Events", events: viewModel.upcomingEvents, iconColor: .green)
            }

            // Past Events
            if !viewModel.pastEvents.isEmpty {
                eventListSection(
                    title: "Past Events", events: viewModel.pastEvents, iconColor: .orange)
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
        .padding(.top, 8)
    }

    private func eventListSection(title: String, events: [CommunityEvent], iconColor: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title)
            .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
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
            .padding(.horizontal, 16)
        }
    }

    private var emptyEventsView: some View {
        VStack(spacing: 16) {
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
        .surfaceCard(cornerRadius: 16)
        .padding(.horizontal, 16)
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
            baseColor: theme.semanticWarning.opacity(0.18), cornerRadius: 16,
            action: { showAdminDashboard = true }
        ) {
            HStack(spacing: 12) {
                TrashIcon(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(theme.semanticWarning)

                Text("Admin Dashboard")
                    .font(theme.typography.headline)
                    .foregroundColor(theme.palette.textPrimary)

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                TrashIcon(systemName: icon)
                    .font(theme.typography.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(theme.typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
            }
            Text(label)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Category Icon
                    ZStack {
                        Circle()
                            .fill(event.category.color.opacity(isPast ? 0.1 : 0.15))
                            .frame(width: 44, height: 44)
                        TrashIcon(systemName: event.imageSystemName)
                            .font(.system(size: 18))
                            .foregroundColor(isPast ? .secondary : event.category.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.category.rawValue)
                                .font(theme.typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isPast ? .secondary : theme.palette.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    (isPast ? Color.gray : event.category.color).opacity(0.15)
                                )
                                .cornerRadius(6)

                            if isPast {
                                Text("Past")
                                    .font(.caption2)
                                    .foregroundColor(theme.semanticWarning)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.semanticWarning.opacity(0.14))
                                    .cornerRadius(4)
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
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 16) {
                    TrashLabel(dateFormatter.string(from: event.date), icon: "calendar")
                    Spacer()
                    TrashLabel(
                        "\(event.participantCount)/\(event.maxParticipants)", icon: "person.2.fill")
                }
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
            }
            .padding(14)
            .surfaceCard(cornerRadius: 14)
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

    /// 报名活动
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

    /// 取消报名
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

    /// 切换报名状态
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
        event.date < Date()
    }

    var body: some View {
        NavigationView {
            ZStack {

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack {
                            LinearGradient(
                                colors: [event.category.color.opacity(0.8), event.category.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 180)

                            VStack(spacing: 12) {
                                TrashIcon(systemName: event.imageSystemName)
                                    .font(.system(size: 50))
                                    .trashOnAccentForeground()
                                Text(event.category.rawValue)
                                    .font(theme.typography.headline)
                                    .foregroundColor(theme.onAccentForeground.opacity(0.9))

                                if isPast {
                                    TrashPill(
                                        title: "Past Event", color: .black.opacity(0.45),
                                        isSelected: true)
                                }
                            }
                        }
                        .cornerRadius(20)
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.title)
                                .font(theme.typography.title)
                                .foregroundColor(theme.palette.textPrimary)

                            HStack {
                                TrashIcon(systemName: "building.2.fill")
                                    .foregroundColor(theme.palette.textSecondary)
                                Text(event.organizer)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                            .font(theme.typography.subheadline)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            InfoRowForCommunity(
                                icon: "calendar", title: "Date & Time",
                                value: dateFormatter.string(from: event.date))
                            InfoRowForCommunity(
                                icon: "mappin.circle.fill", title: "Location", value: event.location
                            )
                            InfoRowForCommunity(
                                icon: "person.2.fill", title: "Participants",
                                value: "\(event.participantCount) / \(event.maxParticipants)")
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(theme.typography.headline)
                                .foregroundColor(theme.palette.textPrimary)
                            Text(
                                event.description.isEmpty
                                    ? "No description available." : event.description
                            )
                            .font(theme.typography.body)
                            .foregroundColor(theme.palette.textSecondary)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
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
                                    ? .gray : event.category.color),
                            cornerRadius: 14,
                            action: {
                                Task {
                                    await viewModel.toggleRegistration(for: event)
                                }
                            }
                        ) {
                            HStack {
                                TrashIcon(
                                    systemName: currentEvent.isRegistered
                                        ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(currentEvent.isRegistered ? "Registered" : "Register Now")
                            }
                            .font(theme.typography.headline)
                            .trashOnAccentForeground()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .disabled(
                            currentEvent.participantCount >= currentEvent.maxParticipants
                                && !currentEvent.isRegistered
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                        .background(theme.appBackground)
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
        HStack(spacing: 14) {
            TrashIcon(systemName: icon)
                .font(.title3)
                .foregroundColor(theme.accents.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                Text(value)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
            }

            Spacer()
        }
        .padding(12)
        .surfaceCard(cornerRadius: 12)
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
