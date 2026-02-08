# 管理员功能快速参考

## 🚀 快速开始（5分钟集成）

### 1. 部署数据库
```bash
# 在Supabase中执行
supabase db push
# 或上传 005_admin_permissions.sql
```

### 2. 添加代码文件
```
将 CommunityAdminFeatures.swift 添加到项目
```

### 3. 添加UI入口
```swift
// 在社区详情页添加
if userSettings.adminCommunities.contains(where: { $0.id == community.id }) {
    Button("管理员面板") {
        showAdminDashboard = true
    }
}
```

✅ 完成！现在管理员可以看到面板入口了。

---

## 📡 API速查表

### 权限检查
```swift
// 检查是否是管理员
let isAdmin = await CommunityService.shared.isAdmin(communityId: "san-diego")
```

### 申请管理
```swift
// 获取待审批申请
let applications = await service.getPendingApplications(communityId: "san-diego")

// 批准申请
let (success, message) = await service.reviewApplication(
    applicationId: applicationId,
    approve: true
)

// 拒绝申请
let (success, message) = await service.reviewApplication(
    applicationId: applicationId,
    approve: false,
    rejectionReason: "不符合社区要求"
)
```

### 社区管理
```swift
// 更新社区信息
let (success, message) = await service.updateCommunityInfo(
    communityId: "san-diego",
    description: "新的描述",
    welcomeMessage: "欢迎加入！",
    rules: "社区规则...",
    requiresApproval: true
)
```

### 成员管理
```swift
// 获取成员列表
let members = await service.getCommunityMembers(communityId: "san-diego")

// 移除成员
let (success, message) = await service.removeMember(
    communityId: "san-diego",
    userId: userId,
    reason: "违反规则"
)
```

### 积分发放
```swift
// 批量发放积分
let (success, message, count) = await service.grantEventCredits(
    eventId: eventId,
    userIds: [userId1, userId2, userId3],
    creditsPerUser: 20,
    reason: "参与清洁活动"
)
```

### 日志查询
```swift
// 获取操作日志
let logs = await service.getAdminLogs(communityId: "san-diego", limit: 50)
```

---

## 🗂️ 数据结构

### JoinApplication
```swift
struct JoinApplication {
    let id: UUID
    let userId: UUID
    let username: String
    let userCredits: Int
    let message: String?
    let createdAt: Date
}
```

### CommunityMember
```swift
struct CommunityMember {
    let userId: UUID
    let username: String
    let credits: Int
    let status: String          // "member" 或 "admin"
    let joinedAt: Date
    let isAdmin: Bool
}
```

### AdminActionLog
```swift
struct AdminActionLog {
    let id: UUID
    let adminUsername: String
    let actionType: String      // 见下方
    let targetUsername: String?
    let details: [String: Any]?
    let createdAt: Date
}

// actionType 可能的值：
// - "approve_member"   批准加入
// - "reject_member"    拒绝申请
// - "remove_member"    移除成员
// - "grant_credits"    发放积分
// - "edit_community"   编辑社区
// - "edit_event"       编辑活动
// - "delete_event"     删除活动
```

---

## 🎨 UI组件使用

### 管理员面板
```swift
// 显示完整的管理面板
CommunityAdminDashboard(community: community)
```

### 编辑社区信息
```swift
// 编辑社区描述、规则等
EditCommunityInfoView(community: community)
```

### 成员列表
```swift
// 查看和管理成员
CommunityMembersListView(communityId: communityId)
```

### 发放积分
```swift
// 为活动参与者发放积分
GrantCreditsView(event: event)
```

### 操作日志
```swift
// 查看管理员操作历史
AdminLogsView(communityId: communityId)
```

---

## 🔐 权限矩阵

| 功能 | 普通成员 | 管理员 | 创建者 |
|------|----------|--------|--------|
| 加入社区 | ✅ | ✅ | ✅ |
| 查看成员列表 | ✅ | ✅ | ✅ |
| 审批申请 | ❌ | ✅ | ✅ |
| 编辑社区信息 | ❌ | ✅ | ✅ |
| 移除成员 | ❌ | ✅ | ✅ |
| 发放积分 | ❌ | ✅ | ✅ |
| 查看操作日志 | ❌ | ✅ | ✅ |
| 删除社区 | ❌ | ❌ | ✅ |
| 提升管理员 | ❌ | ❌ | ✅ |

---

## 🎯 常用代码片段

### 检查管理员权限并显示按钮
```swift
struct CommunityDetailView: View {
    @State private var isAdmin = false
    
    var body: some View {
        VStack {
            // 内容...
            
            if isAdmin {
                adminControls
            }
        }
        .task {
            isAdmin = await CommunityService.shared.isAdmin(communityId: community.id)
        }
    }
    
    private var adminControls: some View {
        Button("管理员面板") {
            // 打开面板
        }
    }
}
```

### 处理申请审批
```swift
func handleApplication(approve: Bool) async {
    let (success, message) = await service.reviewApplication(
        applicationId: application.id,
        approve: approve,
        rejectionReason: approve ? nil : reason
    )
    
    if success {
        // 刷新列表
        await loadApplications()
        
        // 显示提示
        showAlert(message)
    }
}
```

### 批量发放积分
```swift
func grantCreditsToAll() async {
    // 获取所有参与者ID
    let userIds = participants.map { $0.userId }
    
    // 发放积分
    let (success, message, count) = await service.grantEventCredits(
        eventId: event.id,
        userIds: userIds,
        creditsPerUser: 20,
        reason: "活动参与奖励"
    )
    
    if success {
        print("成功发放给 \(count) 人")
    }
}
```

---

## ⚡ 性能优化提示

### 1. 缓存管理员状态
```swift
// ❌ 不好：每次都查询
Button("管理") {
    if await service.isAdmin(communityId: id) {
        // ...
    }
}

// ✅ 好：缓存结果
@State private var isAdmin = false

.task {
    isAdmin = await service.isAdmin(communityId: id)
}

Button("管理") {
    if isAdmin {
        // ...
    }
}
```

### 2. 分页加载日志
```swift
// 默认加载50条
let logs = await service.getAdminLogs(communityId: id, limit: 50)

// 需要更多时再加载
let moreLogs = await service.getAdminLogs(communityId: id, limit: 100)
```

### 3. 批量操作
```swift
// ❌ 不好：逐个审批
for application in applications {
    await reviewApplication(application.id, approve: true)
}

// ✅ 好：未来可实现批量API
await batchReviewApplications(ids: applicationIds, approve: true)
```

---

## 🐛 调试技巧

### 检查权限问题
```swift
// 打印权限状态
let isAdmin = await service.isAdmin(communityId: id)
print("User is admin: \(isAdmin)")

// 检查用户ID
print("Current user: \(Auth.shared.currentUser?.id)")
```

### 查看API响应
```swift
// 在CommunityService中添加打印
func reviewApplication(...) async -> (Bool, String) {
    do {
        let response = try await client.rpc(...).execute().value
        print("✅ Response: \(response)")
        return (response.success, response.message)
    } catch {
        print("❌ Error: \(error)")
        return (false, "操作失败")
    }
}
```

### 测试权限控制
```sql
-- 在Supabase SQL Editor中测试
SELECT public.is_community_admin('san-diego', '<用户UUID>');

-- 应该返回 true 或 false
```

---

## 📋 集成清单

开发前检查：
- [ ] 数据库迁移文件已执行
- [ ] Swift代码文件已添加到项目
- [ ] CommunityService扩展已合并
- [ ] UI入口已添加

测试清单：
- [ ] 管理员可以看到面板入口
- [ ] 普通用户看不到管理功能
- [ ] 申请审批流程正常
- [ ] 积分发放成功
- [ ] 操作日志正确记录
- [ ] 权限检查生效

上线前检查：
- [ ] 所有管理员操作都有日志
- [ ] 错误处理完善
- [ ] UI反馈清晰
- [ ] 性能优化完成

---

## 🎓 学习资源

### Supabase RLS (Row Level Security)
```sql
-- 理解RLS策略
CREATE POLICY "policy_name"
ON table_name
FOR SELECT
USING (auth.uid() = user_id);
```

### Swift异步编程
```swift
// async/await
let result = await service.getData()

// Task
Task {
    await updateUI()
}

// @MainActor
@MainActor
class ViewModel: ObservableObject {
    // 所有发布的属性会在主线程更新
}
```

---

## 🆘 常见错误及解决

### 错误1: "Permission denied"
**原因**: 用户不是管理员
**解决**: 
```sql
-- 检查membership表
SELECT * FROM user_community_memberships
WHERE user_id = '<用户UUID>' 
AND community_id = '<社区ID>';

-- status应该是'admin'
```

### 错误2: "Application not found"
**原因**: 申请ID不存在或已处理
**解决**: 刷新申请列表

### 错误3: "Cannot remove admin"
**原因**: 试图移除管理员
**解决**: 只能移除普通成员

### 错误4: 积分发放失败
**原因**: 
1. 用户未报名该活动
2. 积分数量超出范围(1-1000)
**解决**: 检查参与者列表和积分数量

---

## 📞 技术支持

如果遇到问题：

1. **检查日志**: 查看Supabase日志和Xcode控制台
2. **验证权限**: 确认用户是管理员
3. **测试API**: 在Supabase Dashboard中测试RPC函数
4. **查看文档**: 参考完整文档 `AdminFeaturesGuide.md`

---

## 🎉 快速启动示例

```swift
// 1. 在App中初始化
@main
struct MyApp: App {
    init() {
        // Supabase已配置
    }
}

// 2. 在社区详情页添加
struct CommunityDetailView: View {
    @State private var showAdmin = false
    @State private var isAdmin = false
    
    var body: some View {
        ScrollView {
            // 内容...
            
            if isAdmin {
                Button("管理员面板") { showAdmin = true }
            }
        }
        .sheet(isPresented: $showAdmin) {
            CommunityAdminDashboard(community: community)
        }
        .task {
            isAdmin = await CommunityService.shared.isAdmin(
                communityId: community.id
            )
        }
    }
}

// 3. 完成！🎉
```

---

祝开发顺利！💪
