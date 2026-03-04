# The Trash

The Trash 是一个 iOS 原生环保应用：用端侧 AI 识别垃圾类别，并通过 Arena、社区活动、排行榜等机制提升用户参与度。

## 核心能力

- 端侧识别：MobileCLIP + CoreML，本地推理，离线可用
- 主题化 UI：Neumorphic / Vibrant / Eco-Skeuomorphic
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
The Trash/
├── App/
│   ├── The_TrashApp.swift
│   └── ContentView.swift
├── Theme/
│   ├── TrashTheme.swift
│   ├── TrashCorePrimitives.swift
│   ├── TrashSegmentedControl.swift
│   ├── TrashBottomTabBar.swift
│   ├── TrashPageHeader.swift
│   ├── TrashFormControls.swift
│   ├── NeumorphicTheme.swift
│   ├── VibrantTheme.swift
│   └── EcoSkeuomorphicTheme.swift
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
    ├── 001_core_schema.sql
    ├── 002_arena.sql
    └── 003_security_and_rls.sql

scripts/
└── check_backend_contracts.sh

docs/
└── ARCHITECTURE.md
```

## 前后端交互梳理

详细架构与交互流程见：`docs/ARCHITECTURE.md`

关键链路：

1. Verify 链路
   - `CameraManager` 拍照 -> `RealClassifierService` 本地分类 -> `TrashViewModel` 状态驱动 UI
   - 用户纠错 -> `FeedbackService` 上传图片与日志 -> 积分与成就触发

2. Community/Event 链路
   - `UserSettings` 位置 -> `CommunityService` RPC 拉取社区/活动
   - 加入社区、活动报名、管理员操作全部通过 RPC

3. Arena 链路
   - `ArenaService` 处理挑战创建/应答/提交
   - `DuelRealtimeManager` 通过 Realtime 广播同步对战状态

## 构建与运行

要求：Xcode 16+，iOS deployment target 按工程设置。

```bash
open "The Trash.xcodeproj"

xcodebuild -project "The Trash.xcodeproj" \
  -scheme "The Trash" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

真机构建：

```bash
xcodebuild -project "The Trash.xcodeproj" \
  -scheme "The Trash" \
  -destination 'generic/platform=iOS' \
  build
```

## 配置

1. 本地创建 `Secrets.swift`（不要提交）
2. 将 `MobileCLIPImage.mlpackage` 放入 `The Trash/`
3. 确保 Supabase 项目已应用迁移

## 质量检查

### 1) 编译检查

```bash
xcodebuild -project "The Trash.xcodeproj" -scheme "The Trash" -destination 'generic/platform=iOS' build
```

### 2) 后端契约检查（新增）

```bash
scripts/check_backend_contracts.sh
```

该脚本会对比：
- Swift 中实际 `rpc("...")` 调用
- `supabase/migrations` 中函数定义

用于发现前后端契约漂移。

## 本次代码梳理结论（摘要）

- 已修复全局"页面超宽"问题（主题背景层导致根布局被撑开）
- 社区页面切换容器改为显式渲染，规避分页容器异常
- 后端迁移从 20 个增量文件压缩为 3 个基线文件（奥卡姆剃刀）
- 修复 `member_count`/`participant_count` 双重计数 bug（触发器+RPC 手动更新并存）
- 收紧 `get_event_participants` 权限（仅管理员/活动创建者可查看）
- 删除 `The Trash/migrations/` 镜像目录，消除同步负担
- 后端契约检查脚本简化为仅对比 Swift ↔ supabase/migrations

## 注意事项

- `supabase/migrations/` 是 SQL 唯一 source of truth（3 个基线文件）
- `member_count` 和 `participant_count` 由数据库触发器独占维护，RPC 函数中不得手动更新
- 若改动 RPC 名称，必须同步更新对应 Service 调用和迁移
- 运行 `scripts/check_backend_contracts.sh` 可检测前后端契约漂移
