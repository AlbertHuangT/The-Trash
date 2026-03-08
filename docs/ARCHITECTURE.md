# Smart Sort Architecture

## 1. System Overview

The app is a SwiftUI iOS client with a local CoreML classifier and Supabase backend.

- Frontend: SwiftUI + Theme system + Feature-based views
- Local AI: `RealClassifierService` (MobileCLIP embedding + cosine similarity)
- Backend: Supabase Auth / Postgres / RPC / Realtime / Storage

## 2. Frontend Layers

### App shell

- `Smart Sort/App/Smart_SortApp.swift`
  - App entry, dependency wiring (`AuthViewModel`, `TrashViewModel`); theme applied once via `ThemeManager.shared`
- `Smart Sort/App/ContentView.swift`
  - Root tab shell and custom bottom tab bar

### Theme abstraction layer

Single theme: **Eco Skeuomorphism** (no runtime switching).

- `Smart Sort/Theme/TrashTheme.swift` — token struct + `@Environment(\.trashTheme)` key
- `Smart Sort/Theme/ThemeManager.swift` — plain singleton; wires UIKit appearance proxies on launch
- `Smart Sort/Theme/ThemeComponents.swift` — index file (splits into the files below)
- `Smart Sort/Theme/TrashCorePrimitives.swift`, `TrashBottomTabBar.swift`, `TrashPageHeader.swift`, `TrashFormControls.swift`, `TrashSegmentedControl.swift`

### Feature modules

- Verify: `Smart Sort/Views/Verify/`
- Arena: `Smart Sort/Views/Arena/`
- Leaderboard: `Smart Sort/Views/Leaderboard/`
- Community: `Smart Sort/Views/Community/`
- Account/Auth/Admin/Profile: `Smart Sort/Views/{Account,Auth,Admin,Profile}/`

## 3. Backend Layers

### Client gateway

- `Smart Sort/Services/SupabaseManager.swift`
  - Single Supabase client instance

### Domain services

- `CommunityService`: community/event/admin RPC and table access
- `ArenaService` + `DuelRealtimeManager`: duel and realtime sync
- `ArenaImageLoader`: shared Arena image cache / dedupe / response validation
- `FriendService`: contacts sync + leaderboard RPC
- `FeedbackService`: Storage upload + feedback log insert
- `PhotoModerationService`: local blur / face checks before Verify submission
- `AchievementService`: achievements and trigger RPCs

### SQL source of truth

- `supabase/migrations/` is the **sole** backend schema source
  - In practice, app-owned backend logic lives here, but `001_core_schema.sql` still assumes a small legacy bootstrap of pre-existing base objects/functions in the linked Supabase project
  - `20260303100000_001_core_schema.sql` — tables, triggers, Community/Admin/Profile/Achievement/Leaderboard/Friends RPCs
  - `20260303100001_002_arena.sql` — Arena tables, solo & duel RPCs, initial quiz seed data
  - `20260303100002_003_security_and_rls.sql` — search_path hardening, all RLS policies
  - `20260305100000_004_bug_reports.sql` — bug reports + log upload
  - `20260307120000_004_expire_stale_active_arena_challenges.sql` — inbox cleanup for stale active duels
  - `20260307140000_005_quiz_images_bucket.sql` — Arena quiz image bucket bootstrap
  - `20260307143000_006_self_host_arena_quiz_images.sql` — move recoverable quiz images to Supabase Storage and disable dead seeds
  - `20260307152000_007_enforce_stale_duel_expiry_across_rpcs.sql` — stale duel expiry enforcement in gameplay RPCs
  - `20260307170000_008_security_hardening_and_access_alignment.sql` — RLS tightening, community visibility fixes, profile/admin RPC alignment, friend privacy hardening
  - `20260307173000_009_arena_server_verified_sessions.sql` — server-verified solo Arena sessions and hidden correct answers
  - `20260307180000_010_feedback_storage_and_quiz_candidates.sql` — explicit feedback/candidate storage bootstrap and quiz candidate queue

### Key design decisions

- **Counter triggers only**: `member_count` and `participant_count` are maintained exclusively by database triggers on `user_community_memberships` and `event_registrations`. RPC functions must NOT manually update these counters.
- **`calculate_distance_km`** is a pre-existing function (created in initial Supabase setup, not in these migrations). It is used by `get_nearby_events`.

## 4. End-to-end Interaction Flows

### Verify flow

1. Camera capture (`CameraManager`)
2. Local moderation (`PhotoModerationService`)
3. Local classify (`RealClassifierService`)
4. State update (`TrashViewModel.appState`)
5. Optional feedback upload (`FeedbackService`)
5. Gamification RPC (`increment_credits` + achievements)

Behavior notes:
- Blurry photos are rejected before classification.
- Photos containing faces can still be classified locally.
- Face-containing photos are blocked from feedback upload on the client.
- Verify rewards are server-issued and require a linked account.
- Correctly confirmed photos can be uploaded into `quiz_question_candidates` for later review.
- Feedback images are stored privately and accessed with signed URLs.
- App-level reviewers in `app_admins` can approve or reject candidates in the in-app `Quiz Review` flow; approved items are copied into `quiz-images` and inserted into `quiz_questions`.
- The first `app_admins` entry is intentionally bootstrapped by migration via `scripts/manage_app_admin_migration.sh`, not by an in-app self-serve path.

### Community/Event flow

1. Location selection (`UserSettings` + `LocationManager`)
2. Events/communities fetch via `CommunityService` RPC
3. Join/register actions via RPC with optimistic UI updates
4. Admin actions (approval/remove/grant credits) via RPC

### Arena flow

1. Challenge/create/accept via `ArenaService`
2. Quiz images load via `ArenaImageLoader`
3. Solo Arena modes create server-side sessions; answers are verified server-side via RPC
4. Duel answer validation also stays on the server; public question payloads no longer include `correct_category`
4. Duel realtime broadcast sync via `DuelRealtimeManager`

Behavior notes:
- Quiz images now come from Supabase Storage `quiz-images` for the recovered active seed set.
- Arena credits are only granted to linked accounts; guest play still keeps game scores but does not mutate profile credits.
- Duel ready/finished state is persisted in `arena_challenges`, so reconnects can recover without trusting transient broadcasts.
- Stale `accepted` / `in_progress` duels expire after 30 minutes of inactivity in both inbox fetch and gameplay RPCs.

## 5. RPC Function Registry

Single source of truth for all backend RPC functions and their Swift callers.

### Community domain (001)

| # | Function | Swift caller |
|---|----------|-------------|
| 1 | `is_community_admin` | `CommunityService` |
| 2 | `can_user_create_community` | `CommunityService` |
| 3 | `can_user_create_event` | `CommunityService` |
| 4 | `create_community` | `CommunityService` |
| 5 | `create_event` | `CommunityService` |
| 6 | `get_communities_by_city` | `CommunityService` |
| 7 | `get_my_communities` | `CommunityService` |
| 8 | `apply_to_join_community` | `CommunityService` |
| 9 | `leave_community` | `CommunityService` |
| 10 | `get_nearby_events` | `CommunityService` |
| 11 | `get_community_events` | `CommunityService` |
| 12 | `register_for_event` | `CommunityService` |
| 13 | `cancel_event_registration` | `CommunityService` |
| 14 | `get_my_registrations` | `CommunityService` |
| 15 | `update_user_location` | `CommunityService` |

### Admin domain (001)

| # | Function | Swift caller |
|---|----------|-------------|
| 16 | `get_pending_applications` | `CommunityService` |
| 17 | `review_join_application` | `CommunityService` |
| 18 | `update_community_info` | `CommunityService` |
| 19 | `remove_community_member` | `CommunityService` |
| 20 | `grant_event_credits` | `CommunityService` |
| 21 | `get_community_members_admin` | `CommunityService` |
| 22 | `get_admin_action_logs` | `CommunityService` |
| 23 | `get_event_participants` | `CommunityService` |

### Profile / Credits (001)

| # | Function | Swift caller |
|---|----------|-------------|
| 24 | `increment_credits` | `TrashViewModel` |
| 25 | `increment_total_scans` | `AchievementService` |

### Achievements (001)

| # | Function | Swift caller |
|---|----------|-------------|
| 26 | `get_my_achievements` | `AchievementService` |
| 27 | `set_primary_achievement` | `AchievementService` |
| 28 | `check_and_grant_achievement` | `AchievementService` |
| 29 | `get_community_members_for_grant` | `AchievementService` |

### Leaderboard / Friends (001)

| # | Function | Swift caller |
|---|----------|-------------|
| 30 | `get_community_leaderboard` | `LeaderboardView` |
| 31 | `find_friends_leaderboard` | `FriendService` |

### Arena — Solo modes (002)

| # | Function | Swift caller |
|---|----------|-------------|
| 32 | `get_quiz_questions` | `SpeedSortVM` / `ArenaView` |
| 33 | `get_quiz_questions_batch` | `StreakModeVM` |
| 34 | `submit_streak_record` | `StreakModeVM` |
| 35 | `get_streak_leaderboard` | `StreakLeaderboardView` |
| 36 | `get_daily_challenge` | `DailyChallengeVM` |
| 37 | `submit_daily_challenge` | `DailyChallengeVM` |
| 38 | `get_daily_leaderboard` | `DailyLeaderboardView` |

### Arena — Duel (002/004/007)

| # | Function | Swift caller |
|---|----------|-------------|
| 39 | `create_arena_challenge` | `ArenaService` |
| 40 | `accept_arena_challenge` | `ArenaService` |
| 41 | `decline_arena_challenge` | `ArenaService` |
| 42 | `submit_duel_answer` | `ArenaService` |
| 43 | `complete_arena_challenge` | `ArenaService` |
| 44 | `get_my_challenges` | `ArenaService` |
| 45 | `get_challenge_questions` | `ArenaService` |

### Internal helpers (not called from Swift)

| Function | Purpose | Migration |
|----------|---------|-----------|
| `current_user_id` | Stable `auth.uid()` wrapper for RLS | 001 |
| `normalize_phone_number` | Phone normalization for friend matching | 001 |
| `can_view_community_roster` | Anti-recursion helper for membership RLS | 003 |
| `handle_community_member_count` | Trigger function for member counter | 001 |
| `handle_event_participant_count` | Trigger function for participant counter | 001 |

## 6. Audit Findings (this pass)

### Fixed / Current

- Global width overflow caused by theme background decorative layers expanding root layout
  - Fixed with container-bound sizing and clipping in theme background wrappers
- Community tab page container issue
  - Replaced `.page` `TabView` in `CommunityView` with explicit conditional rendering
- **Double-counting bug**: `member_count` / `participant_count` were updated both by triggers and manually in RPC functions. All manual counter updates removed; triggers are now the sole authority.
- **`get_event_participants` permission**: was open to any authenticated user. Now restricted to event creator or community admin.
- **Duplicate migrations**: two near-identical `admin_permissions` files and multiple functions redefined 3+ times. Consolidated into 3 clean baseline files.
- **App-side migration mirror** (`Smart Sort/migrations/`): deleted. `supabase/migrations/` is the sole source of truth.
- **Arena image drift**: recoverable quiz images are self-hosted in Supabase Storage; dead third-party seeds are disabled.
- **Arena stale duel cleanup**: no longer limited to `get_my_challenges`; gameplay RPCs enforce the same expiry rule.
- **Verify upload moderation**: blurry photos are blocked before inference; face-containing photos are prevented from being uploaded as feedback.
- **Server-verified solo Arena**: Classic / Speed Sort / Streak / Daily no longer trust client-side scoring or exposed answer keys.

### Validation

Run `scripts/check_backend_contracts.sh` to verify Swift RPC calls match migration function definitions.

## 7. Recommended Next Refactors

1. Split service DTOs from domain models (avoid large model files)
2. Introduce per-feature `Repository` protocol to improve testability
3. Add `Smart SortTests` for ViewModel + Service contract tests
4. Add CI step to run `scripts/check_backend_contracts.sh`
5. **Remove duplicate `ThemeBackground()`** from tab-level views (`VerifyView`, `ArenaHubView`, `LeaderboardView`, `CommunityView`). `ContentView` already renders `ThemeBackgroundView()` at the root. Requires visual QA for `NavigationStack` background propagation.
6. **Consolidate `ThemeBackground` and `ThemeBackgroundView`** — they are exact duplicates (one in `ThemeComponents.swift`, one in `ThemeBackgroundView.swift`). Keep one, delete the other.
7. **Migrate `Color.neuXxx` to `theme.palette.*`** — legacy `Color` static extensions in `NeumorphicStyles.swift` bypass `@Environment(\.trashTheme)`. ~100 call sites need migration.
8. **Split `UserSettings`** — currently handles location persistence, CLLocationManager, community membership cache, and community CRUD (321 lines, 4 responsibilities).
9. **Split `CommunityService`** into `CommunityService`, `EventService`, `AdminService` — currently 23 public methods / 367 lines.
