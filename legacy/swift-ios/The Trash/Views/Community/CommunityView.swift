//
//  CommunityView.swift
//  The Trash
//

import SwiftUI

struct CommunityView: View {
    @State private var selectedTab: CommunityTab = .events
    @EnvironmentObject var authVM: AuthViewModel

    enum CommunityTab: String, CaseIterable {
        case events = "Events"
        case groups = "Community"

        var icon: String {
            switch self {
            case .events: return "calendar.badge.clock"
            case .groups: return "person.3.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()

                VStack(spacing: 0) {
                    TrashPageHeader(title: "Community") {
                        AccountButton()
                    }

                    VStack(spacing: 0) {
                        TrashSegmentedControl(
                            options: CommunityTab.allCases.map {
                                TrashSegmentOption(
                                    value: $0,
                                    title: $0.rawValue,
                                    icon: $0.icon
                                )
                            },
                            selection: $selectedTab
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Group {
                            if selectedTab == .events {
                                EventsView()
                            } else {
                                GroupsView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
    }
}
