//
//  CommunityView.swift (EventsView)
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import Combine
import CoreLocation

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

struct CommunityEvent: Identifiable {
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
    
    enum EventCategory: String, CaseIterable {
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
    
    init(id: UUID = UUID(), title: String, organizer: String, description: String, date: Date, location: String, latitude: Double, longitude: Double, imageSystemName: String, category: EventCategory, participantCount: Int, maxParticipants: Int, communityId: String?, communityName: String? = nil, distanceKm: Double? = nil, isRegistered: Bool = false, isPersonal: Bool = false) {
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
    private let minLoadInterval: TimeInterval = 0.5 // 最小请求间隔

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
              let precise = userSettings.preciseLocation else { return }

        events.sort { event1, event2 in
            let dist1 = event1.distance(from: userSettings.selectedLocation, preciseLocation: precise)
            let dist2 = event2.distance(from: userSettings.selectedLocation, preciseLocation: precise)
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
        let response = await communityService.getNearbyEvents(
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

        // 🚀 如果有精确GPS且按距离排序，使用客户端精确排序
        if sortOption == .distance, let precise = userSettings.preciseLocation {
            events.sort { event1, event2 in
                let dist1 = event1.distance(from: userSettings.selectedLocation, preciseLocation: precise)
                let dist2 = event2.distance(from: userSettings.selectedLocation, preciseLocation: precise)
                return dist1 < dist2
            }
        }

        isLoading = false
    }
    
    /// 报名活动
    func registerForEvent(_ event: CommunityEvent) async -> Bool {
        let success = await communityService.registerForEvent(event.id)
        if success {
            // 更新本地状态
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = true
                events[index].participantCount += 1
            }
        }
        return success
    }
    
    /// 取消报名
    func cancelRegistration(_ event: CommunityEvent) async -> Bool {
        let success = await communityService.cancelEventRegistration(event.id)
        if success {
            // 更新本地状态
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isRegistered = false
                events[index].participantCount = max(0, events[index].participantCount - 1)
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

// MARK: - Main View (EventsView / CommunityView)

struct CommunityView: View {
    @StateObject private var viewModel = EventsViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showEventDetail: CommunityEvent? = nil
    @State private var showSortMenu = false
    @State private var showAccountSheet = false
    @State private var showCreateEventSheet = false
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 🎨 App Store 风格头部
                appStoreHeader(title: "Events")
                
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
                    // 活动列表
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
                                EventCard(
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
                }
            }
            
            // 🚀 浮动加号按钮 (FAB)
            if !authVM.isAnonymous && viewModel.hasLocation {
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
            EventDetailSheet(event: event, viewModel: viewModel, userLocation: userSettings.selectedLocation)
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateEventFormSheet(isPresented: $showCreateEventSheet, userSettings: userSettings) {
                // 刷新活动列表
                Task { await viewModel.loadEvents() }
            }
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
    
    // MARK: - 🎨 App Store Style Header
    private func appStoreHeader(title: String) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .default))
            
            Spacer()
            
            AccountButton(showAccountSheet: $showAccountSheet)
                .environmentObject(authVM)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading events...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Control Bar
    private var controlBar: some View {
        HStack(spacing: 12) {
            // 位置显示
            if let location = userSettings.selectedLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(location.city)
                        .font(.subheadline.bold())
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
            }
            
            Spacer()
            
            // 仅显示已加入社区 Toggle
            Button(action: {
                viewModel.showOnlyJoinedCommunities.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.showOnlyJoinedCommunities ? "person.3.fill" : "globe")
                        .font(.caption)
                        .frame(width: 14) // 🚀 固定宽度防止图标切换导致的布局跳动
                    Text(viewModel.showOnlyJoinedCommunities ? "Joined" : "All")
                        .font(.caption.bold())
                        .frame(minWidth: 36, alignment: .leading) // 🚀 固定最小宽度
                }
                .foregroundColor(viewModel.showOnlyJoinedCommunities ? .cyan : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewModel.showOnlyJoinedCommunities ? Color.cyan.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .animation(.easeInOut(duration: 0.2), value: viewModel.showOnlyJoinedCommunities) // 🚀 轻量动画
            }
            
            // 排序按钮
            Menu {
                ForEach(EventSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.sortOption = option
                    }) {
                        HStack {
                            Label(option.rawValue, systemImage: option.icon)
                            Spacer()
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                    Text(viewModel.sortOption.rawValue)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(viewModel.sortOption != .distance ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(viewModel.sortOption != .distance ? Color.blue : Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .animation(.none, value: viewModel.sortOption) // 🚀 禁用按钮内部动画防止卡顿
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .animation(.none, value: viewModel.sortOption) // 🚀 禁用整个控制栏的布局动画
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    CategoryPill(
                        title: "All",
                        icon: "square.grid.2x2.fill",
                        color: .gray,
                        isSelected: viewModel.selectedCategory == nil
                    ) {
                        viewModel.selectedCategory = nil
                    }
                    .id("all")
                    
                    ForEach(CommunityEvent.EventCategory.allCases, id: \.self) { category in
                        CategoryPill(
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
            .background(Color(.systemBackground))
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
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            Text("Set Your Location")
                .font(.title2.bold())
            
            Text("Select a location in Account settings\nto see nearby events")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            NavigationLink(destination: AccountView()) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Go to Settings")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(20)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Events Found")
                .font(.headline)
            
            if viewModel.showOnlyJoinedCommunities {
                Text("Try showing all events or join more communities")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    viewModel.showOnlyJoinedCommunities = false
                }) {
                    Text("Show All Events")
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                }
            } else {
                Text("Check back later for new events!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.bold())
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(20)
            .animation(.easeInOut(duration: 0.15), value: isSelected) // 🚀 轻量快速动画
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: CommunityEvent
    let userLocation: UserLocation?
    let preciseLocation: CLLocation?  // 🚀 新增：精确GPS位置
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }
    
    private var distanceText: String {
        // 优先使用精确位置计算距离
        let dist = event.distance(from: userLocation, preciseLocation: preciseLocation)
        if dist <= 0 { return "" }
        if dist < 1 {
            return String(format: "%.0f m", dist * 1000)
        } else {
            return String(format: "%.1f km", dist)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                descriptionText
                dateLocationRow
                footerRow
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header Row
    private var headerRow: some View {
        HStack(spacing: 12) {
            categoryIcon
            titleSection
            Spacer()
            registeredBadge
        }
    }
    
    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(event.category.color.opacity(0.15))
                .frame(width: 50, height: 50)
            Image(systemName: event.imageSystemName)
                .font(.title3)
                .foregroundColor(event.category.color)
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.category.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(event.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(event.category.color.opacity(0.1))
                    .cornerRadius(6)
                
                if userLocation != nil {
                    Text(distanceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(event.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var registeredBadge: some View {
        if event.isRegistered {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        }
    }
    
    // MARK: - Description
    private var descriptionText: some View {
        Text(event.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
    
    // MARK: - Date & Location Row
    private var dateLocationRow: some View {
        HStack(spacing: 16) {
            Label(dateFormatter.string(from: event.date), systemImage: "calendar")
            Label(event.location, systemImage: "mappin.circle.fill")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
    }
    
    // MARK: - Footer Row
    private var footerRow: some View {
        HStack {
            Text("by \(event.organizer)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            participantCount
        }
    }
    
    private var participantCount: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            Text("\(event.participantCount)/\(event.maxParticipants)")
                .font(.caption.bold())
        }
        .foregroundColor(event.participantCount >= event.maxParticipants ? .red : .blue)
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: CommunityEvent
    @ObservedObject var viewModel: EventsViewModel
    let userLocation: UserLocation?
    @ObservedObject private var userSettings = UserSettings.shared  // 🚀 新增：获取精确位置
    @Environment(\.dismiss) var dismiss
    
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
                        InfoRow(icon: "calendar", title: "Date & Time", value: dateFormatter.string(from: event.date))
                        InfoRow(icon: "mappin.circle.fill", title: "Location", value: event.location)
                        InfoRow(icon: "location.fill", title: "Distance", value: distanceText)
                        InfoRow(icon: "person.2.fill", title: "Participants", value: "\(event.participantCount) / \(event.maxParticipants)")
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(event.description)
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

struct InfoRow: View {
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

// MARK: - Create Event Form Sheet

struct CreateEventFormSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var userSettings: UserSettings
    var onCreated: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date().addingTimeInterval(86400) // 默认明天
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
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        eventDate > Date()
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Event Type Picker
                Section {
                    Picker("Event Type", selection: $isPersonalEvent) {
                        Text("Personal Event").tag(true)
                        Text("Community Event").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if !isPersonalEvent {
                        if userSettings.adminCommunities.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("You need to be a community admin to create community events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Picker("Select Community", selection: $selectedCommunityId) {
                                Text("Select...").tag(nil as String?)
                                ForEach(userSettings.adminCommunities) { community in
                                    Text(community.name).tag(community.id as String?)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Event Host")
                } footer: {
                    Text(isPersonalEvent ? "You will be shown as the organizer" : "Only community admins can create community events")
                }
                
                // Event Details
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    DatePicker("Date & Time", selection: $eventDate, in: Date()...)
                    
                    TextField("Location", text: $location)
                        .textInputAutocapitalization(.words)
                }
                
                // Settings
                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat.capitalized, systemImage: iconForCategory(cat))
                                .tag(cat)
                        }
                    }
                    
                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 5...500, step: 5)
                }
                
                // Info Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("You can create up to 7 events per week.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Error Message
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createEvent) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canCreate || isLoading || (!isPersonalEvent && selectedCommunityId == nil))
                }
            }
            .alert("Event Created!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    isPresented = false
                    onCreated()
                }
            } message: {
                Text("Your event \"\(title)\" has been created successfully!")
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
            let result = await CommunityService.shared.createEvent(
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
            
            await MainActor.run {
                isLoading = false
                
                if result.success {
                    showSuccessAlert = true
                } else {
                    errorMessage = result.message
                }
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
