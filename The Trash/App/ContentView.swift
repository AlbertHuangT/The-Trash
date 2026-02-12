import SwiftUI
import Supabase
import Auth

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

            TabView(selection: $selectedTab) {
                VerifyView()
                    .tabItem {
                        Label("Verify", systemImage: "camera.viewfinder")
                    }
                    .tag(0)

                ArenaHubView()
                    .tabItem {
                        Label("Arena", systemImage: "flame.fill")
                    }
                    .tag(1)

                LeaderboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Leaderboard", systemImage: "chart.bar.fill")
                    }
                    .tag(2)

                CommunityView()
                    .tabItem {
                        Label("Community", systemImage: "person.3.fill")
                    }
                    .tag(3)
            }
            .tint(Color.neuAccentBlue)
            .environment(\.showAccountSheet, $showAccountSheet)
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
                selectedTab = 1 // Switch to Arena tab
            }
        }
    }
}
