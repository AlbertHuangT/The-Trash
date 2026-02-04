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
            let granted = try await store.requestAccess(for: .contacts)
            
            await MainActor.run {
                self.isAuthorized = granted
                if !granted { self.permissionError = true }
            }
            
            if !granted { return }
            
            // 2. 遍历通讯录
            let phoneNumbers = try await Task.detached(priority: .userInitiated) { () -> [String] in
                let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var numbers: Set<String> = [] // 使用 Set 去重
                
                try store.enumerateContacts(with: request) { contact, stop in
                    for number in contact.phoneNumbers {
                        let raw = number.value.stringValue
                        // 🔥 FIX: 改进号码清洗逻辑
                        // 保留纯数字，移除空格、括号、横线
                        let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        
                        // 逻辑：支持 10 位(US) 和 11 位(CN) 号码
                        if digits.count == 11 {
                            // 中国号码，直接添加
                            numbers.insert(digits)
                        } else if digits.count > 10 {
                            // 其他带国家码的号码 (如 1858...)，保留后 10 位作为备选
                            numbers.insert(String(digits.suffix(10)))
                            // 也保留完整数字，以防数据库存的是完整格式
                            numbers.insert(digits)
                        } else if digits.count == 10 {
                            // 美国号码
                            numbers.insert(digits)
                        }
                    }
                }
                return Array(numbers)
            }.value
            
            if phoneNumbers.isEmpty { return }
            
            // 3. 分批查询 (Chunking) 以避免 URL 过长错误
            // Supabase 的 .in 查询如果是 GET 请求，URL 长度有限制。建议每次查 20-50 个。
            let chunkSize = 20
            var allMatchedUsers: [AppUser] = []
            
            // 将数组切片
            let chunks = stride(from: 0, to: phoneNumbers.count, by: chunkSize).map {
                Array(phoneNumbers[$0..<min($0 + chunkSize, phoneNumbers.count)])
            }
            
            for chunk in chunks {
                do {
                    let batchUsers: [AppUser] = try await client
                        .from("profiles")
                        .select("id, username, credits")
                        .in("phone", value: chunk) // 🔥 批量查询
                        .execute()
                        .value
                    
                    allMatchedUsers.append(contentsOf: batchUsers)
                } catch {
                    print("⚠️ Partial batch failed: \(error)")
                    // 即使一批失败，继续尝试下一批
                }
            }
            
            // 4. 合并结果并排序
            // 去重（防止同一个用户被多次匹配）
            let uniqueUsers = Array(Dictionary(grouping: allMatchedUsers, by: { $0.id }).values.compactMap { $0.first })
            let sortedUsers = uniqueUsers.sorted { $0.credits > $1.credits }
            
            await MainActor.run {
                self.friends = sortedUsers
                for i in 0..<self.friends.count {
                    self.friends[i].rank = i + 1
                }
            }
            
        } catch {
            print("Friend Match Error: \(error)")
        }
    }
}
