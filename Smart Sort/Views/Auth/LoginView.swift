//
//  LoginView.swift
//  Smart Sort
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme
    @State private var loginMethod = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var localPhoneNumber = ""
    @State private var otpCode = ""
    @State private var showCheckEmailAlert = false
    @State private var isAwaitingPhoneOTP = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    heroSection
                    authCard
                    guestButton
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.spacing.xl)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationBarHidden(true)
            .alert("Check your email", isPresented: $showCheckEmailAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We sent a verification link to your email address.")
            }
            .onChange(of: localPhoneNumber) { value in
                let digits = value.filter(\.isNumber)
                if digits != value {
                    localPhoneNumber = digits
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            TrashSectionTitle(title: "Welcome Back")
                .foregroundColor(theme.accents.blue)

            Text("Sort smarter.")
                .trashTextRole(.title)

            Text("Use the camera, explore Arena, and link an account to unlock long-term rewards and leaderboard progress.")
                .trashTextRole(.body, color: theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Picker("Login Method", selection: $loginMethod) {
                Text("Email").tag(0)
                Text("Phone").tag(1)
            }
            .pickerStyle(.segmented)

            if let error = authVM.errorMessage {
                authErrorBanner(error)
            }

            if loginMethod == 0 {
                emailSection
            } else {
                phoneSection
            }
        }
        .padding(theme.components.sheetPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .trashInputStyle()

            SecureField("Password", text: $password)
                .trashInputStyle()

            TrashButton(baseColor: theme.accents.green, action: {
                Task {
                    if isSignUp {
                        await authVM.signUp(email: email, password: password)
                        if authVM.errorMessage == nil {
                            showCheckEmailAlert = true
                        }
                    } else {
                        await authVM.signIn(email: email, password: password)
                    }
                }
            }) {
                Group {
                    if authVM.isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                    }
                }
            }
            .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)

            Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                isSignUp.toggle()
            }
            .buttonStyle(.plain)
            .trashTextRole(.button, color: theme.accents.blue, compact: true)
        }
    }

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(isAwaitingPhoneOTP ? "Verify Phone" : "Phone Login")
                .font(theme.typography.headline)
                .foregroundColor(theme.palette.textPrimary)

            if isAwaitingPhoneOTP {
                Text(fullPhoneNumber)
                    .font(theme.typography.subheadline)
                    .foregroundColor(theme.palette.textSecondary)

                TextField("6-digit code", text: $otpCode)
                    .keyboardType(.numberPad)
                    .trashInputStyle()

                TrashButton(baseColor: theme.accents.green, action: {
                    Task {
                        await authVM.verifyOTP(phone: fullPhoneNumber, token: otpCode)
                        if authVM.session != nil {
                            otpCode = ""
                            isAwaitingPhoneOTP = false
                        }
                    }
                }) {
                    Group {
                        if authVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Verify and Continue")
                        }
                    }
                }
                .disabled(authVM.isLoading || otpCode.isEmpty)

                Button("Use a different number", role: .cancel) {
                    isAwaitingPhoneOTP = false
                    authVM.errorMessage = nil
                    otpCode = ""
                }
                .buttonStyle(.plain)
                .trashTextRole(.button, color: theme.accents.blue, compact: true)
            } else {
                HStack(spacing: theme.layout.elementSpacing) {
                    Text("+1")
                        .font(theme.typography.button)
                        .foregroundColor(theme.palette.textPrimary)
                        .padding(.horizontal, theme.layout.inputHorizontalInset)
                        .frame(minHeight: theme.components.inputHeight)
                        .background(
                            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                .fill(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                )
                        )

                    TextField("Phone number", text: $localPhoneNumber)
                        .keyboardType(.phonePad)
                        .trashInputStyle()
                }

                TrashButton(baseColor: theme.accents.green, action: {
                    Task {
                        await authVM.sendOTP(phone: fullPhoneNumber)
                        if authVM.errorMessage == nil {
                            isAwaitingPhoneOTP = true
                        }
                    }
                }) {
                    Group {
                        if authVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Send Verification Code")
                        }
                    }
                }
                .disabled(authVM.isLoading || localPhoneNumber.isEmpty)
            }

            Text("Phone auth supports both sign in and sign up.")
                .trashTextRole(.caption, color: theme.palette.textSecondary)
        }
    }

    private var guestButton: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Just looking around?")
                .trashTextRole(.headline)

            Text("Guest mode lets you browse and play, but linked accounts are required for Verify rewards and account recovery.")
                .trashTextRole(.body, color: theme.palette.textSecondary, compact: true)
                .fixedSize(horizontal: false, vertical: true)

            TrashButton(baseColor: theme.accents.blue, action: {
                Task { await authVM.signInAnonymously() }
            }) {
                Text("Continue as Guest")
            }
            .disabled(authVM.isLoading)
        }
        .padding(theme.components.cardPadding)
        .surfaceCard(cornerRadius: theme.corners.large)
    }

    private var fullPhoneNumber: String {
        let digits = localPhoneNumber.filter(\.isNumber)
        if digits.isEmpty {
            return "+1"
        }
        return "+1\(digits)"
    }

    private func authErrorBanner(_ message: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            TrashIcon(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.semanticDanger)

            Text(message)
                .trashTextRole(.caption, color: theme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.components.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                .fill(theme.semanticDanger.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.corners.medium, style: .continuous)
                        .stroke(theme.semanticDanger.opacity(0.24), lineWidth: 1)
                )
        )
    }
}
