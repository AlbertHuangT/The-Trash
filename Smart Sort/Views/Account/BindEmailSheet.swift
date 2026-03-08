//
//  BindEmailSheet.swift
//  Smart Sort
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    private let theme = TrashTheme()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: "Email")
                        TrashFormTextField(
                            title: "Email",
                            text: $inputEmail,
                            keyboardType: .emailAddress
                        )
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(baseColor: theme.accents.blue, action: {
                        Task {
                            await authVM.updateEmail(email: inputEmail)
                            if authVM.errorMessage == nil {
                                isPresented = false
                            }
                        }
                    }) {
                        Text("Send Link")
                    }
                    .disabled(inputEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authVM.isLoading)

                    if let error = authVM.errorMessage {
                        messageCard(error, color: theme.semanticDanger)
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Bind Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") {
                        authVM.errorMessage = nil
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
}
