//
//  BindPhoneSheet.swift
//  Smart Sort
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    private let theme = TrashTheme()
    @State private var isAwaitingOTP = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: theme.layout.elementSpacing) {
                        TrashSectionTitle(title: isAwaitingOTP ? "Verification Code" : "Phone")

                        if isAwaitingOTP {
                            TrashFormTextField(
                                title: "Code",
                                text: $inputOTP,
                                keyboardType: .numberPad
                            )
                        } else {
                            TrashFormTextField(
                                title: "Phone (+1...)",
                                text: $inputPhone,
                                keyboardType: .phonePad
                            )
                        }
                    }
                    .padding(theme.components.cardPadding)
                    .surfaceCard(cornerRadius: theme.corners.large)

                    TrashButton(
                        baseColor: theme.accents.blue,
                        action: {
                            Task {
                                if isAwaitingOTP {
                                    await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                    if authVM.errorMessage == nil {
                                        isAwaitingOTP = false
                                        inputOTP = ""
                                        isPresented = false
                                    }
                                } else {
                                    await authVM.bindPhone(phone: inputPhone)
                                    if authVM.errorMessage == nil {
                                        isAwaitingOTP = true
                                    }
                                }
                            }
                        }
                    ) {
                        Text(isAwaitingOTP ? "Verify & Link" : "Send Code")
                    }
                    .disabled(actionDisabled)

                    if let error = authVM.errorMessage {
                        messageCard(error, color: theme.semanticDanger)
                    }
                }
                .padding(.horizontal, theme.layout.screenInset)
                .padding(.top, theme.layout.screenInset)
                .padding(.bottom, theme.spacing.xxl)
            }
            .trashScreenBackground()
            .navigationTitle("Bind Phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") {
                        isAwaitingOTP = false
                        authVM.errorMessage = nil
                        inputOTP = ""
                        isPresented = false
                    }
                }
            }
        }
    }

    private var actionDisabled: Bool {
        if isAwaitingOTP {
            return inputOTP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return inputPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
