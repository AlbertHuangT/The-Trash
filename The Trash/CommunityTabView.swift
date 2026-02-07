//
//  CommunityTabView.swift
//  The Trash
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import CoreLocation

// MARK: - Community Tab Sections

enum CommunityTabSection: String, CaseIterable {
    case nearby = "Nearby"
    case joined = "Joined"
    
    var icon: String {
        switch self {
        case .nearby: return "location.fill"
        case .joined: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Main View

struct CommunityTabView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showAccountSheet = false
    @State private var selectedSection: CommunityTabSection = .nearby
    @State private var searchText = ""
    @State private var showLocationPicker = false
    @State private var showCreateEventSheet = false
    @State private var showCreateCommunitySheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // 🎨 App Store 风格头部
                    appStoreHeader(title: "Communities")
                    
                    // 匿名用户限制
                    if authVM.isAnonymous {
                        anonymousRestrictionView
                    } else {
                        // Section Picker
                        sectionPicker
                        
                        // Content
                        switch selectedSection {
                        case .nearby:
                            nearbyCommunitiesContent
                        case .joined:
                            joinedCommunitiesContent
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
                
                // 🚀 浮动加号按钮 (FAB)
                if !authVM.isAnonymous {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FloatingActionButton(icon: "plus") {
                                showCreateCommunitySheet = true
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(isPresented: $showLocationPicker)
        }
        .sheet(isPresented: $showCreateEventSheet) {
            CreateEventSheet(isPresented: $showCreateEventSheet)
        }
        .sheet(isPresented: $showCreateCommunitySheet) {
            CreateCommunitySheet(isPresented: $showCreateCommunitySheet)
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
    
    // MARK: - Section Picker
    
    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(CommunityTabSection.allCases, id: \.self) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Nearby Communities Content
    
    @ViewBuilder
    private var nearbyCommunitiesContent: some View {
        VStack(spacing: 0) {
            // Location Header
            locationHeader
            
            if userSettings.selectedLocation == nil {
                noLocationView
            } else if userSettings.isLoadingCommunities {
                loadingView
            } else if userSettings.communitiesInCity.isEmpty {
                emptyNearbyView
            } else {
                nearbyCommunitiesList
            }
        }
        .task {
            // 🔥 FIX: 首次进入时，如果已有选择的地点但社区列表为空，则加载社区
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }
    
    private var locationHeader: some View {
        Button(action: { showLocationPicker = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if let location = userSettings.selectedLocation {
                        Text(location.city)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(location.state)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Tap to choose your city")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var noLocationView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Location Set")
                .font(.title2).bold()
            Text("Select a location to discover\ncommunities near you")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { showLocationPicker = true }) {
                Text("Select Location")
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
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Loading communities...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var emptyNearbyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Communities Yet")
                .font(.title2).bold()
            Text("No communities in this area yet.\nBe the first to start one!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var nearbyCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.communitiesInCity) { community in
                    CommunityCardView(community: community)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable {
            if let location = userSettings.selectedLocation {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }
    
    // MARK: - Joined Communities Content
    
    @ViewBuilder
    private var joinedCommunitiesContent: some View {
        Group {
            if userSettings.isLoadingCommunities && userSettings.joinedCommunities.isEmpty {
                loadingView
            } else if userSettings.joinedCommunities.isEmpty {
                emptyJoinedView
            } else {
                joinedCommunitiesList
            }
        }
        .task {
            // 只在首次进入或列表为空时加载
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
    }
    
    private var emptyJoinedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Communities Joined")
                .font(.title2).bold()
            Text("Join communities to connect with\npeople in your area")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { selectedSection = .nearby }) {
                Text("Browse Nearby")
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
    
    private var joinedCommunitiesList: some View {
        List {
            ForEach(userSettings.joinedCommunities) { community in
                JoinedCommunityRowExpanded(
                    community: community,
                    onCreateEvent: {
                        // TODO: 打开创建活动的 sheet，传入社区信息
                        showCreateEventSheet = true
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await userSettings.loadMyCommunities()
        }
    }
    
    // MARK: - Anonymous Restriction View
    
    private var anonymousRestrictionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.bottom, 10)
            
            Text("Access Restricted")
                .font(.title).bold()
            
            Text("Communities are only available for registered users.\n\nPlease link your Email or Phone in your Account to access this feature.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Joined Community Row with Admin Features

struct JoinedCommunityRowExpanded: View {
    let community: Community
    let onCreateEvent: () -> Void
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false  // 🚀 使用 sheet 展示详情
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 可点击区域
            Button(action: { showDetail = true }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(community.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if community.isAdmin {
                                Text("Admin")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Label(community.fullLocation, systemImage: "mappin.circle.fill")
                            Label("\(community.memberCount)", systemImage: "person.2.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            
            if !community.description.isEmpty {
                Button(action: { showDetail = true }) {
                    Text(community.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Admin: Create Event Button
                if community.isAdmin {
                    Button(action: onCreateEvent) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Event")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // Leave Button
                Button(action: {
                    Task {
                        isLoading = true
                        _ = await userSettings.leaveCommunity(community)
                        isLoading = false
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                            Text("Leave")
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                    .frame(maxWidth: community.isAdmin ? nil : .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, community.isAdmin ? 20 : 0)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var isSelecting = false // 🚀 防止重复点击
    @State private var showLocationPermissionAlert = false // 🚀 新增：显示定位权限请求弹窗
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 🚀 新增：使用当前位置选项
                if userSettings.locationPermissionStatus != .denied && userSettings.locationPermissionStatus != .restricted {
                    useCurrentLocationSection
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search cities...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Section Header
                HStack {
                    Text("Or select a city")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Location List
                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        LocationRow(
                            location: location,
                            isSelected: userSettings.selectedLocation?.city == location.city,
                            isDisabled: isSelecting
                        ) {
                            guard !isSelecting else { return }
                            isSelecting = true
                            Task {
                                await userSettings.selectLocation(location)
                                isPresented = false
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Enable Location Services", isPresented: $showLocationPermissionAlert) {
                Button("Not Now", role: .cancel) { }
                Button("Enable") {
                    userSettings.requestLocationPermission()
                }
            } message: {
                Text("Allow location access to enable distance-based sorting for nearby events. This helps you find events closest to you.")
            }
            .onChange(of: userSettings.locationPermissionStatus) { newStatus in
                // 权限授予后自动获取位置
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    userSettings.requestCurrentLocation()
                }
            }
            .onChange(of: userSettings.preciseLocation) { newLocation in
                // 获取到精确位置后，找到最近的城市
                if let location = newLocation, !isSelecting {
                    isSelecting = true
                    Task {
                        let nearestCity = findNearestCity(to: location)
                        await userSettings.selectLocation(nearestCity)
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // 🚀 新增：使用当前位置区域
    private var useCurrentLocationSection: some View {
        VStack(spacing: 0) {
            Button(action: handleUseCurrentLocation) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        if userSettings.isRequestingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Current Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(locationSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if userSettings.hasLocationPermission {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Enable")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .disabled(userSettings.isRequestingLocation)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }
    
    private var locationSubtitle: String {
        switch userSettings.locationPermissionStatus {
        case .notDetermined:
            return "Enable for distance-based event sorting"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Find the nearest city automatically"
        case .denied, .restricted:
            return "Location access denied"
        @unknown default:
            return "Enable for better experience"
        }
    }
    
    private func handleUseCurrentLocation() {
        if userSettings.hasLocationPermission {
            // 已有权限，直接获取位置
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            // 未请求过，显示说明弹窗
            showLocationPermissionAlert = true
        }
    }
    
    // 根据精确位置找到最近的预定义城市
    private func findNearestCity(to location: CLLocation) -> UserLocation {
        var nearestCity = PredefinedLocations.all[0]
        var minDistance = Double.infinity
        
        for city in PredefinedLocations.all {
            let cityLocation = CLLocation(latitude: city.latitude, longitude: city.longitude)
            let distance = location.distance(from: cityLocation)
            if distance < minDistance {
                minDistance = distance
                nearestCity = city
            }
        }
        
        return nearestCity
    }
}

// 🚀 提取为单独组件解决点击问题
private struct LocationRow: View {
    let location: UserLocation
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.city)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(location.state)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 🚀 关键：扩大点击区域
        .onTapGesture {
            onTap()
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Create Event Sheet (Placeholder)

struct CreateEventSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date()
    @State private var location = ""
    @State private var category = "cleanup"
    @State private var maxParticipants = 50
    
    let categories = ["cleanup", "workshop", "competition", "education", "other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Event Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    DatePicker("Date & Time", selection: $eventDate)
                    TextField("Location", text: $location)
                }
                
                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat.capitalized).tag(cat)
                        }
                    }
                    
                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 10...500, step: 10)
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        // TODO: 调用后端 API 创建活动
                        isPresented = false
                    }
                    .disabled(title.isEmpty || location.isEmpty)
                }
            }
        }
    }
}

// MARK: - Floating Action Button (FAB)

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Create Community Sheet

struct CreateCommunitySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    // 使用用户当前选择的位置
    private var selectedCity: String {
        userSettings.selectedLocation?.city ?? ""
    }
    
    private var selectedState: String {
        userSettings.selectedLocation?.state ?? ""
    }
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedCity.isEmpty
    }
    
    // 生成社区 ID (slug)
    private var communityId: String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        return "\(slug)-\(selectedCity.lowercased())"
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Location Info
                Section {
                    if userSettings.selectedLocation != nil {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedCity)
                                    .font(.headline)
                                Text(selectedState)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Please select a location first")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Your community will be created in this city")
                }
                
                // Community Details
                Section("Community Details") {
                    TextField("Community Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Info Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("You can create up to 3 communities. You will automatically become the admin of this community.")
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
            .navigationTitle("Create Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createCommunity) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(!canCreate || isLoading)
                }
            }
            .alert("Community Created!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    isPresented = false
                }
            } message: {
                Text("Your community \"\(name)\" has been created. You are now the admin!")
            }
        }
    }
    
    private func createCommunity() {
        guard canCreate else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let result = await CommunityService.shared.createCommunity(
                id: communityId,
                name: name.trimmingCharacters(in: .whitespaces),
                city: selectedCity,
                state: selectedState,
                description: description.isEmpty ? nil : description,
                latitude: userSettings.selectedLocation?.latitude,
                longitude: userSettings.selectedLocation?.longitude
            )
            
            await MainActor.run {
                isLoading = false
                
                if result.success {
                    showSuccessAlert = true
                    // 刷新社区列表
                    Task {
                        await userSettings.loadCommunitiesForCity(selectedCity)
                        await userSettings.loadMyCommunities()
                    }
                } else {
                    errorMessage = result.message
                }
            }
        }
    }
}
