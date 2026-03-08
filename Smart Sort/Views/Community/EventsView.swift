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
    @State private var showSecondaryControls = false

    var body: some View {
        VStack(spacing: 0) {
            controlBar

            if showSecondaryControls {
                secondaryControls
            }

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
                        LazyVStack(spacing: theme.spacing.md) {
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
                        .padding(.horizontal, theme.layout.screenInset)
                        .padding(.top, theme.layout.elementSpacing)
                        .padding(.bottom, theme.layout.sectionSpacing)
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
                // Refresh the event list
                Task { await viewModel.loadEvents() }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker)
        }
        .sheet(isPresented: $showSortMenu) {
            SortOptionSheet(selection: $viewModel.sortOption, isPresented: $showSortMenu)
                .presentationDetents([.medium])
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
            // Re-sort by distance when precise GPS location updates
            if newLocation != nil {
                viewModel.sortEventsByPreciseDistance()
            }
        }
        .onChange(of: userSettings.locationPermissionStatus) { status in
            // Request a precise location after permission is granted
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                viewModel.requestPreciseLocation()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: theme.spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(theme.accents.blue)
            Text("Loading events...")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        HStack(spacing: theme.layout.elementSpacing) {
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: theme.spacing.xs + 2) {
                    TrashIcon(
                        systemName: userSettings.selectedLocation == nil
                            ? "location.slash" : "location.fill"
                    )
                    .foregroundColor(theme.accents.blue)

                    Text(userSettings.selectedLocation?.displayName ?? "Select Location")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    TrashIcon(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.palette.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: theme.components.minimumHitTarget, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(theme.animations.standard) {
                    showSecondaryControls.toggle()
                }
            } label: {
                HStack(spacing: theme.spacing.xs) {
                    TrashIcon(systemName: "slider.horizontal.3")
                    Text(showSecondaryControls ? "Hide" : "Filters")
                }
                .font(theme.typography.caption.weight(.semibold))
                .foregroundColor(theme.accents.blue)
                .frame(minWidth: theme.components.minimumHitTarget, minHeight: theme.components.minimumHitTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.top, theme.layout.elementSpacing)
        .padding(.bottom, theme.spacing.xs)
        .animation(.none, value: viewModel.sortOption)  // Disable layout animation for the control bar
    }

    private var secondaryControls: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm) {
                    TrashIconButton(
                        icon: isMapView ? "map.fill" : "list.bullet",
                        isActive: true,
                        activeColor: theme.accents.blue
                    ) {
                        withAnimation {
                            isMapView.toggle()
                        }
                    }

                    TrashPill(
                        title: viewModel.showOnlyJoinedCommunities ? "Joined" : "All",
                        icon: viewModel.showOnlyJoinedCommunities ? "person.3.fill" : "globe",
                        color: theme.accents.green,
                        isSelected: viewModel.showOnlyJoinedCommunities
                    ) {
                        viewModel.showOnlyJoinedCommunities.toggle()
                    }

                    TrashPill(
                        title: viewModel.sortOption.rawValue,
                        icon: "arrow.up.arrow.down",
                        color: theme.accents.blue,
                        isSelected: viewModel.sortOption != .distance
                    ) {
                        showSortMenu = true
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.spacing.sm)
            }

            categoryFilter
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.sm + 2) {
                    TrashPill(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        color: theme.palette.textSecondary,
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
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.spacing.xs)
                .padding(.bottom, theme.layout.elementSpacing)
            }
            .background(Color.clear)
            // Auto-scroll to the selected category
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
        VStack(spacing: theme.spacing.lg) {
            Spacer()

            EmptyStateView(
                icon: "location.slash.fill",
                title: "Set Your Location",
                subtitle: "Select a location in Account settings to see nearby events."
            )

            TrashButton(
                baseColor: theme.accents.blue, cornerRadius: theme.corners.large,
                action: { showLocationPicker = true }
            ) {
                HStack {
                    TrashIcon(systemName: "location.fill")
                    Text("Select Location")
                }
                .font(theme.typography.subheadline)
                .fontWeight(.bold)
                .trashOnAccentForeground()
            }
            .padding(.horizontal, theme.layout.screenInset)

            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: theme.spacing.md) {
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
    @ObservedObject private var userSettings = UserSettings.shared  // Access precise location updates
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
        let dist = currentEvent.distance(from: userLocation, preciseLocation: userSettings.preciseLocation)
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
                    VStack(alignment: .leading, spacing: theme.spacing.lg) {
                        // Header — neumorphic concave
                        ZStack {
                            Color.clear
                                .frame(height: 180)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                        .fill(theme.surfaceBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                        )
                                )

                            VStack(spacing: theme.spacing.sm + 4) {
                                TrashIcon(systemName: currentEvent.imageSystemName)
                                    .font(.system(size: 50))
                                    .foregroundColor(currentEvent.category.color)
                                Text(currentEvent.category.rawValue)
                                    .font(theme.typography.headline)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous))
                        .padding(.horizontal, theme.components.contentInset)

                        // Title & Organizer
                        VStack(alignment: .leading, spacing: theme.spacing.xs + 2) {
                            Text(currentEvent.title)
                                .font(theme.typography.title)
                                .foregroundColor(theme.palette.textPrimary)

                            HStack {
                                TrashIcon(systemName: "building.2.fill")
                                    .foregroundColor(theme.palette.textSecondary)
                                Text(currentEvent.organizer)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                            .font(theme.typography.subheadline)
                        }
                        .padding(.horizontal, theme.components.contentInset)

                        // Info Cards
                        VStack(spacing: theme.spacing.sm + 4) {
                            InfoRow(
                                icon: "calendar", title: "Date & Time",
                                value: dateFormatter.string(from: currentEvent.date))
                            InfoRow(
                                icon: "mappin.circle.fill", title: "Location", value: currentEvent.location
                            )
                            InfoRow(icon: "location.fill", title: "Distance", value: distanceText)
                            InfoRow(
                                icon: "person.2.fill", title: "Participants",
                                value: "\(currentEvent.participantCount) / \(currentEvent.maxParticipants)")
                        }
                        .padding(.horizontal, theme.components.contentInset)

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(theme.typography.headline)
                                .foregroundColor(theme.palette.textPrimary)
                            Text(currentEvent.description)
                                .font(theme.typography.body)
                                .foregroundColor(theme.palette.textSecondary)
                        }
                        .padding(.horizontal, theme.components.contentInset)

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
                                ? theme.palette.textSecondary : currentEvent.category.color),
                        cornerRadius: theme.corners.medium,
                        action: {
                            Task {
                                await viewModel.toggleRegistration(for: currentEvent)
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
                    }
                    .disabled(
                        currentEvent.participantCount >= currentEvent.maxParticipants
                            && !currentEvent.isRegistered
                    )
                    .padding(.horizontal, theme.components.contentInset)
                    .padding(.bottom, theme.spacing.sm)
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
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
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
                    VStack(spacing: theme.spacing.sm + 4) {
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
                                .padding(.horizontal, theme.components.contentInset)
                                .frame(minHeight: theme.components.rowHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                        .fill(theme.surfaceBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, theme.components.contentInset)
                    .padding(.vertical, theme.spacing.sm + 4)
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
