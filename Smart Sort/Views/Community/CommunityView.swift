//
//  CommunityView.swift
//  Smart Sort
//

import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    @Environment(\.trashTheme) private var theme
    @State private var selectedTab: CommunityTab = .events

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
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.vertical, theme.layout.elementSpacing)

            Group {
                if selectedTab == .events {
                    EventsView()
                } else {
                    GroupsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .trashScreenBackground()
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !authVM.isAnonymous {
                    Button {
                        if selectedTab == .events {
                            appRouter.presentCreateEvent()
                        } else {
                            appRouter.presentCreateCommunity()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(
                                width: theme.layout.toolbarHitTarget,
                                height: theme.layout.toolbarHitTarget
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        selectedTab == .events ? "Create Event" : "Create Community"
                    )
                }

                AccountButton()
            }
        }
    }
}
