//
//  AccountSettingsView.swift
//  Smart Sort
//

import SwiftUI
import Auth

struct AccountSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    private let theme = TrashTheme()
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showChangePasswordSheet = false
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                identitySection
                securitySection
                InfoCard(content: "Linking your email or phone allows you to access your account and credits from any device.")
            }
            .padding(.horizontal, theme.layout.screenInset)
            .padding(.top, theme.layout.screenInset)
            .padding(.bottom, theme.spacing.xxl)
        }
        .trashScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            SectionHeader(title: "Identity")
            SettingsRow(icon: "envelope.fill", title: "Email", subtitle: authVM.session?.user.email ?? "Not linked") {
                inputEmail = authVM.session?.user.email ?? ""
                showBindEmailSheet = true
            }
            SettingsRow(icon: "phone.fill", title: "Phone", subtitle: authVM.session?.user.phone ?? "Not linked") {
                inputPhone = authVM.session?.user.phone ?? "+1"
                inputOTP = ""
                showBindPhoneSheet = true
            }
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
            SectionHeader(title: "Security")
            SettingsRow(icon: "key.fill", title: "Change Password") {
                showChangePasswordSheet = true
            }
        }
    }
}
