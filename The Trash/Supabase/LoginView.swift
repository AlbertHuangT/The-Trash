//
//  LoginView.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    // 模式切换
    @State private var loginMethod = 0 // 0: Email, 1: Phone
    
    // 邮箱表单状态
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    // 手机表单状态
    @State private var phoneNumber = "+1" // 默认美国区号
    @State private var otpCode = ""
    
    var body: some View {
        ZStack {
            // 1. 背景层：漂亮的渐变色
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 2. 内容层：使用 ScrollView 防止键盘遮挡
            ScrollView {
                VStack(spacing: 40) {
                    
                    // --- 顶部 Logo ---
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "trash.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                        }
                        
                        Text("The Trash")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 40)
                    
                    // --- 主卡片区域 ---
                    VStack(spacing: 25) {
                        
                        // 切换登录方式
                        Picker("Method", selection: $loginMethod) {
                            Text("Email").tag(0)
                            Text("Phone").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 5)
                        
                        // 错误提示区域
                        if let error = authVM.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            .foregroundColor(.red)
                            .padding(.vertical, 5)
                            .transition(.opacity)
                        }
                        
                        // 表单内容
                        if loginMethod == 0 {
                            emailFormContent
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        } else {
                            phoneFormContent
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(25)
                    .background(.ultraThinMaterial) // 毛玻璃效果
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
        // 弹窗逻辑保持不变
        .alert("Check Email", isPresented: $authVM.showCheckEmailAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Confirmation link sent to \(email).")
        }
        // 添加动画让切换更丝滑
        .animation(.spring(), value: loginMethod)
        .animation(.easeInOut, value: authVM.showOTPInput)
    }
    
    // MARK: - Email Form Components
    
    var emailFormContent: some View {
        VStack(spacing: 20) {
            // 输入框
            VStack(spacing: 15) {
                CustomTextField(
                    icon: "envelope.fill",
                    placeholder: "UCSD Email",
                    text: $email,
                    keyboardType: .emailAddress
                )
                
                CustomTextField(
                    icon: "lock.fill",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )
            }
            
            // 登录/注册按钮
            if authVM.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    Task {
                        if isSignUp {
                            await authVM.signUp(email: email, password: password)
                        } else {
                            await authVM.signIn(email: email, password: password)
                        }
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Log In")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            
            // 切换文案
            Button(action: { withAnimation { isSignUp.toggle() } }) {
                HStack {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(.secondary)
                    Text(isSignUp ? "Log In" : "Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .font(.footnote)
            }
        }
    }
    
    // MARK: - Phone Form Components
    
    var phoneFormContent: some View {
        VStack(spacing: 20) {
            if !authVM.showOTPInput {
                // 阶段 1: 输入手机号
                VStack(spacing: 8) {
                    CustomTextField(
                        icon: "phone.fill",
                        placeholder: "+1 555 000 1234",
                        text: $phoneNumber,
                        keyboardType: .phonePad
                    )
                    
                    Text("Supports both Sign Up & Login")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 5)
                }
                
                if authVM.isLoading {
                    ProgressView().padding()
                } else {
                    Button(action: {
                        Task { await authVM.sendOTP(phone: phoneNumber) }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Send Code")
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                
            } else {
                // 阶段 2: 输入验证码
                VStack(spacing: 15) {
                    Text("Enter code sent to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(phoneNumber)
                        .font(.headline)
                    
                    CustomTextField(
                        icon: "key.fill",
                        placeholder: "6-digit Code",
                        text: $otpCode,
                        keyboardType: .numberPad
                    )
                    
                    if authVM.isLoading {
                        ProgressView().padding()
                    } else {
                        Button(action: {
                            Task { await authVM.verifyOTP(phone: phoneNumber, token: otpCode) }
                        }) {
                            Text("Verify & Login")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                    }
                    
                    Button("Wrong number?") {
                        withAnimation {
                            authVM.showOTPInput = false
                            otpCode = ""
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - 自定义输入框组件
struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none) // 邮箱不自动大写
            }
        }
        .padding()
        .background(Color(.systemBackground)) // 白色或深色模式背景
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
