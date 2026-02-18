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

// Define verification status for Deep Link
enum AuthDeepLinkStatus: Equatable {
    case idle
    case verifying
    case success
    case failure(String)
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // UI State
    @Published var deepLinkStatus: AuthDeepLinkStatus = .idle
    @Published var showCheckEmailAlert = false
    @Published var showOTPInput = false
    
    private let client = SupabaseManager.shared.client
    
    // 🔥 存储任务引用，防止内存泄漏
    private var authStateTask: Task<Void, Never>?
    
    // Check if the current user is a guest
    var isAnonymous: Bool {
        guard let user = session?.user else { return false }
        // If both email and phone are missing, the user is anonymous
        return (user.email == nil || user.email?.isEmpty == true) &&
               (user.phone == nil || user.phone?.isEmpty == true)
    }
    
    init() {
        authStateTask = Task { [weak self] in
            guard let client = self?.client else { return }
            for await state in client.auth.authStateChanges {
                // 🔥 检查任务是否被取消
                if Task.isCancelled { break }
                self?.session = state.session
            }
        }
    }
    
    // 🔥 FIX: deinit 在 @MainActor 类中不在主线程调用，需要使用 nonisolated
    nonisolated deinit {
        // 🔥 清理：取消任务以防止内存泄漏
        authStateTask?.cancel()
    }
    
    // MARK: - Guest Auth
    
    func signInAnonymously() async {
        isLoading = true
        errorMessage = nil
        do {
            // Note: Ensure Anonymous Auth is enabled in your Supabase Dashboard
            _ = try await client.auth.signInAnonymously()
        } catch {
            errorMessage = "Guest login failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Email Auth
    
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
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            showCheckEmailAlert = true
        } catch {
            errorMessage = "Signup failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Phone Auth
    
    func sendOTP(phone: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await client.auth.signInWithOTP(phone: phone)
            showOTPInput = true
        } catch {
            errorMessage = "Send OTP failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func verifyOTP(phone: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .sms
            )
            showOTPInput = false
        } catch {
            errorMessage = "Invalid Code: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Account Binding
    
    func bindPhone(phone: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let attributes = UserAttributes(phone: phone)
            try await client.auth.update(user: attributes)
            showOTPInput = true
        } catch {
            errorMessage = "Bind Phone Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func confirmBindPhone(phone: String, token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.auth.verifyOTP(
                phone: phone,
                token: token,
                type: .phoneChange
            )
            showOTPInput = false
            try await client.auth.refreshSession()
        } catch {
            errorMessage = "Verification Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func updateEmail(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let attributes = UserAttributes(email: email)
            try await client.auth.update(user: attributes)
            showCheckEmailAlert = true
        } catch {
            errorMessage = "Bind Email Failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func bindEmail(email: String) async {
        await updateEmail(email: email)
    }

    // MARK: - Guest Upgrade

    func upgradeGuestAccount(email: String, password: String) async {
        guard isAnonymous else {
            errorMessage = "You already have a linked account."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let attributes = UserAttributes(email: email, password: password)
            try await client.auth.update(user: attributes)
            showCheckEmailAlert = true
            do {
                _ = try await client.auth.refreshSession()
            } catch {
                print("Refresh session after upgrade failed: \(error)")
            }
        } catch {
            errorMessage = "Upgrade failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    // MARK: - System
    
    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("Sign out error: \(error)")
        }
    }

    func changePassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let attributes = UserAttributes(password: newPassword)
            try await client.auth.update(user: attributes)
        } catch {
            errorMessage = "Failed to change password: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func resendEmailVerification() async {
        guard let email = session?.user.email else {
            errorMessage = "Link an email first."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await client.auth.resend(email: email, type: .signup)
        } catch {
            errorMessage = "Failed to send verification email: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func refreshUserSession() async {
        do {
            let refreshed = try await client.auth.refreshSession()
            self.session = refreshed
        } catch {
            print("Refresh session error: \(error)")
        }
    }
    
    func handleIncomingURL(_ url: URL) async {
        deepLinkStatus = .verifying
        do {
            _ = try await client.auth.session(from: url)
            deepLinkStatus = .success
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            deepLinkStatus = .idle
        } catch {
            deepLinkStatus = .failure("Link invalid or expired: \(error.localizedDescription)")
            // 自动在3秒后重置状态，避免错误消息持续显示
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            deepLinkStatus = .idle
        }
    }
}
