//
//  Smart_SortApp.swift
//  Smart Sort
//
//  Created by Albert Huang on 1/21/26.
//

import Supabase
import SwiftUI

@main
struct Smart_SortApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var trashVM = TrashViewModel(classifier: RealClassifierService.shared)
    @StateObject private var appRouter = AppRouter.shared

    init() {
        TrashTheme().configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // --- 1. Core Page Layer ---
                Group {
                    if authVM.session != nil {
                        ContentView()
                            .environmentObject(trashVM)
                            .transition(.opacity)
                    } else {
                        LoginView()
                            .transition(.opacity)
                    }
                }

                // --- 2. Global Authentication Status Overlay ---
                // Only show when status is not idle
                if authVM.deepLinkStatus != .idle {
                    DeepLinkOverlay(status: authVM.deepLinkStatus)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)  // Always on top
                }
            }
            .environmentObject(authVM)
            .environmentObject(appRouter)
            // Observe URL
            .onOpenURL { url in
                print("🔗 Received Deep Link: \(url)")
                // Try arena challenge deep link first
                if appRouter.handleDeepLink(url: url) {
                    return
                }
                Task {
                    // Pass to ViewModel for Overlay animation
                    await authVM.handleIncomingURL(url)
                }
            }
            // Add animation for smoother transitions
            .animation(.easeInOut, value: authVM.session)
            .animation(.spring(), value: authVM.deepLinkStatus)
            .onChange(of: authVM.session?.user.id) { _ in
                trashVM.reset()  // Clear Verify state when session changes (logout/login)
            }
            .preferredColorScheme(.light)
        }
    }
}

// --- 3. Extracted Stylish Overlay Component ---
struct DeepLinkOverlay: View {
    let status: AuthDeepLinkStatus
    private let theme = TrashTheme()

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                switch status {
                case .verifying:
                    ProgressView()
                    Text("Verifying email...")
                        .fontWeight(.medium)
                        .foregroundColor(theme.palette.textPrimary)

                case .success:
                    TrashIcon(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.semanticSuccess)
                        .font(.title2)
                    Text("Verified! Logging you in...")
                        .fontWeight(.bold)
                        .foregroundColor(theme.palette.textPrimary)

                case .failure(let msg):
                    TrashIcon(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.semanticDanger)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Verification Failed")
                            .fontWeight(.bold)
                        Text(msg)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .foregroundColor(theme.palette.textPrimary)

                case .idle:
                    EmptyView()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)  // Frosted glass background
            .cornerRadius(30)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
        .frame(maxHeight: .infinity, alignment: .top)  // Fixed at the top of the screen
        .padding(.top, 60)  // Avoid notch area
    }
}
