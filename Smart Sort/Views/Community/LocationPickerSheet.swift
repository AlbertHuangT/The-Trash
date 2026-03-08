//
//  LocationPickerSheet.swift
//  Smart Sort
//
//  Extracted from CommunityTabView.swift
//

import SwiftUI
import CoreLocation

// MARK: - Location Picker Sheet
struct LocationPickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    private let theme = TrashTheme()
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var isUsingCurrentLocation = false
    @State private var pendingLocationKey: String?
    @State private var showLocationPermissionAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                theme.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.md) {
                        if showsCurrentLocationSection {
                            useCurrentLocationSection
                        }
                        searchSection
                        resultsSection
                    }
                    .padding(.horizontal, theme.components.contentInset)
                    .padding(.top, theme.components.contentInset)
                    .padding(.bottom, theme.spacing.xxl)
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    TrashTextButton(title: "Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showLocationPermissionAlert) {
                TrashConfirmSheet(
                    title: "Enable Location Services",
                    message: "Allow location access to enable distance-based sorting for nearby events. This helps you find events closest to you.",
                    confirmTitle: "Enable",
                    confirmColor: theme.accents.blue,
                    onConfirm: {
                        userSettings.requestLocationPermission()
                        showLocationPermissionAlert = false
                    },
                    cancelTitle: "Not Now",
                    onCancel: { showLocationPermissionAlert = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: userSettings.locationPermissionStatus) { newStatus in
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    isUsingCurrentLocation = true
                    pendingLocationKey = nil
                    userSettings.requestCurrentLocation()
                }
            }
            .onChange(of: userSettings.preciseLocation) { newLocation in
                if let location = newLocation, isUsingCurrentLocation {
                    selectNearestLocation(from: location)
                }
            }
            .onChange(of: userSettings.locationSyncError) { newError in
                if newError != nil {
                    resetSelectionState()
                }
            }
        }
    }

    private var showsCurrentLocationSection: Bool {
        userSettings.locationPermissionStatus != .denied
            && userSettings.locationPermissionStatus != .restricted
    }

    private var useCurrentLocationSection: some View {
        TrashTapArea(action: handleUseCurrentLocation) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accents.blue, theme.accents.green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)

                    if userSettings.isRequestingLocation || isUsingCurrentLocation {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: theme.onAccentForeground))
                    } else {
                        TrashIcon(systemName: "location.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .trashOnAccentForeground()
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Use Current Location")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(2)

                    Text(locationSubtitle)
                        .font(theme.typography.caption)
                        .foregroundColor(locationSubtitleColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                currentLocationTrailingAccessory
                    .padding(.top, 2)
            }
            .padding(theme.components.cardPadding)
            .frame(maxWidth: .infinity, minHeight: theme.components.rowHeight + 12, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )
            )
        }
        .disabled(isCurrentLocationControlDisabled || isSelecting)
        .opacity((isCurrentLocationControlDisabled || isSelecting) ? 0.72 : 1.0)
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            TrashSearchField(placeholder: "Search cities...", text: $searchText)

            Text(searchSectionTitle)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if filteredLocations.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Matching Cities",
                    subtitle: "Try another city or state, or use your current location."
                )
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacing.sm)
            } else {
                ForEach(filteredLocations, id: \.displayName) { location in
                    LocationRow(
                        location: location,
                        isSelected: userSettings.selectedLocation == location,
                        isLoading: pendingLocationKey == location.displayName,
                        isDisabled: isSelecting
                    ) {
                        selectManualLocation(location)
                    }
                }
            }
        }
    }

    private var filteredLocations: [UserLocation] {
        PredefinedLocations.search(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var searchSectionTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Choose a city manually"
            : "Matching cities"
    }

    private var isCurrentLocationControlDisabled: Bool {
        userSettings.isRequestingLocation || isUsingCurrentLocation
    }

    private var locationSubtitleColor: Color {
        if userSettings.locationSyncError != nil {
            return theme.semanticDanger
        }

        return theme.palette.textSecondary
    }

    @ViewBuilder
    private var currentLocationTrailingAccessory: some View {
        if userSettings.isRequestingLocation || isUsingCurrentLocation {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accents.blue))
                .frame(minWidth: 74, minHeight: theme.components.minimumHitTarget, alignment: .trailing)
        } else if userSettings.hasLocationPermission {
            TrashIcon(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.palette.textSecondary)
                .frame(minWidth: 74, minHeight: theme.components.minimumHitTarget, alignment: .trailing)
        } else if userSettings.locationPermissionStatus == .notDetermined {
            Text("Enable")
                .font(theme.typography.caption.weight(.bold))
                .trashOnAccentForeground()
                .padding(.horizontal, 12)
                .frame(minWidth: 74, minHeight: theme.components.minimumHitTarget)
                .background(theme.accents.blue)
                .clipShape(RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous))
        } else {
            Text("Unavailable")
                .font(theme.typography.caption.weight(.bold))
                .foregroundColor(theme.palette.textSecondary)
                .padding(.horizontal, 12)
                .frame(minWidth: 96, minHeight: theme.components.minimumHitTarget)
                .background(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous))
        }
    }

    private var locationSubtitle: String {
        if userSettings.isRequestingLocation {
            return "Finding your precise location..."
        }

        if isUsingCurrentLocation {
            return "Saving the nearest supported city..."
        }

        if let error = userSettings.locationSyncError {
            return error
        }

        switch userSettings.locationPermissionStatus {
        case .notDetermined:
            return "Enable for distance-based event sorting"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Find the nearest city automatically"
        case .denied, .restricted:
            return "Location access is unavailable. Choose a city below."
        @unknown default:
            return "Enable for better experience"
        }
    }

    private func handleUseCurrentLocation() {
        if userSettings.hasLocationPermission {
            resetSelectionState()
            isSelecting = true
            isUsingCurrentLocation = true
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            showLocationPermissionAlert = true
        }
    }

    private func selectManualLocation(_ location: UserLocation) {
        guard !isSelecting else { return }

        resetSelectionState()
        isSelecting = true
        pendingLocationKey = location.displayName

        Task {
            await userSettings.selectLocation(location)
            if userSettings.locationSyncError == nil {
                isPresented = false
            } else {
                resetSelectionState()
            }
        }
    }

    private func selectNearestLocation(from location: CLLocation) {
        guard !isSelecting || isUsingCurrentLocation else { return }

        isSelecting = true
        pendingLocationKey = nil

        Task {
            let nearestCity = findNearestCity(to: location)
            await userSettings.selectLocation(nearestCity)
            if userSettings.locationSyncError == nil {
                isPresented = false
            } else {
                resetSelectionState()
            }
        }
    }

    private func resetSelectionState() {
        isSelecting = false
        isUsingCurrentLocation = false
        pendingLocationKey = nil
    }

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

// MARK: - Location Row
private struct LocationRow: View {
    let location: UserLocation
    let isSelected: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        TrashTapArea(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((isSelected ? theme.accents.green : theme.accents.blue).opacity(0.15))
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                    TrashIcon(systemName: "mappin.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSelected ? theme.accents.green : theme.accents.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.city)
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(location.state)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: theme.accents.blue))
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                } else if isSelected {
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accents.green)
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                } else {
                    TrashIcon(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.palette.textSecondary.opacity(0.7))
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                }
            }
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.vertical, theme.spacing.sm)
            .frame(maxWidth: .infinity, minHeight: theme.components.rowHeight + 8, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(
                                isSelected ? theme.interactiveStroke : theme.palette.divider.opacity(0.85),
                                lineWidth: 1
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}
