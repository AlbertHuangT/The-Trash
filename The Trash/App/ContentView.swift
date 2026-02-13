import Auth
import Supabase
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAccountSheet = false
    @ObservedObject private var arenaRouter = ArenaRouter.shared
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme

    var body: some View {
        ZStack {
            ThemeBackgroundView()
                .ignoresSafeArea()

            GeometryReader { proxy in
                tabContent
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .clipped()
                    .environment(\.showAccountSheet, $showAccountSheet)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TrashBottomTabBar(items: tabItems, selection: $selectedTab)
                .tint(Color(uiColor: theme.appearance.tabBarSelectedTint))
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(theme.appearance.sheetBackground)
        }
        .onChange(of: arenaRouter.pendingChallengeId) { newValue in
            if newValue != nil {
                selectedTab = 1  // Switch to Arena tab
            }
        }
    }

    private var tabItems: [TrashTabItem<Int>] {
        [
            TrashTabItem(value: 0, title: "Verify", icon: "camera.viewfinder"),
            TrashTabItem(value: 1, title: "Arena", icon: "flame.fill"),
            TrashTabItem(value: 2, title: "Leaderboard", icon: "chart.bar.fill"),
            TrashTabItem(value: 3, title: "Community", icon: "person.3.fill"),
        ]
    }

    private var tabContent: some View {
        Group {
            if selectedTab == 0 {
                VerifyView()
            } else if selectedTab == 1 {
                ArenaHubView()
            } else if selectedTab == 2 {
                LeaderboardView(selectedTab: $selectedTab)
            } else {
                CommunityView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
