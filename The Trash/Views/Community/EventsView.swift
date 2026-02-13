//
//  EventsView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import Combine
import CoreLocation
import SwiftUI

// MARK: - Event Sort Option

enum EventSortOption: String, CaseIterable {
    case date = "Date"
    case distance = "Distance"
    case participants = "Popularity"

    var icon: String {
        switch self {
        case .date: return "calendar"
        case .distance: return "location.fill"
        case .participants: return "person.2.fill"
        }
    }
}

// MARK: - Models

struct CommunityEvent: Identifiable, Hashable, Equatable {
    var id: UUID
    let title: String
    let organizer: String
    let description: String
    let date: Date
    let location: String
    let latitude: Double
    let longitude: Double
    let imageSystemName: String
    let category: EventCategory
    var participantCount: Int
    let maxParticipants: Int
    let communityId: String?  // 🔥 修复：个人活动时为 nil
    var communityName: String?
    var distanceKm: Double?
    var isRegistered: Bool = false
    var isPersonal: Bool = false  // 🔥 新增：是否为个人活动

    enum EventCategory: String, CaseIterable, Codable {
        case cleanup = "Cleanup"
        case workshop = "Workshop"
        case competition = "Competition"
        case education = "Education"

        var color: Color {
            switch self {
            case .cleanup: return .green
            case .workshop: return .blue
            case .competition: return .orange
            case .education: return .purple
            }
        }

        var icon: String {
            switch self {
            case .cleanup: return "leaf.fill"
            case .workshop: return "hammer.fill"
            case .competition: return "trophy.fill"
            case .education: return "book.fill"
            }
        }
    }

    static func == (lhs: CommunityEvent, rhs: CommunityEvent) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // 计算距离（公里）- 优先使用后端计算的距离，其次使用精确GPS，最后使用城市中心
    func distance(from userLocation: UserLocation?, preciseLocation: CLLocation? = nil) -> Double {
        // 1. 优先使用后端返回的距离
        if let distanceKm = distanceKm {
            return distanceKm
        }

        // 2. 如果有精确 GPS 位置，使用它计算
        if let precise = preciseLocation {
            let eventLoc = CLLocation(latitude: latitude, longitude: longitude)
            return eventLoc.distance(from: precise) / 1000.0
        }

        // 3. 否则使用城市中心坐标
        guard let userLoc = userLocation else { return 0 }
        let eventLoc = CLLocation(latitude: latitude, longitude: longitude)
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return eventLoc.distance(from: userCLLoc) / 1000.0
    }

    // 从 API 响应转换
    init(from response: EventResponse) {
        self.id = response.id
        self.title = response.title
        self.organizer = response.organizer
        self.description = response.description ?? ""
        self.date = response.eventDate
        self.location = response.location
        self.latitude = response.latitude
        self.longitude = response.longitude
        self.imageSystemName = response.iconName ?? "calendar"
        self.category = EventCategory(rawValue: response.category.capitalized) ?? .cleanup
        self.participantCount = response.participantCount
        self.maxParticipants = response.maxParticipants
        self.communityId = response.communityId  // 🔥 修复：可能为 nil
        self.communityName = response.communityName
        self.distanceKm = response.distanceKm
        self.isRegistered = response.isRegistered ?? false
        self.isPersonal = response.isPersonal ?? false  // 🔥 新增
    }

    init(
        id: UUID = UUID(), title: String, organizer: String, description: String, date: Date,
        location: String, latitude: Double, longitude: Double, imageSystemName: String,
        category: EventCategory, participantCount: Int, maxParticipants: Int, communityId: String?,
        communityName: String? = nil, distanceKm: Double? = nil, isRegistered: Bool = false,
        isPersonal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.organizer = organizer
        self.description = description
        self.date = date
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.imageSystemName = imageSystemName
        self.category = category
        self.participantCount = participantCount
        self.maxParticipants = maxParticipants
        self.communityId = communityId
        self.communityName = communityName
        self.distanceKm = distanceKm
        self.isRegistered = isRegistered
        self.isPersonal = isPersonal
    }
}

// MARK: - ViewModel

@MainActor
class EventsViewModel: ObservableObject {
    @Published var events: [CommunityEvent] = []
    @Published var isLoading = false
    @Published var selectedCategory: CommunityEvent.EventCategory? = nil
    @Published var sortOption: EventSortOption = .distance  // 🔥 默认按距离排序
    @Published var showOnlyJoinedCommunities: Bool = false
    @Published var errorMessage: String?

    // 🚀 优化：添加请求节流
    private var loadTask: Task<Void, Never>?
    private var lastLoadTime: Date?
    private let minLoadInterval: TimeInterval = 0.5  // 最小请求间隔

    private var userSettings: UserSettings {
        UserSettings.shared
    }

    private var communityService: CommunityService {
        CommunityService.shared
    }

    var hasLocation: Bool {
        userSettings.selectedLocation != nil
    }

    var locationName: String {
        userSettings.selectedLocation?.city ?? ""
    }

    /// 获取当前最佳位置坐标（优先使用精确GPS，否则使用城市中心）
    private var currentCoordinates: (latitude: Double, longitude: Double)? {
        // 优先使用精确GPS位置
        if let precise = userSettings.preciseLocation {
            return (precise.coordinate.latitude, precise.coordinate.longitude)
        }
        // 否则使用选择的城市中心
        if let location = userSettings.selectedLocation {
            return (location.latitude, location.longitude)
        }
        return nil
    }

    init() {
        // 初始化时不加载，等待 onAppear
    }

    /// 请求精确GPS位置（如果有权限）
    func requestPreciseLocation() {
        if userSettings.hasLocationPermission {
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            userSettings.requestLocationPermission()
        }
    }

    /// 使用精确GPS重新排序事件（客户端排序）
    func sortEventsByPreciseDistance() {
        guard sortOption == .distance,
            let precise = userSettings.preciseLocation
        else { return }

        events.sort { event1, event2 in
            let dist1 = event1.distance(
                from: userSettings.selectedLocation, preciseLocation: precise)
            let dist2 = event2.distance(
                from: userSettings.selectedLocation, preciseLocation: precise)
            return dist1 < dist2
        }
    }

    /// 从后端加载附近活动
    func loadEvents() async {
        // 🚀 优化：取消之前的请求任务
        loadTask?.cancel()

        // 🚀 优化：请求节流 - 防止短时间内多次请求
        if let lastTime = lastLoadTime, Date().timeIntervalSince(lastTime) < minLoadInterval {
            try? await Task.sleep(nanoseconds: UInt64(minLoadInterval * 1_000_000_000))
        }

        guard let coords = currentCoordinates else {
            events = []
            return
        }

        // 🚀 优化：防止重复显示 loading（如果已有数据）
        if events.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        lastLoadTime = Date()

        let categoryParam: String? = selectedCategory?.rawValue.lowercased()
        let sortByParam: String
        switch sortOption {
        case .date: sortByParam = "date"
        case .distance: sortByParam = "distance"
        case .participants: sortByParam = "popularity"
        }

        // 🚀 使用精确GPS坐标（如果有）进行后端查询
        do {
            let response = try await communityService.getNearbyEvents(
                latitude: coords.latitude,
                longitude: coords.longitude,
                maxDistanceKm: 50,
                category: categoryParam,
                onlyJoinedCommunities: showOnlyJoinedCommunities,
                sortBy: sortByParam
            )

            // 🚀 优化：检查任务是否被取消
            guard !Task.isCancelled else { return }

            events = response.map { CommunityEvent(from: $0) }
        } catch {
            guard !Task.isCancelled else { return }
            print("❌ Get nearby events error: \(error)")
            errorMessage = error.localizedDescription
        }

        // 🚀 如果有精确GPS且按距离排序，使用客户端精确排序
        if sortOption == .distance, let precise = userSettings.preciseLocation {
            events.sort { event1, event2 in
                let dist1 = event1.distance(
                    from: userSettings.selectedLocation, preciseLocation: precise)
                let dist2 = event2.distance(
                    from: userSettings.selectedLocation, preciseLocation: precise)
                return dist1 < dist2
            }
        }

        isLoading = false
    }

    /// 报名活动
    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        do {
            let success = try await communityService.registerForEvent(event.id)
            if success {
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index].isRegistered = true
                    events[index].participantCount += 1
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
            let success = try await communityService.cancelEventRegistration(event.id)
            if success {
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index].isRegistered = false
                    events[index].participantCount = max(0, events[index].participantCount - 1)
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

// MARK: - Main View (EventsView)

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showSortMenu = false
    // showAccountSheet managed by ContentView via environment
    @State private var showCreateEventSheet = false
    @State private var showLocationPicker = false  // Added for location picker
    @State private var isMapView = false

    var body: some View {
        ZStack {
            ThemeBackground()

            VStack(spacing: 0) {
                // Header is now handled by parent view

                // 顶部控制栏
                controlBar

                // 分类筛选器
                categoryFilter

                if !viewModel.hasLocation {
                    noLocationView
                } else if viewModel.isLoading {
                    loadingView
                } else if viewModel.events.isEmpty {
                    emptyState
                } else {
                    if isMapView {
                        // 地图视图
                        EventsMapView(
                            events: viewModel.events,
                            userSettings: userSettings,
                            onEventSelected: { event in
                                showEventDetail = event
                            }
                        )
                        .transition(.opacity)
                    } else {
                        // 活动列表
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

            // 🚀 浮动加号按钮 (FAB)
            if !authVM.isAnonymous && viewModel.hasLocation && !isMapView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus") {
                            showCreateEventSheet = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
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
                .presentationBackground(theme.appearance.sheetBackground)
        }
        .task {
            // 🚀 请求精确GPS位置（如果有权限）
            viewModel.requestPreciseLocation()

            // 🚀 优化：只在首次加载或数据为空时请求
            if viewModel.events.isEmpty {
                await viewModel.loadEvents()
            }
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
                .tint(.neuAccentBlue)
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(.neuSecondaryText)
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
        .background(theme.palette.background)
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
            .background(theme.palette.background)
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

            ZStack {
                Circle()
                    .fill(theme.palette.background)
                    .frame(width: 120, height: 120)
                    .shadow(color: theme.shadows.dark, radius: 8, x: 6, y: 6)
                    .shadow(color: theme.shadows.light, radius: 8, x: -4, y: -4)
                TrashIcon(systemName: "location.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(theme.accents.blue)
            }

            Text("Set Your Location")
                .font(theme.typography.title)
                .foregroundColor(theme.palette.textPrimary)

            Text("Select a location in Account settings\nto see nearby events")
                .font(theme.typography.subheadline)
                .foregroundColor(theme.palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

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

            ZStack {
                Circle()
                    .fill(theme.palette.background)
                    .frame(width: 100, height: 100)
                    .shadow(color: theme.shadows.dark, radius: 6, x: 4, y: 4)
                    .shadow(color: theme.shadows.light, radius: 6, x: -3, y: -3)
                TrashIcon(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(theme.palette.textSecondary)
            }

            Text("No Events Found")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            if viewModel.showOnlyJoinedCommunities {
                Text("Try showing all events or join more communities")
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)

                TrashTextButton(title: "Show All Events", variant: .accent) {
                    viewModel.showOnlyJoinedCommunities = false
                }
            } else {
                Text("Check back later for new events!")
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
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
    @Environment(\.trashTheme) private var theme

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
                ThemeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header — neumorphic concave
                        ZStack {
                            Color.clear
                                .frame(height: 180)
                                .trashCard(cornerRadius: 20)

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
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(
                                    currentEvent.isRegistered ? .warning : .success)
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
                .background(theme.appearance.sheetBackground)
            }
        }
        .presentationBackground(theme.appearance.sheetBackground)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    @Environment(\.trashTheme) private var theme

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
        .trashCard(cornerRadius: 12)
    }
}

private struct SortOptionSheet: View {
    @Binding var selection: EventSortOption
    @Binding var isPresented: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()
                    .ignoresSafeArea()

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
                                .trashCard(cornerRadius: 14)
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

// MARK: - Create Event Form Sheet

struct CreateEventFormSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var userSettings: UserSettings
    var onCreated: () -> Void
    @Environment(\.trashTheme) private var theme

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(86400)  // 默认明天
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50
    @State private var isPersonalEvent = true
    @State private var selectedCommunityId: String? = nil

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false

    let categories = ["cleanup", "workshop", "competition", "education", "other"]

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !location.trimmingCharacters(in: .whitespaces).isEmpty && eventDate > Date()
    }

    var body: some View {
        NavigationView {
            Form {
                // Event Type Picker
                Section {
                    TrashSegmentedControl(
                        options: [
                            TrashSegmentOption(
                                value: true, title: "Personal Event", icon: "person.crop.circle"),
                            TrashSegmentOption(
                                value: false, title: "Community Event", icon: "person.3.fill"),
                        ],
                        selection: $isPersonalEvent
                    )

                    if !isPersonalEvent {
                        if userSettings.adminCommunities.isEmpty {
                            HStack {
                                TrashIcon(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(theme.semanticWarning)
                                Text("You need to be a community admin to create community events")
                                    .font(theme.typography.caption)
                                    .foregroundColor(theme.palette.textSecondary)
                            }
                        } else {
                            TrashOptionalFormPicker(
                                title: "Select Community",
                                selection: $selectedCommunityId,
                                options: [
                                    TrashOptionalPickerOption(value: nil, title: "Select...")
                                ]
                                    + userSettings.adminCommunities.map {
                                        TrashOptionalPickerOption(value: $0.id, title: $0.name)
                                    }
                            )
                        }
                    }
                } header: {
                    Text("Event Host")
                } footer: {
                    Text(
                        isPersonalEvent
                            ? "You will be shown as the organizer"
                            : "Only community admins can create community events")
                }

                // Event Details
                Section("Event Details") {
                    TrashFormTextField(
                        title: "Event Title",
                        text: $title,
                        textInputAutocapitalization: .words
                    )

                    TrashFormTextEditor(text: $description, minHeight: 80)

                    TrashFormDatePicker(
                        title: "Date & Time", selection: $eventDate, range: Date()...)

                    TrashFormTextField(
                        title: "Location",
                        text: $location,
                        textInputAutocapitalization: .words
                    )
                }

                // Settings
                Section("Settings") {
                    TrashFormPicker(
                        title: "Category",
                        selection: $category,
                        options: categories.map { cat in
                            TrashPickerOption(
                                value: cat, title: cat.capitalized, icon: iconForCategory(cat))
                        }
                    )

                    TrashFormStepper(
                        title: "Max Participants", value: $maxParticipants, range: 5...500, step: 5)
                }

                // Info Section
                Section {
                    HStack(spacing: 12) {
                        TrashIcon(systemName: "info.circle.fill")
                            .foregroundColor(theme.accents.blue)
                        Text("You can create up to 7 events per week.")
                            .font(theme.typography.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                }

                // Error Message
                if let error = errorMessage {
                    Section {
                        HStack {
                            TrashIcon(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.semanticDanger)
                            Text(error)
                                .foregroundColor(theme.semanticDanger)
                                .font(theme.typography.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    TrashTextButton(title: "Create", variant: .accent, action: createEvent)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            }
                        }
                        .disabled(
                            !canCreate || isLoading
                                || (!isPersonalEvent && selectedCommunityId == nil))
                }
            }
            .sheet(isPresented: $showSuccessAlert) {
                TrashNoticeSheet(
                    title: "Event Created!",
                    message: "Your event \"\(title)\" has been created successfully!",
                    onClose: {
                        showSuccessAlert = false
                        isPresented = false
                        onCreated()
                    }
                )
                .presentationDetents([.fraction(0.3), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .task {
                // 加载用户已加入的社区
                if userSettings.joinedCommunities.isEmpty {
                    await userSettings.loadMyCommunities()
                }
            }
        }
    }

    private func createEvent() {
        guard canCreate else { return }
        guard let userLocation = userSettings.selectedLocation else {
            errorMessage = "Please select a location first"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await CommunityService.shared.createEvent(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description,
                    category: category,
                    eventDate: eventDate,
                    location: location.trimmingCharacters(in: .whitespaces),
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude,
                    maxParticipants: maxParticipants,
                    communityId: isPersonalEvent ? nil : selectedCommunityId,
                    iconName: iconForCategory(category)
                )

                isLoading = false
                if result.success {
                    showSuccessAlert = true
                } else {
                    errorMessage = result.message
                }
            } catch {
                isLoading = false
                errorMessage = "Failed to create event: \(error.localizedDescription)"
            }
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "cleanup": return "leaf.fill"
        case "workshop": return "hammer.fill"
        case "competition": return "trophy.fill"
        case "education": return "book.fill"
        default: return "calendar"
        }
    }
}
