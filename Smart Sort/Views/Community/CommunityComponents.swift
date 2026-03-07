//
//  CommunityComponents.swift
//  Smart Sort
//

import SwiftUI

// MARK: - Community Selection Sheet
struct CommunitySelectionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var selectedTab = 0
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TrashSegmentedControl(
                    options: [
                        TrashSegmentOption(value: 0, title: "Location", icon: "location.fill"),
                        TrashSegmentOption(
                            value: 1, title: "My Communities", icon: "person.3.fill"),
                    ],
                    selection: $selectedTab
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if selectedTab == 0 {
                    locationSelectionView
                } else {
                    communitiesView
                }
            }
            .navigationTitle("Location & Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    TrashTextButton(title: "Done", variant: .accent) {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var locationSelectionView: some View {
        VStack(spacing: 0) {
            TrashSearchField(placeholder: "Search cities...", text: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if let location = userSettings.selectedLocation {
                HStack {
                    TrashIcon(systemName: "location.fill")
                        .foregroundColor(theme.accents.blue)
                    Text("Current: \(location.displayName)")
                        .font(.subheadline)
                        .foregroundColor(theme.palette.textPrimary)
                    Spacer()
                    TrashPill(
                        title: "Change", icon: "arrow.triangle.2.circlepath",
                        color: theme.accents.blue
                    ) {
                        Task { await userSettings.selectLocation(nil) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .surfaceCard(cornerRadius: 12)

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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .onAppear {
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty
            {
                Task {
                    await userSettings.loadCommunitiesForCity(location.city)
                }
            }
        }
    }

    private var localCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrashSectionTitle(title: "Communities in \(userSettings.selectedLocation?.city ?? "")")
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading communities...")
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let localCommunities = userSettings.communitiesInCity

                if localCommunities.isEmpty {
                    VStack(spacing: 12) {
                        TrashIcon(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(theme.palette.textSecondary)
                        Text("No communities in this area yet")
                            .font(.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
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
                        .foregroundColor(theme.palette.textSecondary)
                    Spacer()
                }
            } else {
                let joinedCommunities = userSettings.joinedCommunities

                if joinedCommunities.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        TrashIcon(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(theme.palette.textSecondary)
                        Text("No Communities Joined")
                            .font(.headline)
                            .foregroundColor(theme.palette.textPrimary)
                        Text("Select a location first, then join\ncommunities in your area")
                            .font(.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
                            .multilineTextAlignment(.center)

                        TrashButton(baseColor: theme.accents.blue, action: { selectedTab = 0 }) {
                            Text("Select Location")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
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
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
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
    private let theme = TrashTheme()

    var body: some View {
        TrashTapArea(action: onSelect) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        TrashIcon(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accents.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.city)
                        .font(.subheadline.bold())
                        .foregroundColor(theme.palette.textPrimary)
                    Text(location.state)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }

                Spacer()

                TrashIcon(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
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
    private let theme = TrashTheme()

    var isMember: Bool {
        userSettings.isMember(of: community)
    }

    var isAdmin: Bool {
        userSettings.isAdmin(of: community)
    }

    var body: some View {
        TrashTapArea(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                        )
                        .frame(height: 120)
                        .overlay(
                            TrashIcon(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(theme.palette.textSecondary.opacity(0.25))
                        )

                    HStack {
                        Spacer()
                        if isMember {
                            pillBadge(
                                icon: "checkmark.circle.fill", text: "Joined",
                                foreground: theme.accents.green)
                        }
                        if isAdmin {
                            Text("Admin")
                                .font(.caption.bold())
                                .badgeStyle(background: .orange)
                        }
                    }
                    .padding(12)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        Text(community.name)
                            .font(theme.typography.headline)
                            .lineLimit(2)
                            .foregroundColor(theme.palette.textPrimary)

                        Spacer()

                        HStack(spacing: 4) {
                            TrashIcon(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(community.memberCount)")
                                .font(theme.typography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(theme.palette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.surfaceBackground)
                        )
                    }

                    HStack(spacing: 6) {
                        TrashIcon(systemName: "mappin.and.ellipse")
                            .foregroundColor(theme.palette.textSecondary)
                        Text(community.fullLocation)
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
                    }

                    if !community.description.isEmpty {
                        Text(community.description)
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.palette.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isAdmin {
                        theme.palette.divider.frame(height: 1)
                            .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            if let onCreateEvent = onCreateEvent {
                                TrashButton(baseColor: theme.accents.green, action: onCreateEvent) {
                                    HStack {
                                        TrashIcon(systemName: "plus.circle.fill")
                                        Text("Event")
                                    }
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                }
                            }

                            TrashButton(
                                baseColor: theme.semanticWarning.opacity(0.18),
                                action: { showAdminDashboard = true }
                            ) {
                                HStack {
                                    TrashIcon(systemName: "gearshape.fill")
                                    Text("Manage")
                                }
                                .foregroundColor(theme.semanticWarning)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .surfaceCard(cornerRadius: 16)
        }
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }

    @ViewBuilder
    private func pillBadge(icon: String, text: String, foreground: Color) -> some View {
        HStack(spacing: 4) {
            TrashIcon(systemName: icon)
            Text(text)
        }
        .font(theme.typography.caption)
        .fontWeight(.bold)
        .foregroundColor(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(theme.surfaceBackground)
        )
    }
}
