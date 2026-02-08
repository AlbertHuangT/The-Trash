//
//  CommunityDetailView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine

// MARK: - CommunityDetailView

struct CommunityDetailView: View {
    let community: Community
    
    @StateObject private var viewModel = CommunityDetailViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.dismiss) var dismiss
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showAdminDashboard = false
    @State private var showApprovalAlert = false

    var isMember: Bool {
        userSettings.isMember(of: community)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Description
                    descriptionSection
                    
                    // Stats
                    statsSection
                    
                    // Admin Section
                    if community.isAdmin {
                        adminSection
                    }

                    // Events
                    eventsSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(community.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await viewModel.loadEvents(communityId: community.id)
            }
            .sheet(item: $showEventDetail) { event in
                EventDetailSheetForCommunity(event: event, viewModel: viewModel, userLocation: userSettings.selectedLocation)
            }
            .sheet(isPresented: $showAdminDashboard) {
                CommunityAdminDashboard(community: community)
            }
            .alert("Application Submitted", isPresented: $showApprovalAlert) {
                Button("OK") {}
            } message: {
                Text("Your request to join has been submitted. An admin will review it shortly.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(.regularMaterial)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Community Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.6), Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Community Name
            Text(community.name)
                .font(.title2.bold())
            
            // Location
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.secondary)
                Text(community.fullLocation)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            // Join/Leave Button
            joinButton
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    private var joinButton: some View {
        Button(action: {
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
        }) {
            HStack {
                if userSettings.isLoadingCommunities {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(isMember ? .green : .white)
                } else {
                    Image(systemName: isMember ? "checkmark.circle.fill" : "plus.circle.fill")
                }
                Text(isMember ? "Joined" : "Join Community")
            }
            .font(.headline)
            .foregroundColor(isMember ? .green : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isMember ? Color.green.opacity(0.15) : Color.cyan)
            .cornerRadius(14)
        }
        .padding(.horizontal, 40)
        .padding(.top, 8)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
            
            Text(community.description.isEmpty ? "No description available." : community.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(community.memberCount)", label: "Members", icon: "person.2.fill", color: .cyan)
            
            Divider()
                .frame(height: 40)
            
            StatItem(value: "\(viewModel.upcomingEvents.count)", label: "Upcoming", icon: "calendar", color: .green)
            
            Divider()
                .frame(height: 40)
            
            StatItem(value: "\(viewModel.pastEvents.count)", label: "Past", icon: "clock.arrow.circlepath", color: .orange)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Events Section
    
    private var eventsSection: some View {
        VStack(spacing: 16) {
            // Upcoming Events
            if !viewModel.upcomingEvents.isEmpty {
                eventListSection(title: "Upcoming Events", events: viewModel.upcomingEvents, iconColor: .green)
            }
            
            // Past Events
            if !viewModel.pastEvents.isEmpty {
                eventListSection(title: "Past Events", events: viewModel.pastEvents, iconColor: .orange)
            }
            
            // Empty State
            if viewModel.upcomingEvents.isEmpty && viewModel.pastEvents.isEmpty && !viewModel.isLoading {
                emptyEventsView
            }
            
            // Loading State
            if viewModel.isLoading {
                loadingView
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }
    
    private func eventListSection(title: String, events: [CommunityEvent], iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(events) { event in
                    CommunityEventCard(event: event) {
                        showEventDetail = event
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var emptyEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Events Yet")
                .font(.headline)
            
            Text("This community hasn't hosted any events yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Admin Section

    private var adminSection: some View {
        Button(action: { showAdminDashboard = true }) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                Text("Admin Dashboard")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
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
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.title3.bold())
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CommunityEventCard

private struct CommunityEventCard: View {
    let event: CommunityEvent
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }
    
    private var isPast: Bool {
        event.date < Date()
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    // Category Icon
                    ZStack {
                        Circle()
                            .fill(event.category.color.opacity(isPast ? 0.1 : 0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: event.imageSystemName)
                            .font(.system(size: 18))
                            .foregroundColor(isPast ? .secondary : event.category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.category.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(isPast ? .secondary : event.category.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((isPast ? Color.gray : event.category.color).opacity(0.1))
                                .cornerRadius(6)
                            
                            if isPast {
                                Text("Past")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            if event.isRegistered {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text(event.title)
                            .font(.subheadline.bold())
                            .foregroundColor(isPast ? .secondary : .primary)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 16) {
                    Label(dateFormatter.string(from: event.date), systemImage: "calendar")
                    Spacer()
                    Label("\(event.participantCount)/\(event.maxParticipants)", systemImage: "person.2.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .opacity(isPast ? 0.7 : 1)
    }
}

// MARK: - ViewModel

@MainActor
class CommunityDetailViewModel: ObservableObject {
    @Published var allEvents: [CommunityEvent] = []
    @Published var isLoading = false
    
    private var communityService: CommunityService {
        CommunityService.shared
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
        let response = await communityService.getCommunityEvents(communityId: communityId)
        allEvents = response.map { CommunityEvent(from: $0) }
        isLoading = false
    }
    
    /// 报名活动
    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        let success = await communityService.registerForEvent(event.id)
        if success {
            if let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                allEvents[index].isRegistered = true
                allEvents[index].participantCount += 1
            }
        }
        return success
    }
    
    /// 取消报名
    func cancelRegistration(_ event: CommunityEvent) async -> Bool {
        let success = await communityService.cancelEventRegistration(event.id)
        if success {
            if let index = allEvents.firstIndex(where: { $0.id == event.id }) {
                allEvents[index].isRegistered = false
                allEvents[index].participantCount = max(0, allEvents[index].participantCount - 1)
            }
        }
        return success
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Image
                    ZStack {
                        LinearGradient(
                            colors: [event.category.color.opacity(0.8), event.category.color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 180)
                        
                        VStack(spacing: 12) {
                            Image(systemName: event.imageSystemName)
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            Text(event.category.rawValue)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            if isPast {
                                Text("Past Event")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Title & Organizer
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.title2.bold())
                        
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.secondary)
                            Text(event.organizer)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)
                    
                    // Info Cards
                    VStack(spacing: 12) {
                        InfoRowForCommunity(icon: "calendar", title: "Date & Time", value: dateFormatter.string(from: event.date))
                        InfoRowForCommunity(icon: "mappin.circle.fill", title: "Location", value: event.location)
                        InfoRowForCommunity(icon: "person.2.fill", title: "Participants", value: "\(event.participantCount) / \(event.maxParticipants)")
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(event.description.isEmpty ? "No description available." : event.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isPast {
                    VStack {
                        Button(action: {
                            Task {
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(currentEvent.isRegistered ? .warning : .success)
                                await viewModel.toggleRegistration(for: event)
                            }
                        }) {
                            HStack {
                                Image(systemName: currentEvent.isRegistered ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(currentEvent.isRegistered ? "Registered" : "Register Now")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                currentEvent.isRegistered ?
                                Color.green :
                                (currentEvent.participantCount >= currentEvent.maxParticipants ? Color.gray : event.category.color)
                            )
                            .cornerRadius(14)
                        }
                        .disabled(currentEvent.participantCount >= currentEvent.maxParticipants && !currentEvent.isRegistered)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
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
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        CommunityDetailView(community: Community(
            id: "test-id",
            name: "NYC Trash Cleanup",
            city: "New York",
            state: "NY",
            description: "A community dedicated to cleaning up New York City streets and parks. We organize regular cleanup events and educational workshops.",
            memberCount: 156,
            latitude: 40.7128,
            longitude: -74.0060
        ))
    }
}
