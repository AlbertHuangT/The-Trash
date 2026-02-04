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
    @Published var isAuthorized: Bool = false
    
    private let client = SupabaseManager.shared.client
    
    init() {
        checkAuthorizationStatus()
    }
    
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
                self.isAuthorized = granted
                if !granted { self.permissionError = true }
            }
            
            if !granted { return }
            
            // 🔥 Fix: 将耗时的通讯录遍历移到后台线程，避免阻塞主线程
            // 使用 Task.detached 确保不在 MainActor 上运行
            let phoneNumbers = try await Task.detached(priority: .userInitiated) { () -> [String] in
                let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var numbers: [String] = []
                
                try store.enumerateContacts(with: request) { contact, stop in
                    for number in contact.phoneNumbers {
                        let raw = number.value.stringValue
                        let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        if digits.count >= 10 {
                            numbers.append(String(digits.suffix(10)))
                        }
                    }
                }
                return numbers
            }.value
            
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
