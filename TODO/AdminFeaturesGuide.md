# 社区管理员权限功能文档

## 📋 功能概览

这套管理员系统为社区管理员(OP)提供了强大的管理工具：

### 核心功能
1. **申请审批系统** - 审批新成员加入申请
2. **社区信息编辑** - 修改描述、规则、设置
3. **成员管理** - 查看、移除成员
4. **积分发放** - 给活动参与者批量发放积分
5. **操作日志** - 审计所有管理员操作

---

## 🗄️ 数据库部署

### 1. 运行迁移文件

将 `005_admin_permissions.sql` 文件在Supabase中执行：

```bash
# 使用Supabase CLI
supabase db push

# 或者在Supabase Dashboard -> SQL Editor中直接执行
```

### 2. 新增的数据表

**community_join_applications** - 加入申请表
- 存储用户的加入申请
- 状态：pending（待审批）、approved（已批准）、rejected（已拒绝）

**admin_action_logs** - 管理员操作日志
- 记录所有管理员操作
- 用于审计和追溯

**credit_grants** - 积分发放记录
- 记录每次积分发放
- 包含发放者、接收者、数量、理由

### 3. 新增的RPC函数

```sql
-- 权限检查
is_community_admin(community_id, user_id)

-- 申请管理
apply_to_join_community(community_id, message)
get_pending_applications(community_id)
review_join_application(application_id, approve, rejection_reason)

-- 社区管理
update_community_info(community_id, description, welcome_message, rules, requires_approval)
remove_community_member(community_id, user_id, reason)

-- 积分管理
grant_event_credits(event_id, user_ids[], credits_per_user, reason)

-- 数据查询
get_community_members_admin(community_id)
get_admin_action_logs(community_id, limit)
```

---

## 📱 Swift代码集成

### 1. 添加文件到项目

将 `CommunityAdminFeatures.swift` 添加到你的Xcode项目中：

```
The Trash/
├── Services/
│   └── CommunityService.swift (扩展了管理员API)
└── Views/
    └── Admin/
        ├── CommunityAdminDashboard.swift
        ├── EditCommunityInfoView.swift
        ├── CommunityMembersListView.swift
        ├── GrantCreditsView.swift
        └── AdminLogsView.swift
```

### 2. 在社区详情页添加管理入口

修改 `CommunityDetailView.swift`：

```swift
struct CommunityDetailView: View {
    let community: Community
    @ObservedObject var userSettings = UserSettings.shared
    @State private var showAdminDashboard = false
    
    var body: some View {
        ScrollView {
            // ... 现有内容
            
            // 管理员入口（仅管理员可见）
            if userSettings.adminCommunities.contains(where: { $0.id == community.id }) {
                adminSection
            }
        }
        .sheet(isPresented: $showAdminDashboard) {
            CommunityAdminDashboard(community: community)
        }
    }
    
    private var adminSection: some View {
        VStack(spacing: 12) {
            Button(action: { showAdminDashboard = true }) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.orange)
                    Text("管理员面板")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.1), Color.red.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}
```

### 3. 修改加入社区逻辑

更新 `CommunityService.swift` 中的 `joinCommunity` 方法：

```swift
// 旧代码（直接加入）
func joinCommunity(_ communityId: String) async -> Bool {
    // ...
}

// 新代码（支持审批）
func joinCommunity(_ communityId: String, message: String? = nil) async -> (success: Bool, requiresApproval: Bool) {
    do {
        struct Response: Codable {
            let success: Bool
            let message: String
            let requiresApproval: Bool
            
            enum CodingKeys: String, CodingKey {
                case success
                case message
                case requiresApproval = "requires_approval"
            }
        }
        
        let response: Response = try await client
            .rpc("apply_to_join_community", params: [
                "p_community_id": communityId,
                "p_message": message
            ])
            .execute()
            .value
        
        return (response.success, response.requiresApproval)
    } catch {
        print("❌ Join community error: \(error)")
        return (false, false)
    }
}
```

### 4. 在活动详情页添加积分发放

修改 `EventDetailSheet.swift`（或活动详情页）：

```swift
struct EventDetailSheet: View {
    let event: CommunityEvent
    @State private var showGrantCredits = false
    @State private var isEventAdmin = false
    
    var body: some View {
        // ... 现有内容
        
        .toolbar {
            // 如果是管理员或活动创建者，显示"发放积分"按钮
            if isEventAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showGrantCredits = true }) {
                        Image(systemName: "star.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showGrantCredits) {
            GrantCreditsView(event: event)
        }
        .task {
            if let communityId = event.communityId {
                isEventAdmin = await CommunityService.shared.isAdmin(communityId: communityId)
            }
        }
    }
}
```

---

## 🎨 UI使用流程

### 管理员面板访问路径

```
社区详情页
    ↓
[管理员面板] 按钮（橙色渐变）
    ↓
管理员面板
    ├─ 待审批申请（显示数量徽章）
    ├─ 编辑社区信息
    ├─ 管理成员
    └─ 操作日志
```

### 1️⃣ 审批新成员申请

```
管理员面板
    ↓
[待审批申请] 列表
    ↓
每条申请显示：
    - 用户名、头像
    - 积分数
    - 申请留言
    - 申请时间
    ↓
操作：
    [批准] 绿色按钮 → 用户立即加入社区
    [拒绝] 红色按钮 → 填写拒绝理由（可选）→ 申请被拒绝
```

**效果**：
- 批准后，用户会自动成为社区成员
- 拒绝后，用户可以看到拒绝理由（如果有）
- 所有操作都会被记录在日志中

### 2️⃣ 编辑社区信息

```
管理员面板
    ↓
[编辑社区信息]
    ↓
可编辑字段：
    - 社区描述
    - 欢迎消息（新成员看到）
    - 社区规则
    - 加入需要审批（开关）
    ↓
[保存更改]
```

**加入审批开关**：
- **关闭**：用户点击"加入"后立即成为成员
- **开启**：用户点击"加入"后创建申请，需要管理员审批

### 3️⃣ 管理成员

```
管理员面板
    ↓
[管理成员]
    ↓
成员列表显示：
    - 用户名、头像
    - 管理员标签（橙色）
    - 积分数
    - 加入时间
    ↓
点击成员 → 成员详情
    ↓
[移除成员] 红色按钮
    ↓
确认对话框
    - 输入移除理由（可选）
    - 确认移除
```

**注意**：不能移除其他管理员

### 4️⃣ 发放活动积分

```
活动详情页（管理员视图）
    ↓
工具栏右上角 [★] 按钮
    ↓
积分发放界面
    ├─ 活动信息（标题、参与人数）
    ├─ 积分设置
    │   ├─ 每人发放数量（1-100）
    │   └─ 发放理由
    ├─ 参与者列表（多选）
    │   ├─ [全选] 开关
    │   └─ 单独勾选每个用户
    ├─ 总计显示
    └─ [确认发放] 按钮
```

**流程示例**：

1. 管理员打开已结束的清洁活动
2. 点击右上角星星图标
3. 设置每人发放 20 积分
4. 填写理由："参与社区清洁活动"
5. 全选所有参与者（或单独选择）
6. 确认发放
7. 系统批量发放积分
8. 显示成功提示："已为 15 名参与者发放积分"

**限制**：
- 每人每次发放：1-1000 积分
- 只能给已报名的用户发放
- 需要填写发放理由

### 5️⃣ 查看操作日志

```
管理员面板
    ↓
[操作日志]
    ↓
日志列表显示：
    - 操作类型图标（彩色）
    - 操作描述
    - 操作者
    - 目标对象
    - 时间
```

**日志类型**：
- ✅ 批准加入（绿色）
- ❌ 拒绝申请（红色）
- 🚫 移除成员（红色）
- ⭐ 发放积分（橙色）
- ✏️ 编辑社区（蓝色）

---

## 🔐 权限控制

### 谁是管理员？

1. **社区创建者**：自动成为管理员
2. **被提升的成员**：需要手动在数据库中修改

```sql
-- 将用户提升为管理员
UPDATE user_community_memberships
SET status = 'admin'
WHERE user_id = '<用户UUID>' 
AND community_id = '<社区ID>';
```

### 权限检查机制

所有管理员功能都会：
1. 检查用户是否登录
2. 检查用户是否是该社区管理员
3. 记录操作日志

**前端检查**：
```swift
// 检查是否是管理员
let isAdmin = await CommunityService.shared.isAdmin(communityId: communityId)

// 或者使用本地缓存
let isAdmin = userSettings.adminCommunities.contains(where: { $0.id == communityId })
```

**后端检查**：
```sql
-- 所有RPC函数都会调用
IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
END IF;
```

---

## 📊 实际使用场景

### 场景1：新社区创建后的配置

```
1. 用户创建社区 "San Diego环保先锋"
   → 自动成为管理员

2. 进入管理员面板
   → 编辑社区信息

3. 设置：
   - 描述："致力于圣地亚哥地区的环保事业"
   - 欢迎消息："欢迎加入！请先阅读社区规则"
   - 规则："1. 尊重他人 2. 积极参与 3. 保护环境"
   - 开启"加入需要审批"

4. 保存
   → 现在新用户需要申请才能加入
```

### 场景2：审批新成员

```
1. 用户Alice申请加入社区
   留言："我热爱环保，希望能参与活动！"

2. 管理员收到通知（待审批申请徽章显示 1）

3. 打开管理员面板
   → 看到Alice的申请
   → 显示：Alice，积分150，申请留言

4. 管理员点击[批准]
   → Alice立即成为成员
   → 收到欢迎消息

5. 申请记录状态更新为"approved"
6. 操作日志记录："批准 Alice 加入"
```

### 场景3：活动后发放积分

```
1. 社区组织了"海滩清洁日"活动
   - 20人报名
   - 18人签到参加

2. 活动结束后，管理员打开活动详情

3. 点击右上角⭐图标

4. 发放积分界面：
   - 每人发放：30积分
   - 理由："参与海滩清洁活动"
   - 全选18个签到者

5. 确认发放
   → 系统为18人各增加30积分
   → 总计发放：540积分

6. 操作日志记录：
   "发放积分给18名参与者，共540积分"
```

### 场景4：处理问题成员

```
1. 管理员发现用户Bob多次发布不当内容

2. 进入管理员面板 → 管理成员

3. 找到Bob，点击查看详情

4. 点击[移除成员]
   填写理由："多次违反社区规则"

5. 确认移除
   → Bob被移出社区
   → 无法再参与社区活动

6. 操作日志记录：
   "移除成员 Bob，理由：多次违反社区规则"
```

---

## 🎯 最佳实践

### 1. 审批申请

✅ **建议做法**：
- 查看申请者的积分（反映活跃度）
- 阅读申请留言
- 对于可疑申请，可以先拒绝并说明理由

❌ **避免**：
- 不看留言就批准所有申请
- 拒绝时不给理由

### 2. 发放积分

✅ **建议做法**：
- 明确发放理由（"参与XX活动"）
- 根据活动难度设定合理积分（10-50分）
- 只给真正参与的用户发放

❌ **避免**：
- 发放过高积分（破坏平衡）
- 随意发放给未参与的用户
- 不填写发放理由

### 3. 社区规则

✅ **建议做法**：
- 制定清晰的社区规则
- 在欢迎消息中提醒新成员阅读规则
- 对于需要高质量内容的社区，开启审批

❌ **避免**：
- 规则过于复杂
- 从不审批（可能导致质量下降）

---

## 🔧 常见问题

### Q1: 如何添加更多管理员？

**A**: 目前需要在数据库中手动操作：

```sql
UPDATE user_community_memberships
SET status = 'admin'
WHERE user_id = '<新管理员UUID>' 
AND community_id = '<社区ID>';
```

**未来改进**：可以添加"提升为管理员"功能到UI中。

### Q2: 管理员能看到所有成员的个人信息吗？

**A**: 管理员只能看到：
- 用户名
- 积分
- 加入时间
- 社区内的活动记录

**不能看到**：
- 邮箱、手机号等隐私信息
- 其他社区的活动记录

### Q3: 积分发放可以撤销吗？

**A**: 目前不支持自动撤销。如果需要撤销，需要：
1. 记录错误发放的数量
2. 在下次发放时减去对应数量
3. 或者联系超级管理员在数据库中手动调整

**未来改进**：添加"撤销积分"功能。

### Q4: 删除社区会怎样？

**A**: 目前数据库有级联删除：
- 删除社区 → 自动删除
  - 成员关系
  - 申请记录
  - 操作日志
  - 社区活动

**警告**：删除操作无法撤销！

### Q5: 如何防止管理员滥用权限？

**A**: 系统有多重保护：
1. **操作日志**：所有操作都被记录
2. **积分限制**：单次发放最多1000积分
3. **权限隔离**：管理员只能管理自己的社区
4. **审计功能**：超级管理员可以查看所有日志

---

## 📈 未来扩展功能

### Phase 2 功能（建议添加）

1. **多级管理员**
   - Owner（所有者）
   - Admin（管理员）
   - Moderator（版主 - 只能审批申请）

2. **自动化规则**
   - 积分达到X自动通过审批
   - 连续违规N次自动封禁

3. **批量操作**
   - 批量批准/拒绝申请
   - 批量发送通知

4. **统计面板**
   - 申请通过率
   - 成员增长曲线
   - 活动参与率

5. **举报系统**
   - 成员举报不当内容
   - 管理员处理举报

---

## 🎉 结语

这套管理员系统让你能够：
- ✅ 控制社区质量（审批制度）
- ✅ 激励用户参与（积分发放）
- ✅ 灵活调整规则（编辑功能）
- ✅ 追踪管理操作（日志系统）

记住：**管理员是社区的守护者，而不是独裁者！** 

用心管理，创建一个积极、活跃、友善的社区吧！🌟
