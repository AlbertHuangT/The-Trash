//
//  AccountView.swift
//  The Trash
//
//  Created by Albert Huang on 2/4/26.
//


import SwiftUI
import Auth

struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(authVM.isAnonymous ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "person.fill").foregroundColor(authVM.isAnonymous ? .gray : .blue))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if authVM.isAnonymous {
                                Text("Guest User").font(.headline)
                                Text("Link account to save data").font(.caption).foregroundColor(.orange)
                            } else {
                                Text(authVM.session?.user.email ?? authVM.session?.user.phone ?? "Member").font(.headline)
                                Text("Verified Member").font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: { Text("Profile") }
                
                Section {
                    HStack {
                        Label("Email", systemImage: "envelope.fill")
                        Spacer()
                        if let email = authVM.session?.user.email, !email.isEmpty {
                            Text("Linked").font(.caption).bold().foregroundColor(.green)
                        } else {
                            Button("Link") { showBindEmailSheet = true }.foregroundColor(.blue)
                        }
                    }
                    HStack {
                        Label("Phone", systemImage: "phone.fill")
                        Spacer()
                        if let phone = authVM.session?.user.phone, !phone.isEmpty {
                            Text("Linked").font(.caption).bold().foregroundColor(.green)
                        } else {
                            Button("Link") { showBindPhoneSheet = true }.foregroundColor(.blue)
                        }
                    }
                } header: { Text("Account Binding") }
                
                Section {
                    Button(action: { Task { await authVM.signOut() } }) {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right").foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Account")
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
        }
    }
}

// MARK: - Binding Sheets
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
                        TextField("Phone (+1...)", text: $inputPhone).keyboardType(.phonePad)
                        Button("Send Code") { Task { await authVM.bindPhone(phone: inputPhone) } }
                    }
                } else {
                    Section {
                        TextField("Code", text: $inputOTP).keyboardType(.numberPad)
                        Button("Verify & Link") {
                            Task {
                                await authVM.confirmBindPhone(phone: inputPhone, token: inputOTP)
                                isPresented = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bind Phone")
        }
    }
}

struct BindEmailSheet: View {
    @Binding var inputEmail: String
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $inputEmail).keyboardType(.emailAddress).autocapitalization(.none)
                    Button("Send Link") {
                        Task {
                            await authVM.bindEmail(email: inputEmail)
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Bind Email")
        }
    }
}
