import SwiftUI
import Auth

struct AccountSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showChangePasswordSheet = false
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Manage how you sign in and recover your account.")
                    .font(.subheadline)
                    .foregroundColor(.neuSecondaryText)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    EnhancedAccountRow(
                        icon: "envelope.fill",
                        gradient: [.blue, .indigo],
                        title: "Email",
                        status: authVM.session?.user.email ?? "Link Now",
                        isLinked: hasLinkedEmail
                    ) {
                        inputEmail = authVM.session?.user.email ?? ""
                        showBindEmailSheet = true
                    }

                    if hasLinkedEmail && !emailVerified {
                        Button(action: { Task { await sendVerificationEmail() } }) {
                            Label("Resend Verification Email", systemImage: "arrow.clockwise")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.neuAccentBlue)
                    }

                    EnhancedAccountRow(
                        icon: "phone.fill",
                        gradient: [.green, .mint],
                        title: "Phone",
                        status: authVM.session?.user.phone ?? "Link Now",
                        isLinked: authVM.session?.user.phone != nil
                    ) {
                        inputPhone = authVM.session?.user.phone ?? "+1"
                        showBindPhoneSheet = true
                    }

                    EnhancedAccountRow(
                        icon: "key.fill",
                        gradient: [.orange, .red],
                        title: "Password",
                        status: "Change",
                        isLinked: true
                    ) {
                        showChangePasswordSheet = true
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.neuBackground.ignoresSafeArea())
        .navigationTitle("Account Settings")
        .sheet(isPresented: $showBindPhoneSheet) {
            BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
        }
        .sheet(isPresented: $showBindEmailSheet) {
            BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordSheet(authVM: authVM, isPresented: $showChangePasswordSheet)
        }
        .overlay(alignment: .top) {
            FloatingToast(message: $toastMessage)
        }
    }

    private var hasLinkedEmail: Bool {
        guard let email = authVM.session?.user.email else { return false }
        return !email.isEmpty
    }

    private var emailVerified: Bool {
        authVM.session?.user.emailConfirmedAt != nil
    }

    private func sendVerificationEmail() async {
        await authVM.resendEmailVerification()
        await MainActor.run {
            if let error = authVM.errorMessage {
                toastMessage = error
                authVM.errorMessage = nil
            } else if let email = authVM.session?.user.email {
                toastMessage = "Verification email sent to \(email)."
            }
        }
    }
}
