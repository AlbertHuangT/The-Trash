//
//  ArenaHubView.swift
//  The Trash
//
//  Arena game hub — mode selection screen.
//

import SwiftUI
import Supabase
import Combine

struct ArenaHubView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var arenaRouter = ArenaRouter.shared
    @State private var showAccountSheet = false
    @State private var navigationPath = NavigationPath()
    @State private var showChallengeList = false
    @State private var showInviteSheet = false
    @State private var showAcceptView = false
    @State private var pendingBadgeCount = 0

    // Polling timer for pending challenges
    @State private var pollTimer: AnyCancellable?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.neuBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with challenge inbox button
                    HStack(alignment: .center) {
                        Text("Arena")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundColor(.neuText)

                        Spacer()

                        // Challenge inbox button
                        if !authViewModel.isAnonymous {
                            Button(action: { showChallengeList = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "tray.fill")
                                        .font(.title2)
                                        .foregroundColor(.neuText)

                                    if pendingBadgeCount > 0 {
                                        Text("\(pendingBadgeCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            .padding(.trailing, 8)
                        }

                        AccountButton(showAccountSheet: $showAccountSheet)
                            .environmentObject(authViewModel)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    if authViewModel.isAnonymous {
                        EnhancedAnonymousRestrictionView()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                // Mode cards grid
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(ArenaGameMode.allCases) { mode in
                                        GameModeCard(mode: mode) {
                                            if mode == .duel {
                                                showInviteSheet = true
                                            } else if mode.isAvailable {
                                                navigationPath.append(mode)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                Spacer(minLength: 40)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationDestination(for: ArenaGameMode.self) { mode in
                switch mode {
                case .classic:
                    ArenaView()
                        .navigationBarHidden(true)
                case .speedSort:
                    SpeedSortView()
                        .navigationBarHidden(true)
                case .streak:
                    StreakModeView()
                        .navigationBarHidden(true)
                case .dailyChallenge:
                    DailyChallengeView()
                        .navigationBarHidden(true)
                case .duel:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showChallengeList) {
            ChallengeListView()
        }
        .sheet(isPresented: $showInviteSheet) {
            ChallengeInviteSheet()
        }
        .sheet(isPresented: $showAcceptView) {
            if let challengeId = arenaRouter.pendingChallengeId {
                ChallengeAcceptView(challengeId: challengeId) {
                    showAcceptView = false
                    arenaRouter.clearPending()
                }
            }
        }
        .onAppear {
            startPolling()
        }
        .onDisappear {
            pollTimer?.cancel()
        }
        .onChange(of: arenaRouter.pendingChallengeId) { newValue in
            if newValue != nil {
                showAcceptView = true
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        guard !authViewModel.isAnonymous else { return }

        // Initial fetch
        Task { await fetchPendingCount() }

        // Poll every 30 seconds
        pollTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { await fetchPendingCount() }
            }
    }

    private func fetchPendingCount() async {
        do {
            let challenges = try await ArenaService.shared.getMyChallenges(status: "pending")
            let myId = SupabaseManager.shared.client.auth.currentUser?.id
            // Only count challenges where I'm the opponent (incoming)
            pendingBadgeCount = challenges.filter { $0.opponentId == myId }.count
        } catch {
            // Silently fail for polling
        }
    }
}

// MARK: - Game Mode Card

struct GameModeCard: View {
    let mode: ArenaGameMode
    let onTap: () -> Void

    @State private var isPressed = false

    private var gradient: LinearGradient {
        let colors: [Color] = {
            switch mode {
            case .classic: return [.neuAccentBlue, .cyan]
            case .speedSort: return [.orange, .yellow]
            case .streak: return [.purple, .pink]
            case .dailyChallenge: return [.green, .mint]
            case .duel: return [.red, .orange]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.neuBackground)
                        .frame(width: 60, height: 60)
                        .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                        .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)

                    if mode.isAvailable {
                        Image(systemName: mode.icon)
                            .font(.system(size: 26))
                            .foregroundStyle(gradient)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.neuSecondaryText)
                    }
                }

                Text(mode.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.neuText)
                    .multilineTextAlignment(.center)

                Text(mode.isAvailable ? mode.subtitle : "Coming Soon")
                    .font(.caption2)
                    .foregroundColor(.neuSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(Color.neuBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: isPressed ? .clear : .neuDarkShadow, radius: 10, x: 8, y: 8)
            .shadow(color: isPressed ? .clear : .neuLightShadow, radius: 10, x: -5, y: -5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        mode.isAvailable ? gradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: mode.isAvailable ? 1.5 : 0
                    )
                    .opacity(0.3)
            )
            .opacity(mode.isAvailable ? 1.0 : 0.6)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
