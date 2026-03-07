import CoreLocation
import SwiftUI
// MARK: - Main View (EventsView)

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    private let theme = TrashTheme()
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showSortMenu = false
    // showAccountSheet managed by ContentView via environment
    @State private var showCreateEventSheet = false
    @State private var showLocationPicker = false  // Added for location picker
    @State private var isMapView = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            categoryFilter

            if !viewModel.hasLocation {
                noLocationView
            } else if viewModel.isLoading {
                loadingView
            } else if viewModel.events.isEmpty {
                emptyState
            } else {
                if isMapView {
                    EventsMapView(
                        events: viewModel.events,
                        userSettings: userSettings,
                        onEventSelected: { event in
                            showEventDetail = event
                        }
                    )
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
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
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await viewModel.loadEvents()
                    }
                    .transition(.opacity)
                }
            }
        }
        .sheet(item: $showEventDetail) { event in
            EventDetailSheet(
                event: event, viewModel: viewModel, userLocation: userSettings.selectedLocation)
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateEventFormSheet(isPresented: $showCreateEventSheet, userSettings: userSettings) {
                // 刷新活动列表
                Task { await viewModel.loadEvents() }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker)
        }
        .sheet(isPresented: $showSortMenu) {
            SortOptionSheet(selection: $viewModel.sortOption, isPresented: $showSortMenu)
                .presentationDetents([.fraction(0.42), .medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            viewModel.requestPreciseLocation()

            if viewModel.events.isEmpty {
                await viewModel.loadEvents()
            }
        }
        .onChange(of: appRouter.activeSheet) { sheet in
            guard sheet == .createEvent, !authVM.isAnonymous, viewModel.hasLocation else { return }
            showCreateEventSheet = true
            appRouter.dismissSheet()
        }
        .onChange(of: viewModel.selectedCategory) { _ in
            Task { await viewModel.loadEvents() }
        }
        .onChange(of: viewModel.sortOption) { _ in
            Task { await viewModel.loadEvents() }
        }
        .onChange(of: viewModel.showOnlyJoinedCommunities) { _ in
            Task { await viewModel.loadEvents() }
        }
        .onChange(of: userSettings.preciseLocation) { newLocation in
            // 🚀 当精确GPS位置更新时，重新按距离排序
            if newLocation != nil {
                viewModel.sortEventsByPreciseDistance()
            }
        }
        .onChange(of: userSettings.locationPermissionStatus) { status in
            // 🚀 当用户授予位置权限时，请求精确位置
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                viewModel.requestPreciseLocation()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.accents.blue)
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 位置显示
                if let location = userSettings.selectedLocation {
                    TrashPill(
                        title: location.city,
                        icon: "location.fill",
                        color: theme.accents.blue
                    ) {
                        showLocationPicker = true
                    }
                } else {
                    TrashPill(
                        title: "Select Location",
                        icon: "location.slash",
                        color: theme.palette.textSecondary
                    ) {
                        showLocationPicker = true
                    }
                }

                // Map/List Toggle
                TrashIconButton(
                    icon: isMapView ? "map.fill" : "list.bullet",
                    isActive: true,
                    activeColor: theme.accents.blue
                ) {
                    withAnimation {
                        isMapView.toggle()
                    }
                }

                // 仅显示已加入社区 Toggle
                TrashPill(
                    title: viewModel.showOnlyJoinedCommunities ? "Joined" : "All",
                    icon: viewModel.showOnlyJoinedCommunities ? "person.3.fill" : "globe",
                    color: theme.accents.green,
                    isSelected: viewModel.showOnlyJoinedCommunities
                ) {
                    viewModel.showOnlyJoinedCommunities.toggle()
                }

                // 排序按钮
                TrashPill(
                    title: viewModel.sortOption.rawValue,
                    icon: "arrow.up.arrow.down",
                    color: theme.accents.blue,
                    isSelected: viewModel.sortOption != .distance
                ) {
                    showSortMenu = true
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Color.clear)
        .animation(.none, value: viewModel.sortOption)  // 🚀 禁用整个控制栏的布局动画
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    TrashPill(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        color: .gray,
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        viewModel.selectedCategory = nil
                    }
                    .id("all")

                    ForEach(CommunityEvent.EventCategory.allCases, id: \.self) { category in
                        TrashPill(
                            title: category.rawValue,
                            icon: category.icon,
                            color: category.color,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = category
                        }
                        .id(category.rawValue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color.clear)
            // 🚀 优化：选中时自动滚动到选中项
            .onChange(of: viewModel.selectedCategory) { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let category = newValue {
                        proxy.scrollTo(category.rawValue, anchor: .center)
                    } else {
                        proxy.scrollTo("all", anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - No Location View
    private var noLocationView: some View {
        VStack(spacing: 20) {
            Spacer()

            EmptyStateView(
                icon: "location.slash.fill",
                title: "Set Your Location",
                subtitle: "Select a location in Account settings to see nearby events."
            )

            TrashButton(
                baseColor: theme.accents.blue, cornerRadius: 20,
                action: { showLocationPicker = true }
            ) {
                HStack {
                    TrashIcon(systemName: "location.fill")
                    Text("Select Location")
                }
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .trashOnAccentForeground()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            EmptyStateView(
                icon: "calendar.badge.exclamationmark",
                title: "No Events Found",
                subtitle: viewModel.showOnlyJoinedCommunities
                    ? "Try showing all events or join more communities."
                    : "Check back later for new events."
            )

            if viewModel.showOnlyJoinedCommunities {
                TrashTextButton(title: "Show All Events", variant: .accent) {
                    viewModel.showOnlyJoinedCommunities = false
                }
            }
            Spacer()
        }
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: CommunityEvent
    @ObservedObject var viewModel: EventsViewModel
    let userLocation: UserLocation?
    @ObservedObject private var userSettings = UserSettings.shared  // 🚀 新增：获取精确位置
    @Environment(\.dismiss) var dismiss
    private let theme = TrashTheme()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }

    private var currentEvent: CommunityEvent {
        viewModel.events.first(where: { $0.id == event.id }) ?? event
    }

    private var distanceText: String {
        let dist = event.distance(from: userLocation, preciseLocation: userSettings.preciseLocation)
        if dist <= 0 { return "Location unknown" }
        if dist < 1 {
            return String(format: "%.0f meters away", dist * 1000)
        } else {
            return String(format: "%.1f km away", dist)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header — neumorphic concave
                        ZStack {
                            Color.clear
                                .frame(height: 180)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(theme.surfaceBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                        )
                                )

                            VStack(spacing: 12) {
                                TrashIcon(systemName: event.imageSystemName)
                                    .font(.system(size: 50))
                                    .foregroundColor(event.category.color)
                                Text(event.category.rawValue)
                                    .font(theme.typography.headline)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                        }
                        .cornerRadius(20)
                        .padding(.horizontal)

                        // Title & Organizer
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

                        // Info Cards
                        VStack(spacing: 12) {
                            InfoRow(
                                icon: "calendar", title: "Date & Time",
                                value: dateFormatter.string(from: event.date))
                            InfoRow(
                                icon: "mappin.circle.fill", title: "Location", value: event.location
                            )
                            InfoRow(icon: "location.fill", title: "Distance", value: distanceText)
                            InfoRow(
                                icon: "person.2.fill", title: "Participants",
                                value: "\(event.participantCount) / \(event.maxParticipants)")
                        }
                        .padding(.horizontal)

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(theme.typography.headline)
                                .foregroundColor(theme.palette.textPrimary)
                            Text(event.description)
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
        .presentationBackground(theme.appBackground)
    }
}

struct InfoRow: View {
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
        )
    }
}

private struct SortOptionSheet: View {
    @Binding var selection: EventSortOption
    @Binding var isPresented: Bool
    private let theme = TrashTheme()

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(EventSortOption.allCases, id: \.self) { option in
                            TrashTapArea(action: {
                                selection = option
                                isPresented = false
                            }) {
                                HStack(spacing: 12) {
                                    TrashIcon(systemName: option.icon)
                                        .font(theme.typography.subheadline)
                                        .foregroundColor(theme.accents.blue)
                                        .frame(width: 20)

                                    Text(option.rawValue)
                                        .font(theme.typography.subheadline)
                                        .foregroundColor(theme.palette.textPrimary)

                                    Spacer()

                                    if selection == option {
                                        TrashIcon(systemName: "checkmark.circle.fill")
                                            .foregroundColor(theme.accents.green)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(theme.surfaceBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Sort Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
