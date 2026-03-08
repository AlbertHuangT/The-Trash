//
//  EventsMapView.swift
//  Smart Sort
//
//  Created by Albert Huang on 2/6/26.
//

import SwiftUI
import MapKit

struct EventsMapView: View {
    let events: [CommunityEvent]
    @ObservedObject var userSettings: UserSettings
    let onEventSelected: (CommunityEvent) -> Void
    private let theme = TrashTheme()

    @State private var region: MKCoordinateRegion

    @State private var dragOffset = CGSize.zero
    @State private var selectedEvent: CommunityEvent? = nil
    @State private var isDragging = false

    init(events: [CommunityEvent], userSettings: UserSettings, onEventSelected: @escaping (CommunityEvent) -> Void) {
        self.events = events
        self.userSettings = userSettings
        self.onEventSelected = onEventSelected

        let center: CLLocationCoordinate2D
        if let location = userSettings.selectedLocation {
            center = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        } else {
            center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map View
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: events) { event in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)) {
                    eventMarker(event)
                        .onTapGesture {
                            withAnimation {
                                selectedEvent = event
                                region.center = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
                            }
                        }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Map Controls (Custom implementation for older iOS)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        TrashIconButton(icon: "location.fill") {
                            if let location = userSettings.selectedLocation {
                                withAnimation {
                                    region.center = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                                    region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                }
                            }
                        }
                    }
                    .padding(theme.layout.screenInset)
                }
                Spacer()
            }

            // Selected Event Card
            if let event = selectedEvent {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(theme.palette.textSecondary.opacity(0.45))
                        .frame(width: 40, height: 6)
                        .padding(.top, 8)

                    selectedEventSummary(event)
                    .allowsHitTesting(false)
                    .padding(.horizontal, theme.layout.screenInset)
                    .padding(.bottom, theme.layout.sectionSpacing)
                }
                .contentShape(Rectangle())
                .offset(y: max(0, dragOffset.height))
                .transition(.move(edge: .bottom))
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                // Animate off-screen
                                withAnimation(.easeOut(duration: 0.3)) {
                                    dragOffset = CGSize(width: 0, height: 1000)
                                }

                                // Reset state after animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    selectedEvent = nil
                                    // Reset offset without animation so it's ready for next time
                                    dragOffset = .zero
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isDragging = false
                            }
                        }
                )
                .onTapGesture {
                    if !isDragging {
                        onEventSelected(event)
                    }
                }
                .id(event.id)
            }
        }
        .onChange(of: selectedEvent) { newValue in
            if let event = newValue {
                withAnimation {
                    region.center = CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
                }
            }
        }
    }

    private func eventMarker(_ event: CommunityEvent) -> some View {
        ZStack {
            Circle()
                .fill(theme.surfaceBackground)
                .frame(
                    width: theme.components.minimumHitTarget,
                    height: theme.components.minimumHitTarget
                )
                .overlay(
                    Circle()
                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                )

            TrashIcon(systemName: event.imageSystemName)
                .foregroundColor(event.category.color)
                .font(.system(size: 17, weight: .semibold))
        }
        .scaleEffect(selectedEvent?.id == event.id ? 1.08 : 1.0)
        .shadow(
            color: selectedEvent?.id == event.id ? event.category.color.opacity(0.22) : .clear,
            radius: 8
        )
        .animation(.spring(), value: selectedEvent == event)
    }

    private func selectedEventSummary(_ event: CommunityEvent) -> some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            HStack(alignment: .top, spacing: theme.layout.rowContentSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .fill(theme.palette.card)
                        .frame(width: 48, height: 48)

                    TrashIcon(systemName: event.imageSystemName)
                        .foregroundColor(event.category.color)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(theme.typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(2)

                    Text(event.location)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: theme.spacing.sm)

                TrashPill(
                    title: event.category.rawValue.capitalized,
                    color: event.category.color,
                    isSelected: false
                )
            }

            Text(event.description)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
                .lineLimit(2)
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }
}
