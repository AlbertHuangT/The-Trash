# Architecture

## Summary

Smart Sort is an iOS-native SwiftUI app organized around a small app shell, feature-local views/view models, and a Supabase-backed service layer.

The architecture is intentionally lightweight:

- `Smart_SortApp` composes global state and theme
- `ContentView` owns tab and sheet presentation
- `AppRouter` centralizes cross-feature navigation state
- feature views depend on focused services instead of talking to backend setup directly
- `supabase/migrations/` is the only SQL source of truth

## App Shell

### Entry

`Smart_SortApp` bootstraps:

- `AuthViewModel`
- `TrashViewModel`
- `AppRouter`
- `TrashTheme`

It decides between:

- onboarding
- authenticated app shell
- login flow

It also handles:

- global deep-link routing
- top-level auth verification overlay
- theme injection through `@Environment(\.trashTheme)`

### Navigation

`ContentView` renders the main tab shell:

- Verify
- Arena
- Leaderboard
- Community

Navigation behavior is split:

- feature-local push navigation uses `NavigationStack`
- cross-feature sheet presentation uses `AppRouter.activeSheet`
- cross-tab deep-link state uses `AppRouter.pendingChallengeId`

`AppRouter` is the shared coordination layer for:

- selected tab
- modal sheet routing
- challenge deep links

This keeps feature views from owning global navigation decisions.

## State Model

### Global State

- `AuthViewModel`: auth session, deep-link auth state
- `TrashViewModel`: Verify flow state, classifier preparation, reward/feedback actions
- `AppRouter`: tab and sheet routing
- `UserSettings.shared`: user-scoped settings and selected location

### Feature State

Most feature state stays close to the feature:

- Arena mode view models live in `Views/Arena/`
- Community view models live in `Views/Community/`
- Account/Profile state is feature-local where possible

The current codebase still mixes:

- `@StateObject` feature-local models
- singleton/shared services
- a few globally shared stores

That is the current reality and should be documented explicitly rather than idealized away.

## Service Layer

### Backend Access

`SupabaseManager` owns one shared `SupabaseClient` configured from `Secrets.swift`.

Feature services use that shared client for:

- Auth
- PostgREST table access
- RPC calls
- Storage
- Realtime

Representative service boundaries:

- `GamificationService`: reward RPCs
- `FeedbackService`: feedback and quiz-candidate uploads
- `ArenaService`: arena RPCs and challenge/session data
- `CommunityService`: communities/events
- `ProfileService`, `AchievementService`, `BugReportService`

### Backend Contract Rules

- App-owned SQL logic lives only in `supabase/migrations/`
- RPC names used by Swift should be represented in migrations
- direct table access still exists in a few areas and is treated as a risk to reduce over time
- linked-account gating is enforced in reward-sensitive flows such as Verify and Arena

## UI System Boundary

The app uses a shared design system centered on `TrashTheme`.

Rules for the current architecture:

- feature views should read theme from `@Environment(\.trashTheme)`
- shared primitives in `Theme/` should be extended before adding feature-local visual systems
- page background, typography roles, spacing, and component sizing should come from the theme layer

See [UI Guidelines](UI_GUIDELINES.md) for the design rules.

## Backend Drift Protection

The repository includes `scripts/check_backend_contracts.sh`.

It now checks two classes of issues:

- local contract alignment
  - Swift RPC names vs migration-defined functions
  - high-risk direct table access
- remote legacy drift
  - banned old profile trigger/function objects
  - banned legacy profile policies

The remote drift portion depends on linked Supabase access and is meant to catch cases where migration history appears aligned but real deployed objects are not.

## Known Risks

- Some backend access still uses direct table operations instead of RPCs.
- Some features still rely on shared singletons instead of narrower injected interfaces.
- The codebase has gone through schema hardening and reward-flow migrations, so legacy deployed objects remain a real operational risk.
- UI system adoption is much stronger in core flows than in every secondary/admin screen.

## Source Of Truth

- App shell and routing: `Smart Sort/App/`
- Feature UI and view models: `Smart Sort/Views/`
- Backend access: `Smart Sort/Services/`
- Design system: `Smart Sort/Theme/`
- Backend schema and RPCs: `supabase/migrations/`
