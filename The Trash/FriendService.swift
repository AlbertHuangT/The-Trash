//
//  FriendService.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Contacts
import Supabase
import SwiftUI
import Combine

// MARK: - Models

// FriendUser 依然保留，确保它是 Sendable 的
struct FriendUser: Decodable, Identifiable, Sendable {
    let id: UUID
    let username: String
    let credits: Int
    let email: String?
    let phone: String?
}

// MARK: - Service

@MainActor
class FriendService: ObservableObject {
    @Published var friends: [FriendUser] = []
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    // 🔥 添加错误消息
    @Published var errorMessage: String?
    
    // 🚀 优化：添加缓存和节流
    private var lastFetchTime: Date?
    private let cacheValidDuration: TimeInterval = 60 // 缓存有效期60秒
    private var fetchTask: Task<Void, Never>?
    
    private let contactStore = CNContactStore()
    private let client = SupabaseManager.shared.client
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        // 🔥 每次调用都重新检查权限状态（用户可能从设置中更改了权限）
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccessAndFetch() async {
        // 🔥 先更新权限状态
        checkPermission()
        
        // 🔥 如果已经授权，直接获取联系人
        if permissionStatus == .authorized {
            await fetchContactsAndSync()
            return
        }
        
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            // 🔥 更新权限状态
            checkPermission()
            
            if granted {
                await fetchContactsAndSync()
            }
        } catch {
            print("❌ Contact access denied: \(error)")
            errorMessage = "Contact access denied"
            // 🔥 更新权限状态
            checkPermission()
        }
    }
    
    func fetchContactsAndSync(forceRefresh: Bool = false) async {
        // 🔥 先检查权限
        checkPermission()
        guard permissionStatus == .authorized else {
            errorMessage = "Contact permission not granted"
            return
        }
        
        // 🚀 优化：检查缓存是否有效
        if !forceRefresh, 
           !friends.isEmpty,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValidDuration {
            return // 使用缓存数据
        }
        
        // 🚀 优化：取消之前的请求
        fetchTask?.cancel()
        
        self.isLoading = true
        self.errorMessage = nil
        
        // 1. 读取本地通讯录 (使用 Task.detached 在后台线程执行)
        let (emails, phones) = await Task.detached { () -> ([String], [String]) in
            let store = CNContactStore()
            let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            
            var emails: [String] = []
            var phones: [String] = []
            
            try? store.enumerateContacts(with: request) { contact, _ in
                // 提取邮箱
                for email in contact.emailAddresses {
                    emails.append(email.value as String)
                }
                // 提取手机号 (清洗非数字字符)
                for phone in contact.phoneNumbers {
                    let raw = phone.value.stringValue
                    // 仅保留数字
                    let clean = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    
                    if !clean.isEmpty {
                        phones.append(clean)
                        // 如果包含加号 (如 +1)，也保留原始格式作为备选
                        if raw.contains("+") {
                            phones.append(raw)
                        }
                    }
                }
            }
            return (emails, phones)
        }.value
            
        // 2. 调用 Supabase RPC 获取匹配的好友
        do {
            let params: [String: [String]] = [
                "p_emails": emails,
                "p_phones": phones
            ]
            
            let matchedFriends: [FriendUser] = try await client
                .rpc("find_friends_leaderboard", params: params)
                .execute()
                .value
            
            // 🚀 优化：检查任务是否被取消
            guard !Task.isCancelled else {
                self.isLoading = false
                return
            }
            
            self.friends = matchedFriends
            self.lastFetchTime = Date() // 🚀 更新缓存时间
        } catch {
            print("❌ Failed to sync contacts: \(error)")
            // 🔥 FIX: 只在非取消错误时设置错误消息
            if !Task.isCancelled {
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
            }
        }
        
        self.isLoading = false
    }
}
