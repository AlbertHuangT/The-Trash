-- ============================================================
-- Migration 009: Daily Challenge
-- Date: 2026-02-09
-- Description:
--   - daily_challenges table (one row per day, fixed 10 questions)
--   - daily_challenge_results table (one result per user per day)
--   - RPC: get_daily_challenge() — get/create today's challenge
--   - RPC: submit_daily_challenge() — submit result
--   - RPC: get_daily_leaderboard() — daily rankings
-- ============================================================

-- ============================================================
-- PART 1: daily_challenges table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_date DATE NOT NULL UNIQUE,
    question_ids UUID[] NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

ALTER TABLE public.daily_challenges OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_daily_challenges_date ON public.daily_challenges(challenge_date DESC);

ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Daily challenges are readable by authenticated users"
    ON public.daily_challenges
    FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================
-- PART 2: daily_challenge_results table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_challenge_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    challenge_date DATE NOT NULL,
    score INT NOT NULL DEFAULT 0,
    correct_count INT NOT NULL DEFAULT 0,
    time_seconds DECIMAL NOT NULL DEFAULT 0,
    max_combo INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE (user_id, challenge_date)
);

ALTER TABLE public.daily_challenge_results OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_daily_results_date ON public.daily_challenge_results(challenge_date, score DESC);
CREATE INDEX IF NOT EXISTS idx_daily_results_user ON public.daily_challenge_results(user_id);

ALTER TABLE public.daily_challenge_results ENABLE ROW LEVEL SECURITY;

-- Users can read all results (for leaderboard)
CREATE POLICY "Daily results are readable by authenticated users"
    ON public.daily_challenge_results
    FOR SELECT
    TO authenticated
    USING (true);

-- Users can insert their own results
CREATE POLICY "Users can insert their own daily results"
    ON public.daily_challenge_results
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- PART 3: RPC Functions
-- ============================================================

-- get_daily_challenge: get or create today's challenge
CREATE OR REPLACE FUNCTION public.get_daily_challenge()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_today DATE;
    v_challenge_id UUID;
    v_question_ids UUID[];
    v_already_played BOOLEAN;
    v_questions JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_today := (timezone('utc', now()))::date;

    -- Try to get existing challenge for today
    SELECT id, question_ids INTO v_challenge_id, v_question_ids
    FROM public.daily_challenges
    WHERE challenge_date = v_today;

    -- Create if not exists
    IF v_challenge_id IS NULL THEN
        -- Pick 10 random questions
        SELECT ARRAY(
            SELECT q.id
            FROM public.quiz_questions q
            WHERE q.is_active = true
            ORDER BY random()
            LIMIT 10
        ) INTO v_question_ids;

        INSERT INTO public.daily_challenges (challenge_date, question_ids)
        VALUES (v_today, v_question_ids)
        ON CONFLICT (challenge_date) DO UPDATE SET challenge_date = EXCLUDED.challenge_date
        RETURNING id INTO v_challenge_id;

        -- Re-read in case of race condition
        SELECT question_ids INTO v_question_ids
        FROM public.daily_challenges
        WHERE id = v_challenge_id;
    END IF;

    -- Check if user already played today
    SELECT EXISTS(
        SELECT 1 FROM public.daily_challenge_results
        WHERE user_id = v_user_id AND challenge_date = v_today
    ) INTO v_already_played;

    -- Get questions in order (using unnest with ordinality to preserve array order)
    SELECT json_agg(q ORDER BY ord.ordinality)
    INTO v_questions
    FROM unnest(v_question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'challenge_date', v_today,
        'already_played', v_already_played,
        'questions', COALESCE(v_questions, '[]'::json)
    );
END;
$$;

ALTER FUNCTION public.get_daily_challenge() OWNER TO postgres;

-- submit_daily_challenge: submit result (only once per day)
CREATE OR REPLACE FUNCTION public.submit_daily_challenge(
    p_score INT,
    p_correct_count INT,
    p_time_seconds DECIMAL,
    p_max_combo INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_today DATE;
    v_result_id UUID;
    v_points INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_today := (timezone('utc', now()))::date;

    -- Check challenge exists for today
    IF NOT EXISTS (SELECT 1 FROM public.daily_challenges WHERE challenge_date = v_today) THEN
        RAISE EXCEPTION 'No daily challenge for today';
    END IF;

    -- Check not already played
    IF EXISTS (SELECT 1 FROM public.daily_challenge_results WHERE user_id = v_user_id AND challenge_date = v_today) THEN
        RAISE EXCEPTION 'Already completed today''s challenge';
    END IF;

    -- Insert result
    INSERT INTO public.daily_challenge_results (user_id, challenge_date, score, correct_count, time_seconds, max_combo)
    VALUES (v_user_id, v_today, p_score, p_correct_count, p_time_seconds, p_max_combo)
    RETURNING id INTO v_result_id;

    -- Award points (same as score)
    v_points := p_score;
    IF v_points > 0 THEN
        UPDATE public.profiles
        SET credits = credits + v_points
        WHERE id = v_user_id;
    END IF;

    RETURN json_build_object(
        'result_id', v_result_id,
        'points_awarded', v_points
    );
END;
$$;

ALTER FUNCTION public.submit_daily_challenge(INT, INT, DECIMAL, INT) OWNER TO postgres;

-- get_daily_leaderboard: rankings for a given date
CREATE OR REPLACE FUNCTION public.get_daily_leaderboard(
    p_date DATE DEFAULT NULL,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    rank BIGINT,
    user_id UUID,
    display_name TEXT,
    score INT,
    correct_count INT,
    time_seconds DECIMAL,
    max_combo INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_date DATE;
BEGIN
    v_date := COALESCE(p_date, (timezone('utc', now()))::date);

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY dr.score DESC, dr.time_seconds ASC) AS rank,
        dr.user_id,
        COALESCE(p.display_name, 'Anonymous') AS display_name,
        dr.score,
        dr.correct_count,
        dr.time_seconds,
        dr.max_combo
    FROM public.daily_challenge_results dr
    JOIN public.profiles p ON p.id = dr.user_id
    WHERE dr.challenge_date = v_date
    ORDER BY dr.score DESC, dr.time_seconds ASC
    LIMIT p_limit;
END;
$$;

ALTER FUNCTION public.get_daily_leaderboard(DATE, INT) OWNER TO postgres;
