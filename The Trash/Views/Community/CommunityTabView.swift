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
                    appStoreHeader(title: "Communities")

                    if authVM.isAnonymous {
                        anonymousRestrictionView
                    } else {
                        sectionPicker

                        switch selectedSection {
                        case .nearby:
                            nearbyCommunitiesContent
                        case .joined:
                            joinedCommunitiesContent
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))

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
        .task {
            // Eagerly load joined communities to ensure Admin status is known for Nearby list
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
    }

    // MARK: - App Store Style Header
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
                    CommunityCardView(
                        community: community,
                        onCreateEvent: {
                            showCreateEventSheet = true
                        }
                    )
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.joinedCommunities) { community in
                    CommunityCardView(
                        community: community,
                        onCreateEvent: {
                            showCreateEventSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
