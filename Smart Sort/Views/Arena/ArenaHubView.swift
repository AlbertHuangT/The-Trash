//
//  ArenaHubView.swift
//  Smart Sort
//
//  Arena game hub — mode selection screen.
//

import Combine
import Supabase
import SwiftUI

struct ArenaHubView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject private var appRouter: AppRouter
    // showAccountSheet managed by ContentView via environment
    @State private var navigationPath = NavigationPath()
    @State private var showChallengeList = false
    @State private var showInviteSheet = false
    @State private var showAcceptView = false
    @State private var showDuel = false
    @State private var activeOpponentId: UUID?
    @State private var pendingOpponentId: UUID?
    @State private var pendingBadgeCount = 0
    private let theme = TrashTheme()

    // Polling timer for pending challenges
    @State private var pollTimer: AnyCancellable?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if authViewModel.isAnonymous {
                    EnhancedAnonymousRestrictionView()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: theme.spacing.md
                            ) {
                                ForEach(ArenaGameMode.allCases) { mode in
                                    GameModeCard(mode: mode) {
                                        if mode == .duel {
                                            showInviteSheet = true
                                        } else {
                                            navigationPath.append(mode)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, theme.layout.screenInset)

                            Spacer(minLength: 40)
                        }
                        .padding(.top, theme.layout.elementSpacing)
                        .padding(.bottom, theme.spacing.xxl)
                    }
                }
            }
            .trashScreenBackground()
            .navigationTitle("Arena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !authViewModel.isAnonymous {
                        ZStack(alignment: .topTrailing) {
                            Button {
                                showChallengeList = true
                            } label: {
                                Image(systemName: "tray")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(
                                        width: theme.layout.toolbarHitTarget,
                                        height: theme.layout.toolbarHitTarget
                                    )
                            }
                            .buttonStyle(.plain)

                            if pendingBadgeCount > 0 {
                                Text("\(pendingBadgeCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.red, in: Capsule())
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    AccountButton()
                }
            }
            .navigationDestination(for: ArenaGameMode.self) { mode in
                switch mode {
                case .classic:
                    ArenaView()
                case .speedSort:
                    SpeedSortView()
                case .streak:
                    StreakModeView()
                case .dailyChallenge:
                    DailyChallengeView()
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
            if let challengeId = appRouter.pendingChallengeId {
                ChallengeAcceptView(challengeId: challengeId) {
                    showAcceptView = false
                    appRouter.clearPendingChallenge()
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
        .onChange(of: appRouter.pendingChallengeId) { newValue in
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
    private let theme = TrashTheme()

    private var gradient: LinearGradient {
        let colors: [Color] = {
            switch mode {
            case .classic: return [.blue, .purple]
            case .speedSort: return [.orange, .green]
            case .streak: return [.purple, .blue]
            case .dailyChallenge: return [.green, .blue]
            case .duel: return [.red, .orange]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: theme.spacing.md) {
                let circleSize = theme.components.minimumHitTarget
                ZStack {
                    Circle()
                        .frame(width: circleSize, height: circleSize)
                        .foregroundStyle(theme.surfaceBackground)

                    Image(systemName: mode.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconAccentColor)
                }

                Text(mode.title)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(mode.subtitle)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 168)
            .padding(.vertical, theme.spacing.md)
            .padding(.horizontal, theme.spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(theme.surfaceBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                            .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .stroke(gradient, lineWidth: 1.25)
                    .opacity(0.28)
            )
        }
        .buttonStyle(GameModeCardButtonStyle())
        .accessibilityLabel("\(mode.title): \(mode.subtitle)")
    }

    private var iconAccentColor: Color {
        switch mode {
        case .classic: return .blue
        case .speedSort: return .orange
        case .streak: return .purple
        case .dailyChallenge: return .green
        case .duel: return .red
        }
    }
}

/// Provides press-down scale animation for GameModeCard
private struct GameModeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
