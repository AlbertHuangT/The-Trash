-- ============================================================
-- Migration 008: Arena Solo Modes (Streak + Speed Sort support)
-- Date: 2026-02-09
-- Description:
--   - Create streak_records table for tracking streak game results
--   - RPC: get_quiz_questions_batch(p_limit) for variable-count fetches
--   - RPC: submit_streak_record(p_streak_count) to record + award points
--   - RPC: get_streak_leaderboard(p_limit) for top streaks
-- ============================================================

-- ============================================================
-- PART 1: streak_records table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.streak_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    streak_count INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.streak_records OWNER TO postgres;

-- Index for leaderboard queries
CREATE INDEX IF NOT EXISTS idx_streak_records_user_id ON public.streak_records(user_id);
CREATE INDEX IF NOT EXISTS idx_streak_records_streak_count ON public.streak_records(streak_count DESC);

-- Enable RLS
ALTER TABLE public.streak_records ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read all streak records (for leaderboard)
CREATE POLICY "Streak records are readable by authenticated users"
    ON public.streak_records
    FOR SELECT
    TO authenticated
    USING (true);

-- Users can only insert their own streak records
CREATE POLICY "Users can insert their own streak records"
    ON public.streak_records
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- PART 2: RPC Functions
-- ============================================================

-- get_quiz_questions_batch: fetch variable number of random questions
CREATE OR REPLACE FUNCTION public.get_quiz_questions_batch(p_limit INT DEFAULT 10)
RETURNS SETOF public.quiz_questions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.quiz_questions
    WHERE is_active = true
    ORDER BY random()
    LIMIT p_limit;
END;
$$;

ALTER FUNCTION public.get_quiz_questions_batch(INT) OWNER TO postgres;

-- submit_streak_record: record streak + award 5 points per correct answer
CREATE OR REPLACE FUNCTION public.submit_streak_record(p_streak_count INT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_record_id UUID;
    v_points INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Insert streak record
    INSERT INTO public.streak_records (user_id, streak_count)
    VALUES (v_user_id, p_streak_count)
    RETURNING id INTO v_record_id;

    -- Award points: 5 per correct answer
    v_points := p_streak_count * 5;
    IF v_points > 0 THEN
        UPDATE public.profiles
        SET credits = credits + v_points
        WHERE id = v_user_id;
    END IF;

    RETURN v_record_id;
END;
$$;

ALTER FUNCTION public.submit_streak_record(INT) OWNER TO postgres;

-- get_streak_leaderboard: top streaks with user info
CREATE OR REPLACE FUNCTION public.get_streak_leaderboard(p_limit INT DEFAULT 20)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    best_streak INT,
    total_games BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sr.user_id,
        COALESCE(p.display_name, 'Anonymous') AS display_name,
        MAX(sr.streak_count) AS best_streak,
        COUNT(sr.id) AS total_games
    FROM public.streak_records sr
    JOIN public.profiles p ON p.id = sr.user_id
    GROUP BY sr.user_id, p.display_name
    ORDER BY best_streak DESC, total_games DESC
    LIMIT p_limit;
END;
$$;

ALTER FUNCTION public.get_streak_leaderboard(INT) OWNER TO postgres;
