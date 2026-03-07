//
//  GroupsView.swift
//  Smart Sort
//

import CoreLocation
import SwiftUI

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

struct GroupsView: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    @State private var selectedSection: CommunityTabSection = .nearby
    @State private var showLocationPicker = false
    @State private var showCreateEventSheet = false
    @State private var showCreateCommunitySheet = false
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 0) {
            if authVM.isAnonymous {
                anonymousRestrictionView
            } else {
                controlBar

                switch selectedSection {
                case .nearby:
                    nearbyCommunitiesContent
                case .joined:
                    joinedCommunitiesContent
                }
            }
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
            if userSettings.joinedCommunities.isEmpty {
                await userSettings.loadMyCommunities()
            }
        }
        .onChange(of: appRouter.activeSheet) { sheet in
            guard sheet == .createCommunity, !authVM.isAnonymous else { return }
            showCreateCommunitySheet = true
            appRouter.dismissSheet()
        }
    }

    // MARK: - Control Bar
    private var controlBar: some View {
        HStack {
            // Location Button
            TrashButton(
                baseColor: theme.accents.blue.opacity(0.15),
                cornerRadius: 16,
                action: { showLocationPicker = true }
            ) {
                HStack(spacing: 6) {
                    TrashIcon(
                        systemName: userSettings.selectedLocation == nil
                            ? "location.slash" : "location.fill"
                    )
                    .font(.caption)
                    Text(userSettings.selectedLocation?.city ?? "Select Location")
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                }
                .foregroundColor(theme.accents.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Toggle chip (Nearby / Joined)
            TrashButton(
                baseColor: selectedSection == .joined ? theme.accents.green : nil,
                cornerRadius: 16,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = (selectedSection == .nearby) ? .joined : .nearby
                    }
                }
            ) {
                HStack(spacing: 4) {
                    TrashIcon(systemName: selectedSection == .joined ? "person.3.fill" : "globe")
                        .font(.caption)
                    Text(selectedSection == .joined ? "Joined" : "Nearby")
                        .font(.caption.bold())
                }
                .foregroundColor(
                    selectedSection == .joined
                        ? theme.onAccentForeground : theme.palette.textSecondary
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Nearby Communities Content
    @ViewBuilder
    private var nearbyCommunitiesContent: some View {
        VStack(spacing: 0) {
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
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty
            {
                await userSettings.loadCommunitiesForCity(location.city)
            }
        }
    }

    private var noLocationView: some View {
        VStack(spacing: 20) {
            Spacer()
            paperBadge(icon: "location.slash.fill", size: 120, iconColor: theme.accents.blue)
            Text("No Location Set")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)
            TrashButton(baseColor: theme.accents.blue, action: { showLocationPicker = true }) {
                Text("Select Location")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(theme.accents.blue)
            Text("Loading...").foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    private var emptyNearbyView: some View {
        VStack(spacing: 20) {
            Spacer()
            paperBadge(
                icon: "building.2.crop.circle", size: 110, iconColor: theme.palette.textSecondary)
            Text("No Communities Yet").font(theme.typography.headline)
            Spacer()
        }
    }

    private var nearbyCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.communitiesInCity) { community in
                    CommunityCardView(
                        community: community, onCreateEvent: { showCreateEventSheet = true })
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
    }

    private var emptyJoinedView: some View {
        VStack(spacing: 20) {
            Spacer()
            paperBadge(icon: "person.3.fill", size: 110, iconColor: theme.palette.textSecondary)
            Text("No Communities Joined").font(theme.typography.headline)
            TrashButton(baseColor: theme.accents.blue, action: { selectedSection = .nearby }) {
                Text("Browse Nearby").padding(.horizontal, 24).padding(.vertical, 12)
            }
            Spacer()
        }
    }

    private var joinedCommunitiesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(userSettings.joinedCommunities) { community in
                    CommunityCardView(
                        community: community, onCreateEvent: { showCreateEventSheet = true })
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
            paperBadge(icon: "lock.shield.fill", size: 120, iconColor: theme.accents.blue)
            Text("Access Restricted").font(theme.typography.headline)
            Text("Please link your account to join communities.").multilineTextAlignment(.center)
                .padding(.horizontal, 32).foregroundColor(theme.palette.textSecondary)
            Spacer()
        }
    }

    @ViewBuilder
    private func paperBadge(icon: String, size: CGFloat, iconColor: Color) -> some View {
        ZStack {
            Color.clear
                .frame(width: size, height: size)
                .surfaceCard(cornerRadius: size / 2)

            StampedIcon(systemName: icon, size: size * 0.45, weight: .bold, color: iconColor)
        }
    }
}
