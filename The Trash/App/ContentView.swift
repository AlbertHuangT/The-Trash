import SwiftUI
import Supabase
import Auth

struct ContentView: View {
    @State private var selectedTab = 0
    @ObservedObject private var arenaRouter = ArenaRouter.shared

    init() {
        // Configure TabBar appearance for Neumorphism (dark mode adaptive)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        let neuColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 44/255, green: 48/255, blue: 62/255, alpha: 1)
                : UIColor(red: 224/255, green: 229/255, blue: 236/255, alpha: 1)
        }

        appearance.backgroundColor = neuColor
        appearance.shadowColor = nil // Remove top separator line for clean look

        // Apply to both standard and scrollEdge
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Configure segmented controls & nav bars
        NeumorphicAppearance.configureGlobalAppearance()
    }

    var body: some View {
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

            LeaderboardView()
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
        .onChange(of: arenaRouter.pendingChallengeId) { newValue in
            if newValue != nil {
                selectedTab = 1 // Switch to Arena tab
            }
        }
    }
}
