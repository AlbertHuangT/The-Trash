# The Trash

The Trash 是一个垃圾分类与环保互动产品仓库。

当前主线客户端：

- `the-trash-rn/`：Expo + React Native（主线）

已归档客户端（Legacy）：

- `legacy/swift-ios/The Trash/`：SwiftUI iOS 版本（不再主线维护）

## 仓库结构

```text
.
├── the-trash-rn/                  # Expo / RN 代码（主线）
├── legacy/swift-ios/              # 归档 Swift 工程
├── supabase/migrations/           # Supabase 迁移唯一来源
├── scripts/                       # 契约与迁移检查脚本
├── Makefile
└── docs/
```

## 1) React Native 开发（主线）

详细说明见 `the-trash-rn/README.md`。

### 环境

- Node.js 20+
- pnpm 10+
- Xcode / Android Studio（按平台需要）

### 常用命令

```bash
make install
make start
make ios
make android
make lint
```

也可直接在 RN 目录执行：

```bash
cd the-trash-rn
pnpm install
pnpm expo start --dev-client --tunnel --clear
```

## 2) 数据库迁移（Supabase）

### 迁移执行

```bash
supabase db push --project-ref <your-project-ref>
```

`project-ref` 就是 Supabase 项目短 ID（Dashboard URL 里 `project/<ref>` 这段）。

### 契约与迁移检查

```bash
make contracts
make migrations-check
make doctor
```

说明：

- `supabase/migrations/` 是唯一真相源。
- `make migrations-sync` 仅保留兼容入口，现为 no-op。

建议流程：

1. 新增 `supabase/migrations/*.sql`
2. `supabase db push --project-ref <ref>`
3. `make contracts`
4. `make migrations-check`
5. 提交 `supabase/migrations`

## 3) Swift iOS（Legacy 归档）

Swift 工程已归档，仅在需要回溯时使用：

```bash
make legacy-open
```

或直接：

```bash
open "legacy/swift-ios/The Trash.xcodeproj"
```

## 4) 常见问题

- `Could not find table ... in schema cache`
  - 远端 schema 未应用完整迁移，先执行 `supabase db push`。
- Expo iOS 出现 ATS 明文连接报错
  - 使用 `pnpm expo start --dev-client --tunnel --clear`。
- `Authentication with Apple Developer Portal failed / no team`
  - iOS 云构建不可用时，可先走本地 Xcode 真机安装或 Android 开发流程。
