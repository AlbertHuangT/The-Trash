//
//  AccountView.swift
//  The Trash
//
//  Created by Albert Huang on 2/5/26.
//

import SwiftUI
import Supabase
import Combine

// MARK: - Account Button (App Store Style with Depth Effect)
/// 可重用的账户按钮组件，类似 App Store 右上角的头像按钮
/// 点击后展示带有景深效果的个人页面
struct AccountButton: View {
    @Binding var showAccountSheet: Bool
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Button {
            showAccountSheet = true
        } label: {
            ZStack {
                // 外圈发光效果
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .blur(radius: 4)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 45, height: 45)
                    .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
    }
}

// MARK: - Profile ViewModel
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var credits: Int = 0
    @Published var username: String = ""
    @Published var levelName: String = "Novice Recycler"
    @Published var isLoading = false
    // 🔥 添加错误消息，让用户知道发生了什么
    @Published var errorMessage: String?
    
    // 🚀 优化：添加缓存
    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 30 // 缓存有效期30秒
    private var hasFetchedOnce = false
    
    private let client = SupabaseManager.shared.client
    
    func fetchProfile(forceRefresh: Bool = false) async {
        guard let userId = client.auth.currentUser?.id else { return }
        
        // 🚀 优化：检查缓存
        if !forceRefresh && hasFetchedOnce,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return // 使用缓存数据
        }
        
        // 🚀 优化：只在首次加载时显示 loading
        if !hasFetchedOnce {
            isLoading = true
        }
        errorMessage = nil
        do {
            struct UserProfile: Decodable {
                let credits: Int?
                let username: String?
            }
            
            let profile: UserProfile = try await client
                .from("profiles")
                .select("credits, username")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.credits = profile.credits ?? 0
            self.username = profile.username ?? ""
            self.lastFetchTime = Date() // 🚀 更新缓存时间
            self.hasFetchedOnce = true
            calculateLevel()
        } catch {
            print("❌ Fetch profile error: \(error)")
            // 🔥 只在非取消错误时显示错误消息
            if !Task.isCancelled {
                self.errorMessage = "Failed to load profile"
            }
        }
        isLoading = false
    }
    
    // 更新用户名
    func updateUsername(_ newName: String) async {
        guard let userId = client.auth.currentUser?.id else { return }
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // 🔥 乐观更新：先更新UI
        let previousName = self.username
        self.username = newName
        errorMessage = nil
        
        do {
            struct UpdateName: Encodable {
                let username: String
            }
            
            try await client
                .from("profiles")
                .update(UpdateName(username: newName))
                .eq("id", value: userId)
                .execute()
            
            print("✅ Username updated to: \(newName)")
        } catch {
            print("❌ Update username error: \(error)")
            // 🔥 失败时回滚
            self.username = previousName
            self.errorMessage = "Failed to update username"
        }
    }
    
    private func calculateLevel() {
        switch credits {
        case 0..<100: levelName = "Novice Recycler 🌱"
        case 100..<500: levelName = "Green Guardian 🌿"
        case 500..<2000: levelName = "Eco Warrior ⚔️"
        default: levelName = "Planet Savior 🌍"
        }
    }
}

// MARK: - Main View
struct AccountView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()
    @ObservedObject private var userSettings = UserSettings.shared
    
    // Sheets & Alerts
    @State private var showBindPhoneSheet = false
    @State private var showBindEmailSheet = false
    @State private var showEditNameAlert = false
    @State private var newNameInput = ""
    @State private var inputPhone = "+1"
    @State private var inputEmail = ""
    @State private var inputOTP = ""
    @State private var showDeleteAlert = false
    @State private var showDeleteNotAvailableAlert = false
    @State private var showProfileError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 🔥 显示错误提示 - 使用固定高度的容器防止布局跳动
                ZStack {
                    if let error = profileVM.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                            Spacer()
                            Button(action: { profileVM.errorMessage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                    }
                }
                .frame(height: profileVM.errorMessage != nil ? nil : 0) // 🚀 无错误时高度为0
                .clipped()
                .animation(.easeInOut(duration: 0.2), value: profileVM.errorMessage != nil)
                
                // 1. 紧凑型头部卡片
                compactHeaderView
                
                // 2. 数据仪表盘
                if !authVM.isAnonymous {
                    compactStatsView
                } else {
                    compactGuestTeaserView
                }
                
                // 3. 功能菜单
                compactMenuSection
                
                Spacer()
                
                // 4. 🎨 美化退出与版本信息
                VStack(spacing: 12) {
                    Button(action: { Task { await authVM.signOut() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.bold())
                            Text("Log Out")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("The Trash")
                            .font(.caption2.bold())
                        Text("• Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .task {
                await profileVM.fetchProfile()
            }
            // 🚀 禁用因数据加载导致的布局动画
            .animation(.none, value: profileVM.credits)
            .animation(.none, value: profileVM.username)
            .animation(.none, value: profileVM.levelName)
            // Sheets
            .sheet(isPresented: $showBindPhoneSheet) {
                BindPhoneSheet(inputPhone: $inputPhone, inputOTP: $inputOTP, authVM: authVM, isPresented: $showBindPhoneSheet)
            }
            .sheet(isPresented: $showBindEmailSheet) {
                BindEmailSheet(inputEmail: $inputEmail, authVM: authVM, isPresented: $showBindEmailSheet)
            }
            // 修改用户名的弹窗
            .alert("Change Username", isPresented: $showEditNameAlert) {
                TextField("Enter new name", text: $newNameInput)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task { await profileVM.updateUsername(newNameInput) }
                }
            } message: {
                Text("Pick a cool name to show to your friends!")
            }
            // 删除账号的弹窗
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    showDeleteNotAvailableAlert = true
                }
            } message: {
                Text("This action cannot be undone. All your data and credits will be permanently removed.")
            }
            // 删除账号功能暂未上线的提示
            .alert("Contact Support", isPresented: $showDeleteNotAvailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Account deletion requires verification. Please contact support@thetrash.app to request account deletion.")
            }
        }
    }
    
    // MARK: - Compact Subviews
    
    // 🎨 美化头部视图 - 使用动态渐变和动画效果
    var compactHeaderView: some View {
        ZStack {
            // 动态渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8), // 紫色
                    Color(red: 0.2, green: 0.4, blue: 0.9), // 蓝色
                    Color(red: 0.1, green: 0.6, blue: 0.8)  // 青色
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
            .shadow(color: .purple.opacity(0.3), radius: 15, y: 5)
            
            // 装饰性圆形
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .offset(x: -100, y: -60)
            
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 150, height: 150)
                .offset(x: 120, y: 40)
            
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // 🎨 美化头像 - 添加光晕效果
                    ZStack {
                        // 外圈光晕
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 68, height: 68)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: authVM.isAnonymous ? "person.fill" : "person.crop.circle.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    }
                    
                    // Name & Level
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            // 🚀 优化：使用固定占位符防止加载时跳动
                            Group {
                                if !profileVM.username.isEmpty {
                                    Text(profileVM.username)
                                } else if let email = authVM.session?.user.email, !email.isEmpty {
                                    Text(email)
                                        .lineLimit(1)
                                } else if let phone = authVM.session?.user.phone, !phone.isEmpty {
                                    Text(phone)
                                } else {
                                    Text("Guest")
                                }
                            }
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(minWidth: 60, alignment: .leading) // 🚀 固定最小宽度
                            
                            if !authVM.isAnonymous {
                                Button(action: {
                                    newNameInput = profileVM.username
                                    showEditNameAlert = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                        }
                        
                        if !authVM.isAnonymous {
                            // 🎨 美化等级标签 - 使用固定高度防止跳动
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                Text(profileVM.levelName)
                                    .font(.caption.bold())
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                            .foregroundColor(.white)
                            .frame(height: 26) // 🚀 固定高度
                        }
                    }
                    .animation(.none, value: profileVM.username) // 🚀 禁用用户名变化动画
                    .animation(.none, value: profileVM.levelName) // 🚀 禁用等级变化动画
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 24)
        }
    }
    
    // 🎨 美化统计视图 - 添加渐变和动画
    var compactStatsView: some View {
        HStack(spacing: 12) {
            EnhancedStatCard(
                title: "Credits",
                value: "\(profileVM.credits)",
                icon: "flame.fill",
                gradient: [Color.orange, Color.red]
            )
            EnhancedStatCard(
                title: "Status",
                value: "Active",
                icon: "checkmark.shield.fill",
                gradient: [Color.green, Color.mint]
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // 🎨 美化访客引导 - 更吸引眼球
    var compactGuestTeaserView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: .purple.opacity(0.3), radius: 6, y: 2)
                
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Link Account to Save Progress")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text("Don't lose your hard-earned credits!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // 🎨 美化菜单区域
    var compactMenuSection: some View {
        VStack(spacing: 16) {
            // Security Section
            VStack(spacing: 0) {
                // Section Header
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("Security")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                VStack(spacing: 0) {
                    EnhancedAccountRow(
                        icon: "envelope.fill",
                        gradient: [.blue, .indigo],
                        title: "Email",
                        status: authVM.session?.user.email != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.email != nil
                    ) { showBindEmailSheet = true }
                    
                    Divider().padding(.leading, 52)
                    
                    EnhancedAccountRow(
                        icon: "phone.fill",
                        gradient: [.green, .mint],
                        title: "Phone",
                        status: authVM.session?.user.phone != nil ? "Linked" : "Link Now",
                        isLinked: authVM.session?.user.phone != nil
                    ) { showBindPhoneSheet = true }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            )
            
            // General Section
            VStack(spacing: 0) {
                // Section Header
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.gray, .secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text("General")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
                
                VStack(spacing: 0) {
                    // Rewards 入口
                    NavigationLink(destination: RewardView()) {
                        EnhancedSettingsRow(icon: "gift.fill", gradient: [.orange, .yellow], title: "Rewards")
                    }
                    
                    Divider().padding(.leading, 52)
                    
                    NavigationLink(destination: TrashHistoryView()) {
                        EnhancedSettingsRow(icon: "trash.fill", gradient: [.purple, .pink], title: "My Trash History")
                    }
                    
                    Divider().padding(.leading, 52)
                    
                    Button(action: { showDeleteAlert = true }) {
                        EnhancedSettingsRow(icon: "xmark.bin.fill", gradient: [.red, .orange], title: "Delete Account")
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // 保留旧视图兼容性
    var headerView: some View { compactHeaderView }
    var statsGridView: some View { compactStatsView }
    var guestTeaserView: some View { compactGuestTeaserView }
    var menuSection: some View { compactMenuSection }
}

// MARK: - Compact Components

// 🎨 美化统计卡片组件
struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: gradient[0].opacity(0.4), radius: 6, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .frame(minWidth: 50, alignment: .leading) // 🚀 固定最小宽度防止跳动
                    .animation(.none, value: value) // 🚀 禁用数值变化动画
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 72) // 🚀 固定高度防止跳动
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.bold())
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct CompactAccountRow: View {
    let icon: String
    let color: Color
    let title: String
    let status: String
    let isLinked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: { if !isLinked { action() } }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(color)
                    .cornerRadius(6)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .fontWeight(isLinked ? .semibold : .regular)
                    .foregroundColor(isLinked ? .green : .blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isLinked ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                if !isLinked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .disabled(isLinked)
    }
}

struct CompactSettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(color)
                .cornerRadius(6)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// 🎨 美化账户行组件
struct EnhancedAccountRow: View {
    let icon: String
    let gradient: [Color]
    let title: String
    let status: String
    let isLinked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: { if !isLinked { action() } }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: gradient[0].opacity(0.3), radius: 4, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    if isLinked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text(status)
                        .font(.caption.bold())
                        .foregroundColor(isLinked ? .green : .blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isLinked ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                )
                
                if !isLinked {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .disabled(isLinked)
    }
}

// 🎨 美化设置行组件
struct EnhancedSettingsRow: View {
    let icon: String
    let gradient: [Color]
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: gradient[0].opacity(0.3), radius: 4, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct AccountRow: View {
    let icon: String
    let color: Color
    let title: String
    let status: String
    let isLinked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: { if !isLinked { action() } }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(color)
                    .cornerRadius(8)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .fontWeight(isLinked ? .semibold : .regular)
                    .foregroundColor(isLinked ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isLinked ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                if !isLinked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 12)
        }
        .disabled(isLinked)
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .cornerRadius(8)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle()) // 确保整个区域可点击
    }
}

// 自定义 GroupBox 样式
struct CustomGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
                .font(.headline)
                .padding(.bottom, 8)
            
            VStack(alignment: .leading) {
                configuration.content
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
}

// 用于 RoundedCorner
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Binding Sheets (底部弹窗)

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
                                // 🔥 成功后才关闭弹窗
                                if authVM.errorMessage == nil {
                                    isPresented = false
                                }
                            }
                        }
                    }
                }
                
                // 🔥 显示错误信息
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
                    Button("Cancel") {
                        // 🔥 修复：关闭弹窗时重置所有状态
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
                            // 🔥 只有成功时才关闭弹窗
                            if authVM.errorMessage == nil && authVM.showCheckEmailAlert {
                                isPresented = false
                            }
                        }
                    }
                }
                
                // 🔥 显示错误信息
                if let error = authVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Bind Email")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // 🔥 修复：关闭弹窗时重置状态
                        authVM.errorMessage = nil
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Location & Community Selection Sheet
struct CommunitySelectionSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0: Location, 1: Communities
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Location").tag(0)
                    Text("My Communities").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    locationSelectionView
                } else {
                    communitiesView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Location & Communities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Location Selection View
    private var locationSelectionView: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search cities...", text: $searchText)
                    .autocapitalization(.none)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 当前位置
            if let location = userSettings.selectedLocation {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("Current: \(location.displayName)")
                        .font(.subheadline)
                    Spacer()
                    Button("Change") {
                        Task {
                            await userSettings.selectLocation(nil)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                
                // 显示当地社区
                localCommunitiesSection
            } else {
                // 位置列表
                List {
                    ForEach(PredefinedLocations.search(query: searchText), id: \.city) { location in
                        LocationRowView(location: location) {
                            Task {
                                await userSettings.selectLocation(location)
                            }
                            searchText = ""
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            // 如果有位置但没有加载社区，则加载
            if let location = userSettings.selectedLocation, userSettings.communitiesInCity.isEmpty {
                Task {
                    await userSettings.loadCommunitiesForCity(location.city)
                }
            }
        }
    }
    
    // 当地社区列表
    private var localCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Communities in \(userSettings.selectedLocation?.city ?? "")")
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading communities...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                let localCommunities = userSettings.communitiesInCity
                
                if localCommunities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No communities in this area yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(localCommunities) { community in
                                CommunityCardView(community: community)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - My Communities View
    private var communitiesView: some View {
        VStack(spacing: 0) {
            if userSettings.isLoadingCommunities {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Loading your communities...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                let joinedCommunities = userSettings.joinedCommunities
                
                if joinedCommunities.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Communities Joined")
                            .font(.headline)
                        Text("Select a location first, then join\ncommunities in your area")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { selectedTab = 0 }) {
                            Text("Select Location")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(joinedCommunities) { community in
                            JoinedCommunityRow(community: community)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onAppear {
            Task {
                await userSettings.loadMyCommunities()
            }
        }
    }
}

// MARK: - Location Row View
struct LocationRowView: View {
    let location: UserLocation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.city)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(location.state)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Community Card View
struct CommunityCardView: View {
    let community: Community
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false  // 🚀 新增：控制详情 sheet
    
    var isMember: Bool {
        userSettings.isMember(of: community)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 可点击进入详情的区域
            Button(action: { showDetail = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(community.name)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 8) {
                            Label("\(community.memberCount)", systemImage: "person.2.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetail) {
                CommunityDetailView(community: community)
            }
            
            // 描述文字也可点击
            Button(action: { showDetail = true }) {
                Text(community.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Join/Leave Button - 独立于详情按钮
            Button(action: {
                Task {
                    isLoading = true
                    if isMember {
                        _ = await userSettings.leaveCommunity(community)
                    } else {
                        _ = await userSettings.joinCommunity(community)
                    }
                    isLoading = false
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isMember ? "checkmark.circle.fill" : "plus.circle.fill")
                    }
                    Text(isMember ? "Joined" : "Join Community")
                }
                .font(.subheadline.bold())
                .foregroundColor(isMember ? .green : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isMember ? Color.green.opacity(0.1) : Color.cyan)
                .cornerRadius(10)
            }
            .buttonStyle(.plain) // 🚀 防止按钮触发 NavigationLink
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Joined Community Row
struct JoinedCommunityRow: View {
    let community: Community
    @ObservedObject private var userSettings = UserSettings.shared
    @State private var isLoading = false
    @State private var showDetail = false  // 🔥 使用 sheet
    
    var body: some View {
        Button(action: { showDetail = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Label(community.fullLocation, systemImage: "mappin.circle.fill")
                        Label("\(community.memberCount)", systemImage: "person.2.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        isLoading = true
                        _ = await userSettings.leaveCommunity(community)
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Leave")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CommunityDetailView(community: community)
        }
    }
}

// 保留旧的 CommunityRowView 以兼容
struct CommunityRowView: View {
    let community: Community
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        CommunityCardView(community: community)
    }
}
