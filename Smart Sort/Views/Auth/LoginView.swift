//
//  LoginView.swift
//  Smart Sort
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    private let theme = TrashTheme()
    @State private var loginMethod = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var localPhoneNumber = ""
    @State private var otpCode = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    authCard
                    guestButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 28)
            }
            .trashScreenBackground()
            .navigationBarHidden(true)
            .alert("Check your email", isPresented: $authVM.showCheckEmailAlert) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort smarter.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(theme.palette.textPrimary)

            Text("Use the camera, earn credits, and join community challenges with a cleaner, faster sign in flow.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(theme.palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Login Method", selection: $loginMethod) {
                Text("Email").tag(0)
                Text("Phone").tag(1)
            }
            .pickerStyle(.segmented)

            if let error = authVM.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if loginMethod == 0 {
                emailSection
            } else {
                phoneSection
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(theme.palette.divider.opacity(0.8), lineWidth: 1)
                )
        )
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.headline)
                .foregroundColor(theme.palette.textPrimary)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .trashInputStyle(cornerRadius: 16)

            SecureField("Password", text: $password)
                .trashInputStyle(cornerRadius: 16)

            Button {
                Task {
                    if isSignUp {
                        await authVM.signUp(email: email, password: password)
                    } else {
                        await authVM.signIn(email: email, password: password)
                    }
                }
            } label: {
                Group {
                    if authVM.isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accents.green)
            .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)

            Button(isSignUp ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                isSignUp.toggle()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundColor(theme.accents.blue)
        }
    }

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(authVM.showOTPInput ? "Verify Phone" : "Phone Login")
                .font(.headline)
                .foregroundColor(theme.palette.textPrimary)

            if authVM.showOTPInput {
                Text(fullPhoneNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("6-digit code", text: $otpCode)
                    .keyboardType(.numberPad)
                    .trashInputStyle(cornerRadius: 16)

                Button {
                    Task {
                        await authVM.verifyOTP(phone: fullPhoneNumber, token: otpCode)
                        if authVM.session != nil {
                            otpCode = ""
                        }
                    }
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Verify and Continue")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accents.green)
                .disabled(authVM.isLoading || otpCode.isEmpty)

                Button("Use a different number", role: .cancel) {
                    authVM.showOTPInput = false
                    authVM.errorMessage = nil
                    otpCode = ""
                }
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .foregroundColor(theme.accents.blue)
            } else {
                HStack(spacing: 12) {
                    Text("+1")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(theme.palette.divider.opacity(0.85), lineWidth: 1)
                                )
                        )

                    TextField("Phone number", text: $localPhoneNumber)
                        .keyboardType(.phonePad)
                        .trashInputStyle(cornerRadius: 16)
                }

                Button {
                    Task { await authVM.sendOTP(phone: fullPhoneNumber) }
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Send Verification Code")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accents.green)
                .disabled(authVM.isLoading || localPhoneNumber.isEmpty)
            }

            Text("Phone auth supports both sign in and sign up.")
                .font(.footnote)
                .foregroundColor(theme.palette.textSecondary)
        }
    }

    private var guestButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Just looking around?")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.palette.textPrimary)

            Button("Continue as Guest") {
                Task { await authVM.signInAnonymously() }
            }
            .buttonStyle(.bordered)
            .tint(theme.accents.blue)
            .disabled(authVM.isLoading)
        }
    }

    private var fullPhoneNumber: String {
        let digits = localPhoneNumber.filter(\.isNumber)
        if digits.isEmpty {
            return "+1"
        }
        return "+1\(digits)"
    }
}
