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
                            JoinedCommunityRow(community: community)
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
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false
    @State private var showApprovalAlert = false

    var isMember: Bool {
        userSettings.isMember(of: community)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showDetail = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
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
            .sheet(isPresented: $showDetail) {
                CommunityDetailView(community: community)
            }

            Button(action: { showDetail = true }) {
                Text(community.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: {
                Task {
                    isLoading = true
                    if isMember {
                        _ = await userSettings.leaveCommunity(community)
                    } else {
                        let result = await userSettings.joinCommunity(community)
                        if result.requiresApproval {
                            showApprovalAlert = true
                        }
                    }
                    isLoading = false
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isMember ? "checkmark.circle.fill" : "plus.circle.fill")
                    }
                    Text(isMember ? "Joined" : "Join Community")
                }
                .font(.subheadline.bold())
                .foregroundColor(isMember ? .green : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isMember ? Color.green.opacity(0.1) : Color.cyan)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .alert("Application Submitted", isPresented: $showApprovalAlert) {
            Button("OK") {}
        } message: {
            Text("Your request to join has been submitted. An admin will review it shortly.")
        }
    }
}

// MARK: - Joined Community Row
struct JoinedCommunityRow: View {
    let community: Community
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label(community.fullLocation, systemImage: "mappin.circle.fill")
                        Label("\(community.memberCount)", systemImage: "person.2.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    Task {
                        isLoading = true
                        _ = await userSettings.leaveCommunity(community)
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Leave")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
    }
}

// MARK: - Joined Community Row with Admin Features
struct JoinedCommunityRowExpanded: View {
    let community: Community
    let onCreateEvent: () -> Void
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false
    @State private var showAdminDashboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            HStack(spacing: 12) {
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

                    Button(action: { showAdminDashboard = true }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Manage")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

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
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }
}
