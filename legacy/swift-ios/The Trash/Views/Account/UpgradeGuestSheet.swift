//
//  UpgradeGuestSheet.swift
//  The Trash
//

import SwiftUI

struct UpgradeGuestSheet: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isPresented: Bool
    @State private var localError: String?
    @Environment(\.trashTheme) private var theme

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Email")) {
                    TrashFormTextField(
                        title: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                }

                Section(header: Text("Password")) {
                    TrashFormSecureField(title: "Password (min 6 characters)", text: $password)
                    TrashFormSecureField(title: "Confirm Password", text: $confirmPassword)
                }

                Section {
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
                        .padding(.vertical, 10)
                    }
                    .disabled(authVM.isLoading)
                }

                if let message = localError ?? authVM.errorMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
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
