# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**The Trash** is a native iOS app (SwiftUI) that helps users identify and sort trash using on-device AI (MobileCLIP image embeddings + cosine similarity against a knowledge base). It includes gamification (credits/points), community features, events, leaderboards, and an arena quiz mode.

**Bundle ID:** `com.Albert.The-Trash`
**Deep link scheme:** `thetrash://`
**Language:** Swift, targeting iOS

## Build & Run

This is an Xcode project (`The Trash.xcodeproj`). There are no command-line build scripts, test suites, or linters configured. Build and run via Xcode or:
```
xcodebuild -project "The Trash.xcodeproj" -scheme "The Trash" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Dependencies are managed via Swift Package Manager (resolved in the Xcode project, not a standalone Package.swift):
- `supabase-swift` (v2.41.0) — backend client

## Architecture

### App Entry & Navigation
- `The_TrashApp.swift` — App entry point. Creates `AuthViewModel` and `TrashViewModel` as `@StateObject`. Shows `LoginView` or `ContentView` based on auth session.
- `ContentView.swift` — Main `TabView` with 5 tabs: Verify, Arena, Leaderboard, Community, Events.

### Core AI Pipeline
- `RealClassifierService.swift` — Singleton. Loads `MobileCLIPImage.mlpackage` (CoreML) and `trash_knowledge.json` (embedding knowledge base) at init. Classifies images by extracting embeddings via Vision framework, then finding the best cosine-similarity match using vDSP/Accelerate. Conforms to `TrashClassifierService` protocol.
- `TrashViewModel.swift` — Orchestrates image analysis flow. Manages `AppState` (idle → analyzing → finished/error). Grants points via Supabase RPC on successful classification. Also handles user feedback/correction submissions.
- `TrashModels.swift` — `TrashAnalysisResult` and `AppState` enum definitions.

### Backend (Supabase)
All backend interaction goes through `SupabaseManager.shared.client` (singleton `SupabaseClient`). Business logic lives in Postgres RPC functions, not client-side queries.

Key services (all `@MainActor`, singleton pattern):
- `Supabase/AuthViewModel.swift` — Auth (email/password, phone OTP, anonymous, deep link verification). Listens to `authStateChanges`.
- `Supabase/CommunityService.swift` — Communities & events CRUD via RPC (`get_communities_by_city`, `join_community`, `get_nearby_events`, `register_for_event`, `create_community`, `create_event`, etc.). Uses `Sendable` param structs with nonisolated `Encodable` conformance to cross actor boundaries.
- `Supabase/FeedbackService.swift` — Uploads feedback images to Supabase Storage (`feedback_images` bucket), writes to `feedback_logs` table.
- `FriendService.swift` — Reads device contacts (Contacts framework), matches against Supabase users via `find_friends_leaderboard` RPC.

### Views
- `VerifyView.swift` / `CameraView.swift` — Camera capture → AI classification flow
- `ArenaView.swift` — Quiz mode (questions from `quiz_questions` table)
- `LeaderboardView.swift` — Friends & community leaderboards
- `CommunityTabView.swift` / `CommunityDetailView.swift` — Community browsing, joining, admin features
- `CommunityView.swift` — Nearby events discovery with location-based sorting
- `AccountView.swift` — User account, phone/email binding
- `UserSettings.swift` — `UserSettings` singleton manages selected location (persisted via UserDefaults), community membership cache, and CLLocationManager wrapper

### Database Migrations
SQL migrations are in two locations:
- `The Trash/migrations/` — numbered migrations (001-004), reference copies
- `supabase/migrations/` — timestamped migrations for Supabase CLI

## Key Patterns

- **Singleton services:** `SupabaseManager.shared`, `RealClassifierService.shared`, `CommunityService.shared`, `FeedbackService.shared`, `UserSettings.shared`
- **Actor isolation:** ViewModels and services are `@MainActor`. Supabase RPC calls that need to cross actor boundaries use free functions with `Sendable` parameter structs.
- **Secrets:** `Secrets.swift` is gitignored. The Supabase publishable key is in `SupabaseManager.swift` (this is intentional — it's a public anon key).
- **CoreML model:** `MobileCLIPImage.mlpackage` is in the app directory (gitignored via `*.mlpackage` pattern). The knowledge base `trash_knowledge.json` contains pre-computed embeddings.
- **Localization:** `Localizable.xcstrings` is present for string localization.
- **Comments in Chinese:** Many code comments are in Chinese (Mandarin). This is normal for this codebase.
