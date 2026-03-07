//
//  AccountView.swift
//  Smart Sort
//

import Supabase
import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @ObservedObject private var achievementService = AchievementService.shared
    private let theme = TrashTheme()

    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showEditNameAlert = false
    @State private var newNameInput = ""
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let error = profileVM.errorMessage {
                            errorBanner(error)
                        }

                        profileHeroCard

                        if authVM.isAnonymous {
                            guestUpgradeCard
                        } else {
                            statusOverviewSection
                            accountDestinationsSection
                        }

                        supportSection
                        signOutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
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
                    inputPhone: $inputPhone,
                    inputOTP: $inputOTP,
                    authVM: authVM,
                    isPresented: $showBindPhoneSheet
                )
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(
                    inputEmail: $inputEmail,
                    authVM: authVM,
                    isPresented: $showBindEmailSheet
                )
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

    private var profileHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Circle()
                    .fill(theme.cardBackground)
                    .overlay(
                        Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(theme.accents.blue)
                    )
                    .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(theme.palette.textPrimary)

                    Text(accountSubtitle)
                        .font(.subheadline)
                        .foregroundColor(theme.palette.textSecondary)

                    HStack(spacing: 8) {
                        labelPill(title: authVM.isAnonymous ? "Guest" : profileVM.levelName, color: theme.accents.blue)

                        if !authVM.isAnonymous {
                            labelPill(title: statusValue, color: statusBadgeColor)
                        }
                    }
                }

                Spacer(minLength: 0)

                if !authVM.isAnonymous {
                    Button {
                        newNameInput = profileVM.username
                        showEditNameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.palette.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(theme.surfaceBackground, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit Username")
                }
            }

            Text(authVM.isAnonymous ? "Link an account to keep your credits and community progress across devices." : "Your profile, progress, and account tools live here.")
                .font(.footnote)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(20)
        .background(sectionBackground)
    }

    private var statusOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Overview")

            HStack(spacing: 12) {
                summaryCard(
                    title: "Credits",
                    value: "\(profileVM.credits)",
                    icon: "flame.fill",
                    color: .orange
                )

                Button(action: handleStatusTap) {
                    summaryCard(
                        title: "Account",
                        value: statusValue,
                        detail: statusDescription,
                        icon: statusIcon,
                        color: statusBadgeColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var guestUpgradeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Save Your Progress")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accents.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Link an account")
                            .font(.headline)
                            .foregroundColor(theme.palette.textPrimary)
                        Text("Protect your credits and pick up where you left off.")
                            .font(.footnote)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                    Spacer()
                }

                Button("Link Account") {
                    showUpgradeSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accents.blue)
            }
            .padding(18)
            .background(sectionBackground)
        }
    }

    private var accountDestinationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Progress")

            VStack(spacing: 0) {
                destinationRow(
                    title: "Achievements & Badges",
                    subtitle: "Track milestones and unlockables",
                    icon: "trophy.fill",
                    color: theme.accents.green,
                    destination: BadgeAchievementsHubView()
                )

                rowDivider

                destinationRow(
                    title: "Rewards",
                    subtitle: "Redeem credits and prizes",
                    icon: "gift.fill",
                    color: .orange,
                    destination: RewardView()
                )

                rowDivider

                destinationRow(
                    title: "History",
                    subtitle: "Review your scans and activity",
                    icon: "clock.arrow.circlepath",
                    color: .teal,
                    destination: TrashHistoryView()
                )
            }
            .background(sectionBackground)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tools & Support")

            VStack(spacing: 0) {
                destinationRow(
                    title: "Account Settings",
                    subtitle: "Manage email, phone, and password",
                    icon: "lock.shield.fill",
                    color: theme.accents.blue,
                    destination: AccountSettingsView()
                )

                rowDivider

                destinationRow(
                    title: "Feedback",
                    subtitle: "Report bugs or suggest improvements",
                    icon: "exclamationmark.bubble.fill",
                    color: .red,
                    destination: BugReportView()
                )
            }
            .background(sectionBackground)
        }
    }

    private var signOutSection: some View {
        VStack(spacing: 14) {
            Button {
                Task { await authVM.signOut() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Log Out")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Text("Smart Sort • Version 1.0.0")
                .font(.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(.top, 6)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error)
                .font(.caption)
                .foregroundColor(theme.palette.textPrimary)
            Spacer()
            Button {
                profileVM.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(theme.palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(sectionBackground)
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String? = nil,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(theme.surfaceBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.palette.textPrimary)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(theme.palette.textSecondary)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary.opacity(0.85))
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(sectionBackground)
    }

    private func destinationRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(theme.surfaceBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.palette.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.palette.textSecondary.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(theme.palette.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 2)
    }

    private func labelPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
            )
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 68)
    }
}

extension AccountView {
    private var displayName: String {
        authVM.isAnonymous ? "Guest" : (profileVM.username.isEmpty ? "User" : profileVM.username)
    }

    private var accountSubtitle: String {
        if authVM.isAnonymous {
            return "Explore the app without a linked account."
        }
        if let email = authVM.session?.user.email, !email.isEmpty {
            return email
        }
        if let phone = authVM.session?.user.phone, !phone.isEmpty {
            return phone
        }
        return "Account linked"
    }

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
        return emailVerified ? "Active" : "Verify"
    }

    private var statusDescription: String {
        guard hasLinkedEmail else { return "Add an email to secure your account" }
        return emailVerified ? "Everything looks good" : "Tap to resend verification"
    }

    private var statusIcon: String {
        guard hasLinkedEmail else { return "envelope" }
        return emailVerified ? "checkmark.shield" : "exclamationmark.shield"
    }

    private var statusBadgeColor: Color {
        guard hasLinkedEmail else { return .gray }
        return emailVerified ? theme.accents.green : .orange
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
