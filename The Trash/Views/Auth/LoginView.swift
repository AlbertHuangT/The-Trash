//
//  LoginView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var loginMethod = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var phoneNumber = "+1"
    @State private var otpCode = ""

    // Animation states
    @State private var isAnimating = false
    @State private var logoRotation: Double = 0
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Neumorphic Background
            Color.neuBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Logo
                    logoSection

                    // Main card
                    mainCard

                    // Guest entry
                    guestButton

                    Spacer().frame(height: 50)
                }
                .padding(.top, 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            isAnimating = true
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: loginMethod)
        .animation(.easeInOut(duration: 0.3), value: authVM.showOTPInput)
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Neumorphic embossed circle
                Circle()
                    .fill(Color.neuBackground)
                    .frame(width: 110, height: 110)
                    .shadow(color: .neuDarkShadow, radius: 10, x: 8, y: 8)
                    .shadow(color: .neuLightShadow, radius: 10, x: -6, y: -6)

                TrashIcon(systemName: "leaf.arrow.triangle.circlepath")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neuAccentBlue, .cyan, .neuAccentGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(logoRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                            logoRotation = 360
                        }
                    }
            }

            VStack(spacing: 8) {
                Text("The Trash")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.neuText)

                Text("Smart Waste Sorting")
                    .font(.subheadline)
                    .foregroundColor(.neuSecondaryText)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -30)
    }

    // MARK: - Main Card
    private var mainCard: some View {
        VStack(spacing: 24) {
            TrashSegmentedControl(
                options: [
                    TrashSegmentOption(value: 0, title: "Email", icon: "envelope.fill"),
                    TrashSegmentOption(value: 1, title: "Phone", icon: "phone.fill")
                ],
                selection: $loginMethod
            )

            // Error message
            if let error = authVM.errorMessage {
                HStack(spacing: 10) {
                    TrashIcon(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.neuText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .transition(.scale.combined(with: .opacity))
            }

            // Form content
            if loginMethod == 0 {
                emailFormContent
            } else {
                phoneFormContent
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.neuBackground)
                .shadow(color: .neuDarkShadow, radius: 15, x: 10, y: 10)
                .shadow(color: .neuLightShadow, radius: 15, x: -8, y: -8)
        )
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 50)
    }

    // MARK: - Guest Button
    private var guestButton: some View {
        TrashTapArea(action: {
            Task { await authVM.signInAnonymously() }
        }) {
            HStack(spacing: 12) {
                TrashIcon(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title3)
                Text("Continue as Guest")
                    .fontWeight(.medium)
            }
            .foregroundColor(.neuSecondaryText)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.neuBackground)
                    .shadow(color: .neuDarkShadow, radius: 6, x: 4, y: 4)
                    .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
            )
        }
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Email Form
    private var emailFormContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                EnhancedTextField(
                    icon: "envelope.fill",
                    placeholder: "Email Address",
                    text: $email,
                    keyboardType: .emailAddress
                )

                EnhancedTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )
            }

            if authVM.isLoading {
                LoadingButton()
            } else {
                GradientButton(
                    title: isSignUp ? "Create Account" : "Sign In",
                    colors: [.neuAccentBlue, .cyan],
                    icon: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill"
                ) {
                    Task {
                        if isSignUp {
                            await authVM.signUp(email: email, password: password)
                        } else {
                            await authVM.signIn(email: email, password: password)
                        }
                    }
                }
            }

            // Toggle login/signup
            TrashTapArea(action: { withAnimation { isSignUp.toggle() } }) {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.neuSecondaryText)
                    Text(isSignUp ? "Sign In" : "Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.neuAccentBlue)
                }
                .font(.subheadline)
                    }
                }
            }

    // MARK: - Phone Form
    private var phoneFormContent: some View {
        VStack(spacing: 20) {
            if !authVM.showOTPInput {
                VStack(spacing: 12) {
                    EnhancedTextField(
                        icon: "phone.fill",
                        placeholder: "+1 555 000 1234",
                        text: $phoneNumber,
                        keyboardType: .phonePad
                    )

                    Text("Works for both sign up and login")
                        .font(.caption)
                        .foregroundColor(.neuSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if authVM.isLoading {
                    LoadingButton()
                } else {
                    GradientButton(
                        title: "Send Verification Code",
                        colors: [.neuAccentGreen, .mint],
                        icon: "paperplane.fill"
                    ) {
                        Task { await authVM.sendOTP(phone: phoneNumber) }
                    }
                }
            } else {
                // OTP input
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        TrashIcon(systemName: "ellipsis.message.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [.neuAccentGreen, .mint], startPoint: .top, endPoint: .bottom)
                            )

                        Text("Verification Code Sent")
                            .font(.headline)
                            .foregroundColor(.neuText)

                        Text(phoneNumber)
                            .font(.subheadline)
                            .foregroundColor(.neuSecondaryText)
                    }

                    EnhancedTextField(
                        icon: "key.fill",
                        placeholder: "Enter 6-digit code",
                        text: $otpCode,
                        keyboardType: .numberPad
                    )

                    if authVM.isLoading {
                        LoadingButton()
                    } else {
                        GradientButton(
                            title: "Verify & Continue",
                            colors: [.neuAccentBlue, .purple],
                            icon: "checkmark.circle.fill"
                        ) {
                            Task {
                                await authVM.verifyOTP(phone: phoneNumber, token: otpCode)
                                if authVM.session != nil {
                                    otpCode = ""
                                }
                            }
                        }
                    }

                    TrashTextButton(title: "Use a different number", variant: .destructive) {
                        withAnimation(.spring()) {
                            authVM.showOTPInput = false
                            authVM.errorMessage = nil
                            otpCode = ""
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Input Field (Neumorphic Concave)
struct EnhancedTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TrashIconInputField(
            icon: icon,
            placeholder: placeholder,
            text: $text,
            isSecure: isSecure,
            keyboardType: keyboardType,
            textInputAutocapitalization: .never
        )
    }
}

// MARK: - Gradient Action (Accent LED)
struct GradientButton: View {
    let title: String
    let colors: [Color]
    let icon: String
    let action: () -> Void
    @Environment(\.trashTheme) private var theme

    var body: some View {
        TrashTapArea(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .fontWeight(.bold)
                TrashIcon(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            .trashOnAccentForeground()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.interactiveStroke, lineWidth: 1)
                        .padding(1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: colors.first?.opacity(0.4) ?? .neuAccentBlue.opacity(0.4), radius: 10, x: 5, y: 5)
            .shadow(color: .neuLightShadow, radius: 6, x: -3, y: -3)
        }
    }
}

// MARK: - Loading Action (Neumorphic Pressed)
struct LoadingButton: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.neuSecondaryText)
            Text("Please wait...")
                .fontWeight(.medium)
        }
        .foregroundColor(.neuSecondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .neumorphicConcave(cornerRadius: 14)
    }
}

// Keep the old CustomTextField for backward compatibility
struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        EnhancedTextField(
            icon: icon,
            placeholder: placeholder,
            text: $text,
            isSecure: isSecure,
            keyboardType: keyboardType
        )
    }
}

// Keep AnimatedGradientBackground for backward compatibility
struct AnimatedGradientBackground: View {
    var body: some View {
        Color.neuBackground
            .ignoresSafeArea()
    }
}
