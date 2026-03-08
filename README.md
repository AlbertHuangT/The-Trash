# Smart Sort

<p align="center">
  <strong>An iOS-native trash sorting app with on-device AI, Arena gameplay, and community-driven sustainability loops.</strong>
</p>

<p align="center">
  <a href="https://github.com/AlbertHuangT/Smart-Sort">
    <img src="https://img.shields.io/badge/platform-iOS-4F7D78?style=for-the-badge&logo=apple&logoColor=white" alt="iOS">
  </a>
  <a href="https://developer.apple.com/xcode/swiftui/">
    <img src="https://img.shields.io/badge/UI-SwiftUI-4E6532?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  </a>
  <a href="https://supabase.com/">
    <img src="https://img.shields.io/badge/backend-Supabase-2A9D8F?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase">
  </a>
  <a href="https://developer.apple.com/documentation/coreml">
    <img src="https://img.shields.io/badge/ML-CoreML-C96B2C?style=for-the-badge&logo=apple&logoColor=white" alt="CoreML">
  </a>
  <a href="./docs/ARCHITECTURE.md">
    <img src="https://img.shields.io/badge/docs-Architecture-8A5A6B?style=for-the-badge&logo=readme&logoColor=white" alt="Architecture">
  </a>
  <a href="./docs/UI_GUIDELINES.md">
    <img src="https://img.shields.io/badge/design-UI%20Guidelines-6B7A40?style=for-the-badge&logo=storybook&logoColor=white" alt="UI Guidelines">
  </a>
  <a href="https://creativecommons.org/licenses/by-sa/4.0/">
    <img src="https://img.shields.io/badge/license-CC%20BY--SA%204.0-7A4A2E?style=for-the-badge" alt="License">
  </a>
</p>

## Overview

Smart Sort is a native iOS app that helps users identify trash categories with on-device AI, then keeps them engaged through Arena challenges, community events, leaderboards, and feedback-driven data improvement.

The project combines:

- On-device classification with CoreML
- A custom SwiftUI design system (`TrashTheme`)
- Supabase-backed auth, RPC, storage, and realtime flows
- Game loops for repeat engagement
- Community tooling for local sustainability participation

## What It Does

### Verify

- Uses the camera to identify an item locally
- Runs blur and face checks before feedback upload
- Supports correction flows that feed a quiz-candidate pipeline
- Verify rewards require a linked email or phone

### Arena

- Classic, Speed Sort, Streak, Daily Challenge, and Duel
- Solo modes use server-verified sessions and server-side answer validation
- Duel uses backend validation plus realtime synchronization
- Quiz images are served from Supabase Storage
- Arena rewards are only credited to linked accounts

### Community

- Browse and join communities by location
- Create and join events
- Support community admin tools and moderation flows

### Progress

- Credits, achievements, badges, and leaderboards
- Friend and community engagement loops

## Stack

| Layer | Tech |
| --- | --- |
| App | SwiftUI |
| ML | CoreML (`MobileCLIPImage.mlpackage`) |
| Backend | Supabase Auth / Postgres / RPC / Storage / Realtime |
| Package manager | Swift Package Manager |
| Design system | `TrashTheme` + shared primitives |

## Project Structure

```text
Smart Sort/
├── App/
├── Models/
├── Services/
├── Theme/
├── Views/
│   ├── Verify/
│   ├── Arena/
│   ├── Community/
│   ├── Leaderboard/
│   ├── Account/
│   ├── Auth/
│   ├── Admin/
│   └── Shared/
└── trash_knowledge.json

supabase/
└── migrations/

scripts/
├── check_backend_contracts.sh
├── manage_app_admin_migration.sh
└── migrate_arena_quiz_images.sh

docs/
├── ARCHITECTURE.md
└── UI_GUIDELINES.md
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [UI Guidelines](docs/UI_GUIDELINES.md)
- [Audit](AUDIT.md)

## Getting Started

### Requirements

- Xcode 16+
- A configured Supabase project
- Local `Secrets.swift`
- `MobileCLIPImage.mlpackage` present in `Smart Sort/`

### Build

```bash
xcodebuild -project "Smart Sort.xcodeproj" \
  -scheme "Smart Sort" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### Device Build

```bash
xcodebuild -project "Smart Sort.xcodeproj" \
  -scheme "Smart Sort" \
  -destination 'generic/platform=iOS' \
  build
```

## Backend Workflow

Apply migrations:

```bash
supabase db push --linked --yes
```

Check RPC drift and direct table access:

```bash
scripts/check_backend_contracts.sh
```

Bootstrap the first app reviewer:

```bash
scripts/manage_app_admin_migration.sh grant <user_uuid>
supabase db push --linked --include-all --yes
```

## Current Backend Notes

- Arena solo modes are server-verified
- Arena and Verify rewards require a linked account
- Duel stale challenges are expired consistently across gameplay RPCs
- Duel ready/finished state is persisted server-side for reconnect recovery
- Recoverable Arena quiz images were migrated off third-party dead links into Supabase Storage
- Correctly confirmed Verify photos can enter `quiz_question_candidates`
- Face-containing photos are never uploaded as feedback
- Feedback images are now private and served via signed URLs
- `app_admins` can review and publish quiz candidates through the in-app `Quiz Review` flow

## Design System Notes

The app now uses a shared UI metric system aligned to Apple HIG-sized controls:

- Minimum hit target: `44pt`
- Button/input height: `50pt`
- Standard row height: `56pt`
- Corner radii: `10 / 16 / 24 / pill`

Use shared primitives before writing feature-local styling:

- `TrashButton`
- `TrashPill`
- `TrashIconButton`
- `TrashForm*`
- `TrashCard` / `.surfaceCard(...)`
- `TrashSegmentedControl`

See [UI Guidelines](docs/UI_GUIDELINES.md) for the full rules.

## Source Of Truth

- App-owned SQL logic lives in `supabase/migrations/`
- UI tokens and interaction metrics live in `TrashTheme`
- Shared component primitives should be extended before creating one-off visual systems

## License

This work is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
