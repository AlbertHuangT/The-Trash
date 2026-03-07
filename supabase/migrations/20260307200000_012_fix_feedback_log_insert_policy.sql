-- ============================================================
-- Migration 012: Fix feedback log insert policy
-- Date: 2026-03-07
--
-- Problem:
-- The original feedback_logs policy used a broad FOR ALL policy with
-- public.current_user_id(). In production this has produced RLS insert
-- failures for legitimate authenticated feedback submissions.
--
-- Fix:
-- Replace it with explicit per-action policies that use auth.uid()
-- directly for self-owned rows.
-- ============================================================

ALTER TABLE public.feedback_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for everyone" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback readable" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback self-manage" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback insert own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback update own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback delete own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback select own" ON public.feedback_logs;

CREATE POLICY "Feedback select own"
    ON public.feedback_logs FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "Feedback insert own"
    ON public.feedback_logs FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "Feedback update own"
    ON public.feedback_logs FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid())
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

CREATE POLICY "Feedback delete own"
    ON public.feedback_logs FOR DELETE TO authenticated
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid());
