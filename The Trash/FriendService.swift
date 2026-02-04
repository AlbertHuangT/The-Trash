//
//  FriendService.swift
//  The Trash
//
//  Created by Albert Huang on 2/3/26.
//

import Contacts
import Supabase
import SwiftUI

struct AppUser: Codable, Identifiable {
    let id: UUID
    let username: String?
    let credits: Int
    // 用于 UI 显示排名的计算属性
    var rank: Int = 0
}

class FriendService: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var permissionError: Bool = false
    
    private let client = SupabaseManager.shared.client
    
    // 获取通讯录并匹配
    func findFriendsFromContacts() async {
        let store = CNContactStore()
        
        do {
            // 1. 请求权限
            let granted = try await store.requestAccess(for: .contacts)
            if !granted {
                await MainActor.run { self.permissionError = true }
                return
            }
            
            // 2. 提取手机号
            let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            
            var phoneNumbers: [String] = []
            
            try store.enumerateContacts(with: request) { contact, stop in
                for number in contact.phoneNumbers {
                    // 简单的清洗逻辑：只保留数字
                    let raw = number.value.stringValue
                    let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    // 简单匹配：取后10位 (适配不同国家码格式)
                    if digits.count >= 10 {
                        phoneNumbers.append(String(digits.suffix(10)))
                    }
                }
            }
            
            // 3. 去 Supabase 查询 (这里假设 phone 字段存的是清洗过的号码)
            // 注意：实际生产中手机号应该 Hash 后再上传对比，保护隐私
            if phoneNumbers.isEmpty { return }
            
            // 这是一个简单的模糊查询演示
            // 实际中建议让后端做这个匹配，或者精确匹配
            let response: [AppUser] = try await client
                .from("profiles")
                .select("id, username, credits")
                .order("credits", ascending: false) // 直接按积分排序
                .execute()
                .value
            
            // 4. 更新 UI
            await MainActor.run {
                self.friends = response
                // 简单的排名赋值
                for i in 0..<self.friends.count {
                    self.friends[i].rank = i + 1
                }
            }
            
        } catch {
            print("Friend Match Error: \(error)")
        }
    }
}
