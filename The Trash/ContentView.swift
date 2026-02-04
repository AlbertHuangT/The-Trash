import SwiftUI

// 确保引入需要的模块
import Supabase
import Auth

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VerifyView()
                .tabItem { Label("Verify", systemImage: "camera.viewfinder") }
                .tag(0)
            
            FriendView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(1)
            
            ArenaView()
                .tabItem { Label("Arena", systemImage: "flame.fill") }
                .tag(2)
            
            RewardView()
                .tabItem { Label("Reward", systemImage: "gift.fill") }
                .tag(3)
            
            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle.fill") }
                .tag(4)
        }
        .accentColor(.blue)
    }
}
