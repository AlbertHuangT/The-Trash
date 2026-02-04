//
//  AuthViewModel.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import SwiftUI
import Combine
import Supabase
import Auth

// 1. 定义 Deep Link 的验证状态
enum AuthDeepLinkStatus: Equatable {
    case idle           // 空闲
    case verifying      // 正在验证
    case success        // 验证成功
    case failure(String)// 验证失败
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // UI 状态
    @Published var deepLinkStatus: AuthDeepLinkStatus = .idle
    @Published var showCheckEmailAlert = false // 注册成功后提示查收邮件
    @Published var showOTPInput = false // 控制是否显示输入验证码的框
    
    private let client = SupabaseManager.shared.client
    
    init() {
        // 自动登录：监听 Session 变化
        Task {
            for await state in client.auth.authStateChanges {
                self.session = state.session
            }
        }
    }
    
    // MARK: - Email Auth
    
    // 登录
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 注册
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            // 注册成功，设置标记以弹窗提示
            showCheckEmailAlert = true
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Phone Auth (核心修复部分)
    
    // 1. 发送验证码 (登录/注册通用)
    func sendOTP(phone: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // Supabase 会自动判断是注册还是登录
            try await client.auth.signInWithOTP(phone: phone)
            showOTPInput = true // 成功发送后，让 UI 显示输入框
        } catch {
            errorMessage = "Send OTP failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 2. 验证验证码并登录
    func verifyOTP(phone: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // 🔥 修复：调整参数顺序，phone 必须在 token 之前
            _ = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            // 验证成功后 session 会自动更新，UI 自动跳转
            showOTPInput = false
        } catch {
            errorMessage = "Invalid Code: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Account Binding (绑定/解绑)
    
    // 绑定手机号 (给当前用户添加手机)
    func bindPhone(phone: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // 这会触发一条短信发到新手机号
            let attributes = UserAttributes(phone: phone)
            try await client.auth.update(user: attributes)
            showOTPInput = true // 需要在 UI 上弹出一个框输入验证码
        } catch {
            errorMessage = "Bind Phone Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 确认绑定手机号 (输入验证码)
    func confirmBindPhone(phone: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // 🔥 修复：这里也同样调整参数顺序，以防编译器报错
            _ = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .phoneChange
            )
            showOTPInput = false
            // 刷新 session 里的 user 信息
            try await client.auth.refreshSession()
        } catch {
            errorMessage = "Verification Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // 绑定邮箱
    func bindEmail(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            // 这会发一封确认邮件到新邮箱，用户点击链接即可完成绑定
            let attributes = UserAttributes(email: email)
            try await client.auth.update(user: attributes)
            showCheckEmailAlert = true
        } catch {
            errorMessage = "Bind Email Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - System
    
    // 登出
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }
    
    // 处理 Deep Link
    func handleIncomingURL(_ url: URL) async {
        // 设置状态为“正在验证”，UI 会显示转圈圈
        deepLinkStatus = .verifying
        
        do {
            // 把 Token 喂给 Supabase
            _ = try await client.auth.session(from: url)
            
            // 成功：显示绿勾提示
            deepLinkStatus = .success
            
            // 延迟 2 秒，让用户看清楚“验证成功”的提示，再消失
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            
            // 重置状态 (此时 Session 应该已经更新，View 会自动切换到 ContentView)
            deepLinkStatus = .idle
            
        } catch {
            print("❌ Deep Link Error: \(error)")
            deepLinkStatus = .failure("Link invalid or expired: \(error.localizedDescription)")
        }
    }
}
