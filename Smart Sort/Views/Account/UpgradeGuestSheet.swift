//
//  UpgradeGuestSheet.swift
//  Smart Sort
//

import SwiftUI

struct UpgradeGuestSheet: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isPresented: Bool
    @State private var localError: String?
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Email")
                        TrashFormTextField(
                            title: "you@example.com",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Password")
                        TrashFormSecureField(title: "Password (min 6 characters)", text: $password)
                        TrashFormSecureField(title: "Confirm Password", text: $confirmPassword)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(baseColor: theme.accents.blue, action: {
                        Task { await upgradeGuest() }
                    }) {
                        HStack {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(theme.onAccentForeground)
                                Text("Upgrading...")
                            } else {
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .trashOnAccentForeground()
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(authVM.isLoading)

                    if let message = localError ?? authVM.errorMessage {
                        messageCard(message, color: theme.semanticDanger)
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Link Your Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") {
                        resetState()
                        isPresented = false
                    }
                }
            }
        }
    }

    private func messageCard(_ message: String, color: Color) -> some View {
        HStack(spacing: theme.spacing.sm) {
            TrashIcon(systemName: "exclamationmark.circle.fill")
                .foregroundColor(color)
            Text(message)
                .font(theme.typography.caption)
                .foregroundColor(theme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func upgradeGuest() async {
        localError = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            localError = "Please enter an email address."
            return
        }

        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            localError = "Passwords do not match."
            return
        }

        await authVM.upgradeGuestAccount(email: trimmedEmail, password: password)

        if authVM.errorMessage == nil {
            resetState()
            isPresented = false
        }
    }

    private func resetState() {
        localError = nil
        authVM.errorMessage = nil
        email = ""
        password = ""
        confirmPassword = ""
    }
}
