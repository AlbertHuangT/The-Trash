//
//  AuthViewModel.swift
//  Smart Sort
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
    
    private let client = SupabaseManager.shared.client
    
    // Store the auth task reference to avoid leaks
    // nonisolated(unsafe) lets deinit cancel it safely
    nonisolated(unsafe) private var authStateTask: Task<Void, Never>?
    
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
                // Stop if the task has been cancelled
                if Task.isCancelled { break }
                self?.session = state.session
            }
        }
    }
    
    // deinit is not guaranteed to run on the main thread for @MainActor classes
    nonisolated deinit {
        // Cancel the task to avoid leaking the auth listener
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
            do {
                _ = try await client.auth.refreshSession()
            } catch {
                LogManager.shared.log("Refresh session after upgrade failed: \(error)", level: .error, category: "Auth")
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
            LogManager.shared.log("Sign out error: \(error)", level: .error, category: "Auth")
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
            LogManager.shared.log("Refresh session error: \(error)", level: .error, category: "Auth")
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
            // Reset after 3 seconds so the error state does not linger
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            deepLinkStatus = .idle
        }
    }
}
