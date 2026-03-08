//
//  ChangePasswordSheet.swift
//  Smart Sort
//

import SwiftUI

struct ChangePasswordSheet: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    private let theme = TrashTheme()
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var localError: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "New Password")
                        TrashFormSecureField(title: "Enter new password", text: $newPassword)
                        TrashFormSecureField(title: "Confirm password", text: $confirmPassword)
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(baseColor: theme.accents.blue, action: {
                        Task { await submit() }
                    }) {
                        if authVM.isLoading {
                            HStack {
                                ProgressView()
                                Text("Updating…")
                            }
                        } else {
                            Text("Update Password")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(authVM.isLoading)

                    if let message = localError ?? authVM.errorMessage {
                        messageCard(message, color: theme.semanticDanger, icon: "exclamationmark.circle.fill")
                    } else if let success = successMessage {
                        messageCard(success, color: theme.semanticSuccess, icon: "checkmark.circle.fill")
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Change Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Done", variant: .accent) {
                        resetFields()
                        isPresented = false
                    }
                }
            }
        }
    }

    private func messageCard(_ message: String, color: Color, icon: String) -> some View {
        HStack(spacing: theme.spacing.sm) {
            TrashIcon(systemName: icon)
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

    private func submit() async {
        localError = nil
        successMessage = nil

        guard newPassword.count >= 6 else {
            localError = "Password must be at least 6 characters."
            return
        }

        guard newPassword == confirmPassword else {
            localError = "Passwords do not match."
            return
        }

        await authVM.changePassword(newPassword: newPassword)
        if authVM.errorMessage == nil {
            successMessage = "Password updated successfully."
            resetFields(preserveSuccess: true)
        }
    }

    private func resetFields(preserveSuccess: Bool = false) {
        newPassword = ""
        confirmPassword = ""
        localError = nil
        if !preserveSuccess {
            successMessage = nil
        }
    }
}
