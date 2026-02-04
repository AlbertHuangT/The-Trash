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

struct AppUser: Codable, Identifiable {
    let id: UUID
    let username: String?
    let credits: Int
    var rank: Int = 0
}

class FriendService: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var permissionError: Bool = false
    @Published var isAuthorized: Bool = false // ✨ 新增：记录权限状态
    
    private let client = SupabaseManager.shared.client
    
    init() {
        checkAuthorizationStatus() // 初始化时检查权限
    }
    
    // ✨ 新增：检查当前权限状态
    func checkAuthorizationStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        DispatchQueue.main.async {
            self.isAuthorized = (status == .authorized)
        }
    }
    
    // 获取通讯录并匹配
    func findFriendsFromContacts() async {
        let store = CNContactStore()
        
        do {
            // 1. 请求权限
            let granted = try await store.requestAccess(for: .contacts)
            
            await MainActor.run {
                self.isAuthorized = granted // 更新权限状态
                if !granted { self.permissionError = true }
            }
            
            if !granted { return }
            
            // 2. 提取手机号
            let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            
            var phoneNumbers: [String] = []
            
            try store.enumerateContacts(with: request) { contact, stop in
                for number in contact.phoneNumbers {
                    let raw = number.value.stringValue
                    let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if digits.count >= 10 {
                        phoneNumbers.append(String(digits.suffix(10)))
                    }
                }
            }
            
            if phoneNumbers.isEmpty { return }
            
            // 3. 去 Supabase 查询
            let response: [AppUser] = try await client
                .from("profiles")
                .select("id, username, credits")
                .order("credits", ascending: false)
                .execute()
                .value
            
            // 4. 更新 UI
            await MainActor.run {
                self.friends = response
                for i in 0..<self.friends.count {
                    self.friends[i].rank = i + 1
                }
            }
            
        } catch {
            print("Friend Match Error: \(error)")
        }
    }
}
