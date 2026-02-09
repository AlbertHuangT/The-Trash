//
//  CommunityComponents.swift
//  The Trash
//
//  Extracted from AccountView.swift and CommunityTabView.swift
//

import SwiftUI

// MARK: - Community Selection Sheet
struct CommunitySelectionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Location").tag(0)
                    Text("My Communities").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if selectedTab == 0 {
                    locationSelectionView
                } else {
                    communitiesView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Location & Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var locationSelectionView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search cities...", text: $searchText)
                    .autocapitalization(.none)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if let location = userSettings.selectedLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Current: \(location.displayName)")
                        .font(.subheadline)
                    Spacer()
                    Button("Change") {
                        Task {
                            await userSettings.selectLocation(nil)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))

                localCommunitiesSection
            } else {
                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        LocationRowView(location: location) {
                            Task {
                                await userSettings.selectLocation(location)
                            }
                            searchText = ""
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                Task {
                    await userSettings.loadCommunitiesForCity(location.city)
                }
            }
        }
    }

    private var localCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Communities in \(userSettings.selectedLocation?.city ?? "")")
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading communities...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let localCommunities = userSettings.communitiesInCity

                if localCommunities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No communities in this area yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(localCommunities) { community in
                                CommunityCardView(community: community)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private var communitiesView: some View {
        VStack(spacing: 0) {
            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Loading your communities...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                let joinedCommunities = userSettings.joinedCommunities

                if joinedCommunities.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Communities Joined")
                            .font(.headline)
                        Text("Select a location first, then join\ncommunities in your area")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { selectedTab = 0 }) {
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
                } else {
                    List {
                        ForEach(joinedCommunities) { community in
                            CommunityCardView(community: community)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onAppear {
            Task {
                await userSettings.loadMyCommunities()
            }
        }
    }
}

// MARK: - Location Row View
struct LocationRowView: View {
    let location: UserLocation
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: Community
    var onCreateEvent: (() -> Void)? = nil
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false
    @State private var showApprovalAlert = false
    @State private var showAdminDashboard = false

    var isMember: Bool {
        userSettings.isMember(of: community)
    }
    
    var isAdmin: Bool {
        userSettings.isAdmin(of: community)
    }

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 0) {
                // 1. Header Image / Gradient
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    
                    // Badges
                    HStack {
                        Spacer()
                        
                        if isMember {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Joined")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                        
                        if isAdmin {
                            Text("Admin")
                                .font(.caption.bold())
                                .badgeStyle(background: .orange)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(12)
                }
                
                // 2. Content
                VStack(alignment: .leading, spacing: 10) {
                    // Title & Member Count
                    HStack(alignment: .top) {
                        Text(community.name)
                            .font(.title3.bold())
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(community.memberCount)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(6)
                    }
                    
                    // Location
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.secondary)
                        Text(community.fullLocation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Admin Controls (Footer)
                    if isAdmin {
                        Divider()
                            .padding(.vertical, 4)
                            
                        HStack(spacing: 12) {
                            if let onCreateEvent = onCreateEvent {
                                Button(action: onCreateEvent) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Event")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: { showAdminDashboard = true }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Manage")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
            }
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }
}

// MARK: - Joined Community Row

