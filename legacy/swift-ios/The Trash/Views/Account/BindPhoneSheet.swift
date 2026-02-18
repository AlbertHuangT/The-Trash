//
//  BindPhoneSheet.swift
//  The Trash
//
//  Extracted from AccountView.swift
//

import SwiftUI

struct BindPhoneSheet: View {
    @Binding var inputPhone: String
    @Binding var inputOTP: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            Form {
                if !authVM.showOTPInput {
                    Section {
                        TrashFormTextField(
                            title: "Phone (+1...)",
                            text: $inputPhone,
                            keyboardType: .phonePad
                        )
                        TrashTextButton(title: "Send Code", variant: .accent) {
                            Task { await authVM.bindPhone(phone: inputPhone) }
                        }
                    }
                } else {
                    Section {
                        TrashFormTextField(
                            title: "Code",
                            text: $inputOTP,
                            keyboardType: .numberPad
                        )
                        TrashTextButton(title: "Verify & Link", variant: .accent) {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                if authVM.errorMessage == nil {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Bind Phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    TrashTextButton(title: "Cancel") {
                        authVM.showOTPInput = false
                        authVM.errorMessage = nil
                        inputOTP = ""
                        isPresented = false
                    }
                }
            }
        }
    }
}
