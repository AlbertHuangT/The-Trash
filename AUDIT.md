# Smart Sort Audit

Date: 2026-03-08

## Scope

This audit covered the SwiftUI iOS client, Supabase migrations, RPC boundaries, RLS policies, Arena gameplay integrity, Verify feedback flow, and repo/backend drift.

## Method

- Read client feature flows and service layers
- Reviewed `supabase/migrations` as the declared backend source
- Traced RPC callers and direct table access
- Built the iOS app for simulator and device targets
- Ran backend contract checks against the workspace migrations

## Findings And Status

### P0 fixed

- Community membership RLS no longer allows arbitrary self-written membership records.
- Community update/delete privileges now require creator or community admin rights.
- Community achievements are no longer granted through broad direct table insert policies; they now flow through explicit admin RPCs.
- Private community data leaks through community/event/leaderboard SECURITY DEFINER RPCs were tightened with shared visibility checks.
- Friend leaderboard no longer returns matched users' raw email addresses or phone numbers.
- Arena single-player modes no longer expose `correct_category` in question payloads.
- Classic / Speed Sort / Streak / Daily now use server-verified session/answer RPCs and server-side completion logic.
- `accept_arena_challenge` now restricts acceptance to the invited opponent.
- Event credit grants now require registered participants and are idempotent per `(event_id, user_id, reason)`.
- Duel stale-active expiry is enforced in gameplay RPCs instead of only inbox fetches.

### P1 fixed

- Classic and Speed Sort no longer couple answer correctness to `increment_credits` success.
- Verify rewards now use a server-owned, idempotent reward RPC instead of client-issued credit mutation.
- Verify and Arena rewards now require a linked account, so guest play no longer pollutes profile credits or leaderboards.
- Feedback images are private and fetched through signed URLs instead of a public bucket.
- Feedback and quiz-candidate ingestion now require a linked identity.
- Streak no longer double-grants credits across frontend and backend.
- Daily Challenge no longer trusts client-submitted score/correct/combo totals.
- Speed Sort no longer starts its timer before the current question image is available.
- Daily Challenge now surfaces submission failure instead of silently marking the run complete.
- Verify no longer treats classifier failure as a normal completed recognition.
- Verify resets state on view disappearance, avoiding stale state carry-over.
- Verify now performs local blur/face moderation before upload decisions.
- Correctly confirmed Verify photos can enter a candidate queue instead of being discarded.
- Community/location cached state is now scoped by authenticated user instead of device-global keys.
- Pending join state is preserved in community UI instead of collapsing into "not joined".
- Community membership state no longer treats long-lived `UserDefaults` caches as the authority source.
- Login and phone-binding flows no longer share the same OTP UI state.
- Community and event detail sheets now act on current state instead of stale snapshots.
- Account settings rows are wired again instead of rendering dead actions.
- Events list loading now uses latest-request-wins semantics instead of fake cancellation.
- Feedback history no longer hardcodes the Supabase project URL.
- Feedback and bug report uploads now clean up orphaned storage objects on DB write failure.
- `scripts/check_backend_contracts.sh` now flags direct table access and overloaded SQL functions in addition to basic RPC-name drift.
- Duel ready/finished state is persisted server-side, and completion now returns structured status instead of forcing the client to parse SQL error text.

### P2 fixed or reduced

- `.gitignore` no longer ignores the entire `supabase/` tree, reducing migration drift risk.
- Arena quiz images are self-hosted in Supabase Storage instead of relying on unstable third-party links.
- Streak now tolerates the small active question pool by allowing backend-assisted rotation once unique questions are exhausted.

## Remaining Residual Risks

- `20260303100000_001_core_schema.sql` still assumes some legacy bootstrap objects already exist in the linked Supabase project, so the repo is not yet a guaranteed from-scratch backend bootstrap.
- `scripts/check_backend_contracts.sh` still cannot prove full RPC signature compatibility or RLS correctness; it is a drift detector, not a formal verifier.
- Arena question pool depth is still limited by the currently hosted seed set; gameplay is stable, but content variety remains constrained until more reviewed images are added.
- `quiz_question_candidates` exists as an intake queue, but a full admin review/publish UI is still not implemented in the app.
- Friend leaderboard still depends on contacts permission, which keeps a high-friction privacy gate in a core engagement loop.

## Validation

- `xcodebuild -project "Smart Sort.xcodeproj" -scheme "Smart Sort" -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `xcodebuild -project "Smart Sort.xcodeproj" -scheme "Smart Sort" -destination 'generic/platform=iOS' build`
- `bash scripts/check_backend_contracts.sh`

## Next Recommended Work

1. Replace the remaining legacy bootstrap assumptions in `001_core_schema.sql` so the repo can rebuild a clean database from zero.
2. Add an admin review/publish surface for `quiz_question_candidates`.
3. Expand the self-hosted Arena image pool to reduce repetition in Streak and Daily.
