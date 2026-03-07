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
                        TrashTapArea(action: {
                            if let location = userSettings.selectedLocation {
                                withAnimation {
                                    region.center = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                                    region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                }
                            }
                        }) {
                            TrashIcon(systemName: "location.fill")
                                .padding(10)
                                .background(theme.surfaceBackground)
                                .overlay(
                                    Circle()
                                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding()
                }
                Spacer()
            }

            // Selected Event Card
            if let event = selectedEvent {
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.secondary)
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)

                    EnhancedEventCard(
                        event: event,
                        userLocation: userSettings.selectedLocation,
                        preciseLocation: userSettings.preciseLocation,
                        onTap: {}
                    )
                    .allowsHitTesting(false)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                    )

                TrashIcon(systemName: event.imageSystemName)
                    .foregroundColor(event.category.color)
                    .font(.system(size: 18))
            }
            .scaleEffect(selectedEvent?.id == event.id ? 1.2 : 1.0)
            .animation(.spring(), value: selectedEvent == event)
        }}
