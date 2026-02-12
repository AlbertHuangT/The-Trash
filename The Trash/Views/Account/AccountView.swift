//
//  AccountView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase

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
        NavigationView {
            VStack(spacing: 0) {
                // Error banner
                if let error = profileVM.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.neuText)
                        Spacer()
                        Button(action: { profileVM.errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.neuSecondaryText)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: profileVM.errorMessage)
                }

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

                Spacer()

                // 4. Logout & version
                VStack(spacing: 12) {
                    Button(action: { Task { await authVM.signOut() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.bold())
                            Text("Log Out")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.neuBackground)
                                .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                                .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
                        )
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundColor(.neuAccentGreen)
                        Text("The Trash")
                            .font(.caption2.bold())
                            .foregroundColor(.neuText)
                        Text("• Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.neuSecondaryText)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(
                ThemeBackgroundView()
                    .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .overlay {
                // 成就解锁 Toast 通知
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
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordSheet(authVM: authVM, isPresented: $showChangePasswordSheet)
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeGuestSheet(
                    authVM: authVM,
                    email: $upgradeEmail,
                    password: $upgradePassword,
                    confirmPassword: $upgradeConfirmPassword,
                    isPresented: $showUpgradeSheet
                )
            }
            .sheet(isPresented: $showThemeSheet) {
                ThemePickerSheet(isPresented: $showThemeSheet)
            }
            .alert("Change Username", isPresented: $showEditNameAlert) {
                TextField("Enter new name", text: $newNameInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task { await profileVM.updateUsername(newNameInput) }
                }
            } message: {
                Text("Pick a cool name to show to your friends!")
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    showDeleteNotAvailableAlert = true
                }
            } message: {
                Text("This action cannot be undone. All your data and credits will be permanently removed.")
            }
            .alert("Contact Support", isPresented: $showDeleteNotAvailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Account deletion requires verification. Please contact support@thetrash.app to request account deletion.")
            }
            .onAppear {
                evaluateUCSDGrant()
            }
            .onChange(of: authVM.session?.user.emailConfirmedAt) { _ in
                evaluateUCSDGrant()
            }
            .onChange(of: authVM.session?.user.email) { _ in
                didTriggerUCSDCheck = false
                verificationStatusMessage = nil
                evaluateUCSDGrant()
            }
        }
    }

    // MARK: - Header View
    var compactHeaderView: some View {
        ZStack {
            // Neumorphic flat header
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 10, x: 5, y: 5)
                .shadow(color: .neuLightShadow, radius: 10, x: -5, y: -5)
                .frame(height: 160)
                .padding(.horizontal, 4)

            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // Neumorphic embossed avatar circle
                    ZStack {
                        Circle()
                            .fill(Color.neuBackground)
                            .frame(width: 68, height: 68)
                            .shadow(color: .neuDarkShadow, radius: 6, x: 5, y: 5)
                            .shadow(color: .neuLightShadow, radius: 6, x: -4, y: -4)

                        Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.neuAccentBlue)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Group {
                                if !profileVM.username.isEmpty {
                                    Text(profileVM.username)
                                } else if let email = authVM.session?.user.email, !email.isEmpty {
                                    Text(email)
                                        .lineLimit(1)
                                } else if let phone = authVM.session?.user.phone, !phone.isEmpty {
                                    Text(phone)
                                } else {
                                    Text("Guest")
                                }
                            }
                            .font(.title3.bold())
                            .foregroundColor(.neuText)
                            .lineLimit(1)
                            .frame(minWidth: 60, alignment: .leading)

                            if !authVM.isAnonymous {
                                Button(action: {
                                    newNameInput = profileVM.username
                                    showEditNameAlert = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.neuAccentBlue)
                                }
                            }
                        }

                        if !authVM.isAnonymous {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(profileVM.levelName)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(.neuAccentBlue)
                            .neumorphicConcave(cornerRadius: 13)
                            .frame(height: 26)
                            
                            // 装备的成就徽章
                            if let icon = profileVM.equippedAchievementIcon,
                               let name = profileVM.equippedAchievementName {
                                HStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.caption2)
                                    Text(name)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(profileVM.equippedAchievementRarity?.color ?? .neuAccentBlue)
                                .background(
                                    Capsule()
                                        .fill(Color.neuBackground)
                                        .shadow(color: .neuDarkShadow, radius: 2, x: 1, y: 1)
                                        .shadow(color: .neuLightShadow, radius: 2, x: -1, y: -1)
                                )
                                .frame(height: 22)
                            }
                        }
                    }
                    .animation(.none, value: profileVM.username)
                    .animation(.none, value: profileVM.levelName)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Stats View
    var compactStatsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                EnhancedStatCard(
                    title: "Credits",
                    value: "\(profileVM.credits)",
                    icon: "flame.fill",
                    gradient: [Color.orange, Color.red]
                )
                Button(action: handleStatusTap) {
                    EnhancedStatCard(
                        title: "Status",
                        value: statusValue,
                        icon: statusIcon,
                        gradient: statusGradient
                    )
                }
                .buttonStyle(.plain)
            }

            if !hasLinkedEmail && verificationStatusMessage == nil {
                Text("Link an email to secure your account.")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
                    .padding(.horizontal, 16)
            } else if !emailVerified && verificationStatusMessage == nil {
                Text("Tap \"Status\" to resend verification or refresh.")
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Guest Teaser View
    var compactGuestTeaserView: some View {
        Button(action: {
            upgradeEmail = ""
            upgradePassword = ""
            upgradeConfirmPassword = ""
            authVM.errorMessage = nil
            showUpgradeSheet = true
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.neuBackground)
                        .frame(width: 44, height: 44)
                        .shadow(color: .neuDarkShadow, radius: 4, x: 3, y: 3)
                        .shadow(color: .neuLightShadow, radius: 4, x: -2, y: -2)

                    Image(systemName: "link.circle.fill")
                        .font(.title2)
                        .foregroundColor(.neuAccentBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Link Account to Save Progress")
                        .font(.subheadline.bold())
                        .foregroundColor(.neuText)
                    Text("Don't lose your hard-earned credits!")
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.neuAccentBlue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions
    var quickActionsSection: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]

        return VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.neuText)
                .padding(.horizontal, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                NavigationLink {
                    AccountSettingsView()
                        .environmentObject(authVM)
                } label: {
                    QuickActionTile(
                        icon: "lock.shield.fill",
                        title: "Account Settings",
                        subtitle: "Manage email, phone, and password",
                        gradient: [.neuAccentBlue, .cyan]
                    )
                }

                NavigationLink(destination: BadgeAchievementsHubView()) {
                    QuickActionTile(
                        icon: "trophy.fill",
                        title: "Badges & Achievements",
                        subtitle: "Equip badges and review unlocks",
                        gradient: [.purple, .indigo]
                    )
                }

                NavigationLink(destination: RewardView()) {
                    QuickActionTile(
                        icon: "gift.fill",
                        title: "Rewards",
                        subtitle: "Redeem your credits",
                        gradient: [.orange, .red]
                    )
                }

                NavigationLink(destination: TrashHistoryView()) {
                    QuickActionTile(
                        icon: "clock.arrow.circlepath",
                        title: "Trash History",
                        subtitle: "See previous identifications",
                        gradient: [.mint, .teal]
                    )
                }

                Button(action: { showDeleteAlert = true }) {
                    QuickActionTile(
                        icon: "xmark.bin.fill",
                        title: "Delete Account",
                        subtitle: "Request account removal",
                        gradient: [.red, .pink]
                    )
                }

                Button(action: { showThemeSheet = true }) {
                    QuickActionTile(
                        icon: "paintbrush.pointed",
                        title: "UI Style",
                        subtitle: "Switch between app themes",
                        gradient: [.neuAccentPurple, .pink]
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
}

// MARK: - Helpers

extension AccountView {
    private var hasLinkedEmail: Bool {
        guard let email = authVM.session?.user.email else { return false }
        return !email.isEmpty
    }

    private var emailVerified: Bool {
        authVM.session?.user.emailConfirmedAt != nil
    }

    private var isUCSDMail: Bool {
        authVM.session?.user.email?.lowercased().hasSuffix("@ucsd.edu") == true
    }

    private var statusValue: String {
        guard hasLinkedEmail else { return "Link Email" }
        return emailVerified ? "Active" : "Verify Email"
    }

    private var statusIcon: String {
        guard hasLinkedEmail else { return "envelope.badge" }
        return emailVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
    }

    private var statusGradient: [Color] {
        guard hasLinkedEmail else { return [Color.gray, Color.neuSecondaryText] }
        return emailVerified ? [Color.neuAccentGreen, Color.mint] : [Color.orange, Color.yellow]
    }

    private func handleStatusTap() {
        verificationStatusMessage = nil
        guard hasLinkedEmail else {
            inputEmail = ""
            showBindEmailSheet = true
            return
        }

        if emailVerified {
            verificationStatusMessage = "Email verified. You're all set!"
        } else {
            Task {
                await sendVerificationEmail()
                refreshVerificationStatus()
            }
        }
    }

    private func refreshVerificationStatus() {
        Task {
            await authVM.refreshUserSession()
            await MainActor.run {
                verificationStatusMessage = emailVerified ? "Email verified!" : "Still waiting for verification."
            }
            evaluateUCSDGrant()
        }
    }

    private func sendVerificationEmail() async {
        await authVM.resendEmailVerification()
        await MainActor.run {
            if let error = authVM.errorMessage {
                verificationStatusMessage = error
                authVM.errorMessage = nil
            } else if let email = authVM.session?.user.email {
                verificationStatusMessage = "Verification email sent to \(email)."
            }
        }
    }

    private func evaluateUCSDGrant() {
        guard hasLinkedEmail,
              emailVerified,
              isUCSDMail else {
            return
        }
        if didTriggerUCSDCheck { return }
        didTriggerUCSDCheck = true
        Task {
            await achievementService.checkAndGrant(triggerKey: "ucsd_email")
        }
    }
}

// MARK: - Theme Picker Card

struct ThemeChoiceCard: View {
    let option: ThemeOption
    let isSelected: Bool
    let action: () -> Void
    var fillWidth: Bool = false

    @Environment(\.trashTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack {
                    Label(option.displayName, systemImage: option.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.neuText)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.neuAccentGreen)
                            .font(.title3)
                    }
                }

                Text(option.description)
                    .font(.caption)
                    .foregroundColor(.neuSecondaryText)

                RoundedRectangle(cornerRadius: theme.corners.small)
                    .fill(
                        LinearGradient(
                            colors: option.previewGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.corners.small)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding()
            .frame(maxWidth: fillWidth ? .infinity : 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow.opacity(isSelected ? 0.5 : 0.3), radius: 8, x: 5, y: 5)
                    .shadow(color: .neuLightShadow.opacity(isSelected ? 0.4 : 0.2), radius: 8, x: -4, y: -4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.medium)
                    .stroke(isSelected ? Color.neuAccentBlue.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .accessibilityLabel("\(option.displayName) theme")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }
}

struct ThemePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(ThemeOption.allCases) { option in
                        ThemeChoiceCard(
                            option: option,
                            isSelected: themeManager.currentOption == option,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    themeManager.apply(option)
                                }
                            },
                            fillWidth: true
                        )
                    }
                }
                .padding(16)
            }
            .background(
                ThemeBackgroundView()
                    .ignoresSafeArea()
            )
            .navigationTitle("Choose UI Style")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
