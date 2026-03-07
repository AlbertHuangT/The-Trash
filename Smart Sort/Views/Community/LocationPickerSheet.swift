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
    @State private var showLocationPermissionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if userSettings.locationPermissionStatus != .denied && userSettings.locationPermissionStatus != .restricted {
                    useCurrentLocationSection
                }

                TrashSearchField(placeholder: "Search cities...", text: $searchText)
                .padding(.horizontal, theme.components.contentInset)
                .padding(.vertical, theme.spacing.sm + 4)

                HStack {
                    Text("Or select a city")
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.palette.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, 8)

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
                                if userSettings.locationSyncError == nil {
                                    isPresented = false
                                } else {
                                    isSelecting = false
                                }
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
                .presentationDetents([.fraction(0.36), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appBackground)
            }
            .onChange(of: userSettings.locationPermissionStatus) { newStatus in
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    userSettings.requestCurrentLocation()
                }
            }
            .onChange(of: userSettings.preciseLocation) { newLocation in
                if let location = newLocation, !isSelecting {
                    isSelecting = true
                    Task {
                        let nearestCity = findNearestCity(to: location)
                        await userSettings.selectLocation(nearestCity)
                        if userSettings.locationSyncError == nil {
                            isPresented = false
                        } else {
                            isSelecting = false
                        }
                    }
                }
            }
            .onChange(of: userSettings.locationSyncError) { newError in
                if newError != nil {
                    isSelecting = false
                }
            }
        }
    }

    private var useCurrentLocationSection: some View {
        VStack(spacing: 0) {
            TrashTapArea(action: handleUseCurrentLocation) {
                HStack(spacing: 14) {
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

                        if userSettings.isRequestingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: theme.onAccentForeground))
                        } else {
                            TrashIcon(systemName: "location.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .trashOnAccentForeground()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use Current Location")
                            .font(theme.typography.headline)
                            .foregroundColor(theme.palette.textPrimary)

                        Text(locationSubtitle)
                            .font(.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    }

                    Spacer()

                    if userSettings.hasLocationPermission {
                        TrashIcon(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(theme.palette.textSecondary)
                    } else {
                        Text("Enable")
                            .font(.caption.bold())
                            .trashOnAccentForeground()
                            .padding(.horizontal, 12)
                            .frame(minHeight: theme.components.minimumHitTarget)
                            .background(theme.accents.blue)
                            .clipShape(RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous))
                    }
                }
                .padding(theme.components.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .fill(theme.surfaceBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                        )
                )
            }
            .disabled(userSettings.isRequestingLocation)
            .padding(.horizontal, theme.components.contentInset)
            .padding(.top, theme.components.contentInset)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, theme.components.contentInset)
                .padding(.vertical, 8)
        }
    }

    private var locationSubtitle: String {
        if let error = userSettings.locationSyncError {
            return error
        }

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
            userSettings.requestCurrentLocation()
        } else if userSettings.locationPermissionStatus == .notDetermined {
            showLocationPermissionAlert = true
        }
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
    let isDisabled: Bool
    let onTap: () -> Void
    private let theme = TrashTheme()

    var body: some View {
        TrashTapArea(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.accents.blue.opacity(0.15))
                        .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                    TrashIcon(systemName: "mappin.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.accents.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.city)
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textPrimary)
                    Text(location.state)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }

                Spacer()

                if isSelected {
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accents.green)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}
