//
//  AccountView.swift
//  The Trash
//

import Supabase
import SwiftUI

// MARK: - Main View
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var profileVM = ProfileViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    @ObservedObject private var achievementService = AchievementService.shared
    @Environment(\.trashTheme) private var theme
    @State private var showThemeSheet = false

    // Sheets & Alerts
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showEditNameAlert = false
    @State private var newNameInput = ""
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    @State private var showDeleteAlert = false
    @State private var showDeleteNotAvailableAlert = false
    @State private var showProfileError = false
    @State private var showChangePasswordSheet = false
    @State private var verificationStatusMessage: String?
    @State private var didTriggerUCSDCheck = false
    @State private var showUpgradeSheet = false
    @State private var upgradeEmail = ""
    @State private var upgradePassword = ""
    @State private var upgradeConfirmPassword = ""

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()

                VStack(spacing: 0) {
                    // Error banner
                    if let error = profileVM.errorMessage {
                        HStack {
                            TrashIcon(systemName: "exclamationmark.triangle.fill").foregroundColor(
                                .orange)
                            Text(error).font(.caption).foregroundColor(theme.palette.textPrimary)
                            Spacer()
                            TrashIconButton(icon: "xmark", action: { profileVM.errorMessage = nil })
                        }
                        .padding(10)
                        .trashCard(cornerRadius: 10)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 1. Header
                            compactHeaderView

                            // 2. Stats dashboard
                            if !authVM.isAnonymous {
                                compactStatsView
                            } else {
                                compactGuestTeaserView
                            }

                            // 3. Quick Actions
                            quickActionsSection

                            Spacer(minLength: 40)

                            // 4. Logout & version
                            VStack(spacing: 16) {
                                TrashButton(
                                    baseColor: .red.opacity(0.1),
                                    action: { Task { await authVM.signOut() } }
                                ) {
                                    HStack(spacing: 8) {
                                        TrashIcon(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Log Out")
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }

                                HStack(spacing: 4) {
                                    TrashIcon(systemName: "leaf.fill")
                                        .font(.caption2)
                                        .foregroundColor(theme.accents.green)
                                    Text("The Trash")
                                        .font(.caption2.bold())
                                        .foregroundColor(theme.palette.textPrimary)
                                    Text("• Version 1.0.0")
                                        .font(.caption2)
                                        .foregroundColor(theme.palette.textSecondary)
                                }
                                .padding(.bottom, 20)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if let result = achievementService.lastGrantedAchievement, result.granted {
                    AchievementToastView(result: result) {
                        achievementService.dismissGrantNotification()
                    }
                }
            }
            .overlay(alignment: .top) {
                FloatingToast(message: $verificationStatusMessage)
            }
            .task {
                await profileVM.fetchProfile()
            }
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(
                    inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM,
                    isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(
                    inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet(authVM: authVM, isPresented: $showChangePasswordSheet)
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeGuestSheet(
                    authVM: authVM, email: $upgradeEmail, password: $upgradePassword,
                    confirmPassword: $upgradeConfirmPassword, isPresented: $showUpgradeSheet)
            }
            .sheet(isPresented: $showThemeSheet) {
                ThemePickerSheet(isPresented: $showThemeSheet)
            }
            .sheet(isPresented: $showEditNameAlert) {
                TrashTextInputSheet(
                    title: "Change Username",
                    message: "Pick a cool name to show to your friends!",
                    placeholder: "Enter new name",
                    text: $newNameInput,
                    confirmTitle: "Save",
                    onConfirm: { value in
                        Task { await profileVM.updateUsername(value) }
                        showEditNameAlert = false
                    }
                )
                .presentationDetents([.fraction(0.34), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .onAppear { evaluateUCSDGrant() }
        }
    }

    // MARK: - Header View
    var compactHeaderView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Avatar
                ZStack {
                    Color.clear
                        .frame(width: 68, height: 68)
                        .trashCard(cornerRadius: 34)

                    TrashIcon(
                        systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill"
                    )
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(theme.accents.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(
                            authVM.isAnonymous
                                ? "Guest"
                                : (profileVM.username.isEmpty ? "User" : profileVM.username)
                        )
                        .font(.title3.bold())
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)

                        if !authVM.isAnonymous {
                            TrashIconButton(
                                icon: "pencil",
                                action: {
                                    newNameInput = profileVM.username
                                    showEditNameAlert = true
                                })
                        }
                    }

                    if !authVM.isAnonymous {
                        HStack(spacing: 4) {
                            TrashIcon(systemName: "star.fill").font(.caption2)
                            Text(profileVM.levelName).font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor(theme.accents.blue)
                        .trashCard(cornerRadius: 13)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 120)
        .trashCard(cornerRadius: 24)
        .padding(.horizontal, 16)
    }

    // MARK: - Stats View
    var compactStatsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Credits",
                    value: "\(profileVM.credits)",
                    icon: "flame.fill",
                    color: .orange
                )

                TrashButton(baseColor: theme.accents.blue.opacity(0.08), action: handleStatusTap) {
                    StatCard(
                        title: "Status",
                        value: statusValue,
                        icon: statusIcon,
                        color: statusGradient.first ?? .gray
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Guest Teaser View
    var compactGuestTeaserView: some View {
        TrashButton(baseColor: theme.accents.blue.opacity(0.1), action: { showUpgradeSheet = true })
        {
            HStack(spacing: 14) {
                TrashIcon(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(theme.accents.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Link Account to Save Progress")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.palette.textPrimary)
                    Text("Don't lose your hard-earned credits!")
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }
                Spacer()
                TrashIcon(systemName: "chevron.right").foregroundColor(theme.palette.textSecondary)
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Quick Actions
    var quickActionsSection: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(theme.palette.textPrimary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                actionTile(icon: "lock.shield.fill", title: "Settings", color: theme.accents.blue) {
                    // Navigate to settings...
                }

                NavigationLink(destination: BadgeAchievementsHubView()) {
                    actionTile(icon: "trophy.fill", title: "Badges", color: theme.accents.green) {}
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RewardView()) {
                    actionTile(icon: "gift.fill", title: "Rewards", color: .orange) {}
                }
                .buttonStyle(.plain)

                NavigationLink(destination: TrashHistoryView()) {
                    actionTile(icon: "clock.arrow.circlepath", title: "History", color: .teal) {}
                }
                .buttonStyle(.plain)

                actionTile(icon: "paintbrush.pointed", title: "UI Style", color: .purple) {
                    showThemeSheet = true
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func actionTile(icon: String, title: String, color: Color, action: @escaping () -> Void)
        -> some View
    {
        TrashButton(baseColor: color.opacity(0.08), action: action) {
            VStack(spacing: 12) {
                if theme.visualStyle == .ecoPaper {
                    StampedIcon(systemName: icon, size: 30, weight: .bold, color: color)
                } else {
                    TrashIcon(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .trashCard(cornerRadius: 16)
        }
    }
}

// MARK: - Helpers
extension AccountView {
    private var hasLinkedEmail: Bool {
        guard let email = authVM.session?.user.email else { return false }
        return !email.isEmpty
    }
    private var emailVerified: Bool { authVM.session?.user.emailConfirmedAt != nil }
    private var isUCSDMail: Bool {
        authVM.session?.user.email?.lowercased().hasSuffix("@ucsd.edu") == true
    }
    private var statusValue: String {
        guard hasLinkedEmail else { return "Link Email" }
        return emailVerified ? "Active" : "Verify"
    }
    private var statusIcon: String {
        guard hasLinkedEmail else { return "envelope" }
        return emailVerified ? "checkmark.shield" : "exclamationmark.shield"
    }
    private var statusGradient: [Color] {
        guard hasLinkedEmail else { return [.gray] }
        return emailVerified ? [theme.accents.green] : [.orange]
    }

    private func handleStatusTap() {
        if !hasLinkedEmail {
            showBindEmailSheet = true
        } else if !emailVerified {
            Task { await authVM.resendEmailVerification() }
        }
    }

    private func evaluateUCSDGrant() {
        guard hasLinkedEmail, emailVerified, isUCSDMail, !didTriggerUCSDCheck else { return }
        didTriggerUCSDCheck = true
        Task { await achievementService.checkAndGrant(triggerKey: "ucsd_email") }
    }
}

// MARK: - Theme Style Sheet (Simplified for brevity)
struct ThemePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    @Environment(\.trashTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(ThemeOption.allCases) { option in
                        TrashButton(
                            baseColor: option.previewGradient.first?.opacity(0.12),
                            action: {
                                withAnimation { themeManager.apply(option) }
                            }
                        ) {
                            HStack {
                                TrashLabel(option.displayName, icon: option.icon)
                                Spacer()
                                if themeManager.currentOption == option {
                                    TrashIcon(systemName: "checkmark.circle.fill").foregroundColor(
                                        theme.accents.green)
                                }
                            }
                            .padding()
                            .trashCard(cornerRadius: 16)
                        }
                    }
                }
                .padding()
            }
            .background(ThemeBackground())
            .navigationTitle("Themes")
            .toolbar {
                TrashTextButton(title: "Done", variant: .accent) { isPresented = false }
            }
        }
    }
}
