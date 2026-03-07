import Auth
import Supabase
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter

    var body: some View {
        ZStack {
            ThemeBackgroundView()
            
            TabView(selection: $appRouter.selectedTab) {
            NavigationStack {
                VerifyView()
            }
            .tabItem {
                Label("Verify", systemImage: "camera")
            }
            .tag(AppRouter.Tab.verify)

            ArenaHubView()
                .tabItem {
                    Label("Arena", systemImage: "flag.checkered")
                }
                .tag(AppRouter.Tab.arena)

            NavigationStack {
                LeaderboardView()
            }
            .tabItem {
                Label("Leaderboard", systemImage: "chart.bar")
            }
            .tag(AppRouter.Tab.leaderboard)

            NavigationStack {
                CommunityView()
            }
            .tabItem {
                Label("Community", systemImage: "person.3")
            }
            .tag(AppRouter.Tab.community)
        }
        .sheet(
            isPresented: Binding(
                get: { appRouter.activeSheet == .account },
                set: { isPresented in
                    if !isPresented && appRouter.activeSheet == .account {
                        appRouter.dismissSheet()
                    }
                }
            )
        ) {
            AccountView()
                .environmentObject(authVM)
                .environmentObject(appRouter)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        }
    }
}
