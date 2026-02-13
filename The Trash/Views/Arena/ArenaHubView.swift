//
//  ArenaHubView.swift
//  The Trash
//
//  Arena game hub — mode selection screen.
//

import Combine
import Supabase
import SwiftUI

struct ArenaHubView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var arenaRouter = ArenaRouter.shared
    @Environment(\.trashTheme) private var theme
    // showAccountSheet managed by ContentView via environment
    @State private var navigationPath = NavigationPath()
    @State private var showChallengeList = false
    @State private var showInviteSheet = false
    @State private var showAcceptView = false
    @State private var showDuel = false
    @State private var activeOpponentId: UUID?
    @State private var pendingOpponentId: UUID?
    @State private var pendingBadgeCount = 0

    // Polling timer for pending challenges
    @State private var pollTimer: AnyCancellable?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemeBackground()

                VStack(spacing: 0) {
                    TrashPageHeader(title: "Arena") {
                        HStack(spacing: theme.spacing.sm) {
                            if !authViewModel.isAnonymous {
                                ZStack(alignment: .topTrailing) {
                                    TrashIconButton(
                                        icon: "tray.fill", action: { showChallengeList = true })

                                    if pendingBadgeCount > 0 {
                                        Text("\(pendingBadgeCount)")
                                            .font(.system(size: 10, weight: .bold))
                                            .trashOnAccentForeground()
                                            .padding(4)
                                            .background(theme.semanticDanger)
                                            .clipShape(Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                            }
                            AccountButton()
                        }
                    }

                    if authViewModel.isAnonymous {
                        EnhancedAnonymousRestrictionView()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: theme.spacing.xl) {
                                // Mode cards grid
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: theme.spacing.lg
                                ) {
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
                                .padding(.horizontal, theme.spacing.lg)

                                Spacer(minLength: theme.spacing.xxl)
                            }
                            .padding(.top, theme.spacing.sm)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
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
        .sheet(isPresented: $showInviteSheet, onDismiss: handleInviteDismiss) {
            ChallengeInviteSheet { opponentId in
                pendingOpponentId = opponentId
                showInviteSheet = false
            }
        }
        .sheet(isPresented: $showAcceptView) {
            if let challengeId = arenaRouter.pendingChallengeId {
                ChallengeAcceptView(challengeId: challengeId) {
                    showAcceptView = false
                    arenaRouter.clearPending()
                }
            }
        }
        .fullScreenCover(isPresented: $showDuel) {
            if let opponentId = activeOpponentId {
                DuelView(challengeId: nil, opponentId: opponentId, isAccepting: false)
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

    private func handleInviteDismiss() {
        guard let opponentId = pendingOpponentId else { return }
        pendingOpponentId = nil
        activeOpponentId = opponentId
        showDuel = true
    }

    // MARK: - Polling

    private func startPolling() {
        guard !authViewModel.isAnonymous else { return }

        // Cancel any existing timer to prevent duplicates
        pollTimer?.cancel()

        // Initial fetch
        Task { await fetchPendingCount() }

        // Poll every 10 seconds (challenges expire after 1 minute)
        pollTimer = Timer.publish(every: 10, on: .main, in: .common)
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
    @Environment(\.trashTheme) private var theme

    private var gradient: LinearGradient {
        let colors: [Color] = {
            switch mode {
            case .classic: return [theme.accents.blue, theme.accents.purple]
            case .speedSort: return [theme.accents.orange, theme.accents.green]
            case .streak: return [theme.accents.purple, theme.accents.blue]
            case .dailyChallenge: return [theme.accents.green, theme.accents.blue]
            case .duel: return [.red, .orange]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        TrashTapArea(action: onTap) {
            VStack(spacing: theme.spacing.md) {
                let circleSize = theme.spacing.xl * 1.5
                ZStack {
                    Circle()
                        .frame(width: circleSize, height: circleSize)
                        .trashCard(cornerRadius: circleSize)  // Use TrashCard for consistent shadow

                    if mode.isAvailable {
                        if theme.visualStyle == .ecoPaper {
                            StampedIcon(
                                systemName: mode.icon, size: 32, weight: .semibold,
                                color: iconAccentColor)
                        } else {
                            TrashIcon(systemName: mode.icon)
                                .font(theme.typography.headline)
                                .foregroundStyle(iconAccentColor)
                        }
                    } else {
                        if theme.visualStyle == .ecoPaper {
                            StampedIcon(
                                systemName: "lock.fill", size: 32, weight: .semibold,
                                color: theme.palette.textSecondary)
                        } else {
                            TrashIcon(systemName: "lock.fill")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.palette.textSecondary)
                        }
                    }
                }

                Text(mode.title)
                    .font(theme.typography.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(mode.isAvailable ? mode.subtitle : "Coming Soon")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.xl)
            .padding(.horizontal, theme.spacing.sm)
            .trashCard(cornerRadius: theme.corners.medium)
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.medium)
                    .stroke(
                        mode.isAvailable
                            ? gradient
                            : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: mode.isAvailable ? 1.5 : 0
                    )
                    .opacity(0.3)
            )
            .opacity(mode.isAvailable ? 1.0 : 0.6)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .onLongPressGesture(
            minimumDuration: .infinity,
            pressing: { pressing in
                withAnimation(.easeOut(duration: 0.15)) {
                    isPressed = pressing
                }
            }, perform: {})
    }

    private var iconAccentColor: Color {
        switch mode {
        case .classic: return theme.accents.blue
        case .speedSort: return theme.accents.orange
        case .streak: return theme.accents.purple
        case .dailyChallenge: return theme.accents.green
        case .duel: return Color.red
        }
    }
}
