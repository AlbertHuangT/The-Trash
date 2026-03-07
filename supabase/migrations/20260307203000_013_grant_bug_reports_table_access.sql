-- ============================================================
-- Migration 013: Grant bug_reports table access to authenticated users
-- Date: 2026-03-07
--
-- Problem:
-- The bug_reports table had RLS policies but no explicit table grants for
-- authenticated users, which caused "permission denied for table bug_reports"
-- on insert.
-- ============================================================

GRANT SELECT, INSERT ON TABLE public.bug_reports TO authenticated;
