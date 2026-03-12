import CoreLocation
import SwiftUI
// MARK: - Main View (EventsView)

private struct EventsRefreshInputs: Equatable {
    let selectedLocation: UserLocation?
    let selectedCategory: CommunityEvent.EventCategory?
    let sortOption: EventSortOption
    let showOnlyJoinedCommunities: Bool
}

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @Environment(\.trashTheme) private var theme
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showSortMenu = false
    @State private var showLocationPicker = false  // Added for location picker
    @State private var isMapView = false
    @State private var showSecondaryControls = false

    private var refreshInputs: EventsRefreshInputs {
        EventsRefreshInputs(
            selectedLocation: userSettings.selectedLocation,
            selectedCategory: viewModel.selectedCategory,
            sortOption: viewModel.sortOption,
            showOnlyJoinedCommunities: viewModel.showOnlyJoinedCommunities
        )
    }

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
            CommunityEventDetailSheet(
                event: event,
                userLocation: userSettings.selectedLocation,
                resolveCurrentEvent: { selectedEvent in
                    viewModel.events.first(where: { $0.id == selectedEvent.id }) ?? selectedEvent
                },
                onToggleRegistration: { selectedEvent in
                    await viewModel.toggleRegistration(for: selectedEvent)
                }
            )
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
            viewModel.scheduleRefresh(immediate: viewModel.events.isEmpty)
        }
        .onChange(of: refreshInputs) { _ in
            viewModel.scheduleRefresh()
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
        .onReceive(NotificationCenter.default.publisher(for: .communityEventsDidChange)) { _ in
            viewModel.scheduleRefresh()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: theme.layout.elementSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    ShimmerSkeletonRow(showAvatar: false)
                }
            }
            .padding(.top, theme.layout.elementSpacing)
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

private struct SortOptionSheet: View {
    @Binding var selection: EventSortOption
    @Binding var isPresented: Bool
    @Environment(\.trashTheme) private var theme

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
