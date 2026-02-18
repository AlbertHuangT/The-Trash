//
//  AccountSettingsView.swift
//  The Trash
//

import SwiftUI
import Auth

struct AccountSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.trashTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ThemeBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    SectionHeader(title: "Identity")
                    
                    VStack(spacing: 12) {
                        SettingsRow(icon: "envelope.fill", title: "Email", subtitle: authVM.session?.user.email ?? "Not linked") {
                            // Action...
                        }
                        
                        SettingsRow(icon: "phone.fill", title: "Phone", subtitle: authVM.session?.user.phone ?? "Not linked") {
                            // Action...
                        }
                    }
                    
                    SectionHeader(title: "Security")
                    
                    VStack(spacing: 12) {
                        SettingsRow(icon: "key.fill", title: "Change Password") {
                            // Action...
                        }
                    }
                    
                    InfoCard(content: "Linking your email or phone allows you to access your account and credits from any device.")
                }
                .padding(16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
