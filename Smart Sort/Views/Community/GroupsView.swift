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
    @State private var showSecondaryControls = false
    private let theme = TrashTheme()

    var body: some View {
        VStack(spacing: 0) {
            if authVM.isAnonymous {
                anonymousRestrictionView
            } else {
                controlBar

                if showSecondaryControls {
                    secondaryControls
                }

                switch selectedSection {
                case .nearby:
                    nearbyCommunitiesContent
                case .joined:
                    joinedCommunitiesContent
                }
            }
        }
        .trashScreenBackground()
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

                    Text(userSettings.selectedLocation?.displayName ?? "Select your city")
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
    }

    private var secondaryControls: some View {
        TrashSegmentedControl(
            options: CommunityTabSection.allCases.map {
                TrashSegmentOption(value: $0, title: $0.rawValue, icon: $0.icon)
            },
            selection: $selectedSection
        )
        .padding(.horizontal, theme.layout.screenInset)
        .padding(.bottom, theme.layout.elementSpacing)
        .transition(.move(edge: .top).combined(with: .opacity))
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
        VStack(spacing: theme.layout.sectionSpacing) {
            Spacer()
            paperBadge(icon: "location.slash.fill", size: 104, iconColor: theme.accents.blue)
            Text("No Location Set")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)
            TrashButton(baseColor: theme.accents.blue, action: { showLocationPicker = true }) {
                Text("Select Location")
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
        VStack(spacing: theme.layout.sectionSpacing) {
            Spacer()
            paperBadge(
                icon: "building.2.crop.circle", size: 96, iconColor: theme.palette.textSecondary)
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
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.elementSpacing)
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
        VStack(spacing: theme.layout.sectionSpacing) {
            Spacer()
            paperBadge(icon: "person.3.fill", size: 96, iconColor: theme.palette.textSecondary)
            Text("No Communities Joined").font(theme.typography.headline)
            TrashButton(baseColor: theme.accents.blue, action: { selectedSection = .nearby }) {
                Text("Browse Nearby")
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
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.elementSpacing)
        }
        .refreshable {
            await userSettings.loadMyCommunities()
        }
    }

    // MARK: - Anonymous Restriction View
    private var anonymousRestrictionView: some View {
        VStack(spacing: 24) {
            Spacer()
            paperBadge(icon: "lock.shield.fill", size: 104, iconColor: theme.accents.blue)
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
