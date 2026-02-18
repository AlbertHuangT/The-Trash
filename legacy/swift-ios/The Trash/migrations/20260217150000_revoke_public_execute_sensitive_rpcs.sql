BEGIN;

-- Remove PUBLIC execute from sensitive mutating RPCs.
-- This closes the gap where revoking anon alone is insufficient because
-- PostgreSQL functions are executable by PUBLIC by default.
REVOKE EXECUTE ON FUNCTION public.apply_to_join_community(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_event_registration(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_and_grant_achievement(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.complete_arena_challenge(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_community(text, text, text, text, text, numeric, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_event(text, text, text, timestamptz, text, numeric, numeric, integer, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.find_friends_leaderboard(text[], text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.grant_event_credits(uuid, uuid[], integer, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_credits(integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_total_scans() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.join_community(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.leave_community(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.register_for_event(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.remove_community_member(text, uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.review_join_application(uuid, boolean, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_daily_challenge(integer, integer, numeric, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_duel_answer(uuid, integer, text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_streak_record(integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_community_info(text, text, text, text, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_user_location(text, text, numeric, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_user_location(text, text, double precision, double precision) FROM PUBLIC;

COMMIT;
