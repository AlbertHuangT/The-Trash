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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
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
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.appearance.sheetBackground)
            }
            .onAppear { evaluateUCSDGrant() }
        }
    }

    private var profileHeroCard: some View {
        VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
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
                    TrashIconButton(icon: "pencil") {
                        newNameInput = profileVM.username
                        showEditNameAlert = true
                    }
                    .accessibilityLabel("Edit Username")
                }
            }

            Text(authVM.isAnonymous ? "Link an account to start earning Verify rewards and keep your community progress across devices." : "Your profile, progress, and account tools live here.")
                .font(.footnote)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(theme.spacing.lg)
        .background(sectionBackground)
    }

    private var statusOverviewSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            sectionTitle("Overview")

            HStack(spacing: theme.layout.elementSpacing) {
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
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            sectionTitle("Save Your Progress")

            VStack(alignment: .leading, spacing: theme.spacing.sm + 2) {
                HStack(spacing: theme.layout.elementSpacing) {
                    Image(systemName: "link.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accents.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Link an account")
                            .font(.headline)
                            .foregroundColor(theme.palette.textPrimary)
                        Text("Link an account before you start earning Verify rewards, and pick up where you left off.")
                            .font(.footnote)
                            .foregroundColor(theme.palette.textSecondary)
                    }
                    Spacer()
                }

                TrashButton(baseColor: theme.accents.blue, action: {
                    showUpgradeSheet = true
                }) {
                    Text("Link Account")
                }
            }
            .padding(theme.spacing.md)
            .background(sectionBackground)
        }
    }

    private var accountDestinationsSection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
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
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
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

                if profileVM.isAppAdmin {
                    rowDivider

                    destinationRow(
                        title: "Quiz Review",
                        subtitle: "Review and publish candidate Arena images",
                        icon: "photo.badge.checkmark",
                        color: theme.accents.green,
                        destination: QuizCandidateReviewView()
                    )
                }
            }
            .background(sectionBackground)
        }
    }

    private var signOutSection: some View {
        VStack(spacing: theme.layout.elementSpacing) {
            TrashButton(baseColor: theme.semanticDanger, action: {
                Task { await authVM.signOut() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Log Out")
                        .fontWeight(.semibold)
                }
                .trashOnAccentForeground()
            }

            Text("Smart Sort • Version 1.0.0")
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textSecondary)
        }
        .padding(.top, theme.spacing.xs + 2)
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: theme.spacing.sm + 2) {
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
        .padding(theme.components.cardPadding)
        .background(sectionBackground)
    }

    private func summaryCard(
        title: String,
        value: String,
        detail: String? = nil,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                .background(
                    theme.surfaceBackground,
                    in: RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                )

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
        .padding(theme.components.cardPadding)
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
            HStack(spacing: theme.layout.rowContentSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: theme.components.minimumHitTarget, height: theme.components.minimumHitTarget)
                    .background(
                        theme.surfaceBackground,
                        in: RoundedRectangle(cornerRadius: theme.corners.small, style: .continuous)
                    )

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
            .padding(.horizontal, theme.components.cardPadding)
            .padding(.vertical, theme.spacing.sm)
            .frame(minHeight: theme.components.rowHeight)
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
        TrashPill(title: title, color: color, isSelected: false)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
            .fill(theme.surfaceBackground)
            .overlay(
                RoundedRectangle(cornerRadius: theme.corners.large, style: .continuous)
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
