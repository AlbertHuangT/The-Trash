# Smart Sort

Smart Sort 是一个 iOS 原生环保应用：用端侧 AI 识别垃圾类别，并通过 Arena、社区活动、排行榜等机制提升用户参与度。

## 核心能力

- 端侧识别：MobileCLIP + CoreML，本地推理，离线可用
- 主题化 UI：Eco Skeuomorphism（单主题，`TrashTheme`）
- 社区与活动：创建、加入、报名、管理员审批与积分发放
- Arena 对战：单人模式 + 1v1 Duel + Realtime 同步
- 排行榜：好友榜 + 社区榜

## 技术栈

- 前端：SwiftUI
- 模型：CoreML (`MobileCLIPImage.mlpackage`)
- 后端：Supabase (Auth / Postgres / RPC / Realtime / Storage)
- 依赖：`supabase-swift`（SPM）

## 项目结构（当前）

```text
Smart Sort/
├── App/
│   ├── Smart_SortApp.swift
│   └── ContentView.swift
├── Theme/
│   ├── TrashTheme.swift          (single theme: Eco Skeuomorphism)
│   ├── ThemeManager.swift        (plain singleton, UIKit appearance wiring)
│   ├── TrashCorePrimitives.swift
│   ├── TrashSegmentedControl.swift
│   ├── TrashBottomTabBar.swift
│   ├── TrashPageHeader.swift
│   └── TrashFormControls.swift
├── Views/
│   ├── Verify/
│   ├── Arena/
│   ├── Leaderboard/
│   ├── Community/
│   ├── Account/
│   ├── Auth/
│   ├── Admin/
│   └── Shared/
├── Services/
├── ViewModels/          (app-level: AuthViewModel, TrashViewModel)
├── Models/
└── trash_knowledge.json

supabase/
└── migrations/
    ├── 20260303100000_001_core_schema.sql
    ├── 20260303100001_002_arena.sql
    ├── 20260303100002_003_security_and_rls.sql
    ├── 20260305100000_004_bug_reports.sql
    ├── 20260307120000_004_expire_stale_active_arena_challenges.sql
    ├── 20260307140000_005_quiz_images_bucket.sql
    ├── 20260307143000_006_self_host_arena_quiz_images.sql
    └── 20260307152000_007_enforce_stale_duel_expiry_across_rpcs.sql

scripts/
├── check_backend_contracts.sh
└── migrate_arena_quiz_images.sh

docs/
└── ARCHITECTURE.md
```

## 前后端交互梳理

详细架构与交互流程见：`docs/ARCHITECTURE.md`

关键链路：

1. Verify 链路
   - `CameraManager` 拍照 -> `PhotoModerationService` 本地模糊/人脸预检 -> `RealClassifierService` 本地分类 -> `TrashViewModel` 状态驱动 UI
   - 用户纠错 -> `FeedbackService` 上传图片与日志（含人脸照片前端直接拦截上传） -> 积分与成就触发

2. Community/Event 链路
   - `UserSettings` 位置 -> `CommunityService` RPC 拉取社区/活动
   - 加入社区、活动报名、管理员操作全部通过 RPC

3. Arena 链路
   - `ArenaService` 处理挑战创建/应答/提交
   - `DuelRealtimeManager` 通过 Realtime 广播同步对战状态
   - Arena 图片由 Supabase Storage `quiz-images` 提供，前端统一经过 `ArenaImageLoader`

## 构建与运行

要求：Xcode 16+，iOS deployment target 按工程设置。

```bash
open "Smart Sort.xcodeproj"

xcodebuild -project "Smart Sort.xcodeproj" \
  -scheme "Smart Sort" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

真机构建：

```bash
xcodebuild -project "Smart Sort.xcodeproj" \
  -scheme "Smart Sort" \
  -destination 'generic/platform=iOS' \
  build
```

## 配置

1. 本地创建 `Secrets.swift`（不要提交）
2. 将 `MobileCLIPImage.mlpackage` 放入 `Smart Sort/`
3. 确保 Supabase 项目已应用迁移

## 质量检查

### 1) 编译检查

```bash
xcodebuild -project "Smart Sort.xcodeproj" -scheme "Smart Sort" -destination 'generic/platform=iOS' build
```

### 2) 后端契约检查（新增）

```bash
scripts/check_backend_contracts.sh
```

该脚本会对比：
- Swift 中实际 `rpc("...")` 调用
- `supabase/migrations` 中函数定义

用于发现前后端契约漂移。

## 当前后端状态（摘要）

- Arena 题图已从失效的第三方 Unsplash 外链迁到 Supabase Storage；当前恢复了 21 张活题，11 张死链题目已停用
- Duel 收件箱会自动过期陈旧的 `accepted` / `in_progress` 挑战；核心 Duel RPC 也统一执行同样的 stale-active 过期校验
- Arena 图片加载已统一到共享 loader，支持缓存、请求去重、失败态和重试
- Verify 新增本地照片预检：模糊照片会在识别前拦截；含人脸照片仍可识别，但不能上传反馈
- `scripts/check_backend_contracts.sh` 仍用于检测 Swift RPC 与 SQL migration 定义是否一致

## 注意事项

- `supabase/migrations/` 是 SQL 唯一 source of truth
- `member_count` 和 `participant_count` 由数据库触发器独占维护，RPC 函数中不得手动更新
- 若改动 RPC 名称，必须同步更新对应 Service 调用和迁移
- 运行 `scripts/check_backend_contracts.sh` 可检测前后端契约漂移

## License

This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
