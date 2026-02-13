//
//  ChangePasswordSheet.swift
//  The Trash
//

import SwiftUI

struct ChangePasswordSheet: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    @Environment(\.trashTheme) private var theme
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var localError: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Password")) {
                    TrashFormSecureField(title: "Enter new password", text: $newPassword)
                    TrashFormSecureField(title: "Confirm password", text: $confirmPassword)
                }

                Section {
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
                }

                if let message = localError ?? authVM.errorMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else if let success = successMessage {
                    Section {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
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
