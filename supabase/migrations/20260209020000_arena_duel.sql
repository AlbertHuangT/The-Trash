-- ============================================================
-- Migration 010: Arena Duel (1v1 Realtime)
-- Date: 2026-02-09
-- Description:
--   - arena_challenges table (duel sessions)
--   - arena_challenge_answers table (server-side answer verification)
--   - RPCs for full duel lifecycle
-- ============================================================

-- ============================================================
-- PART 1: arena_challenges table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.arena_challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    opponent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'in_progress', 'completed', 'expired', 'declined', 'cancelled')),
    question_ids UUID[] NOT NULL,
    channel_name TEXT UNIQUE,
    challenger_score INT DEFAULT 0,
    opponent_score INT DEFAULT 0,
    winner_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    expires_at TIMESTAMPTZ DEFAULT timezone('utc', now()) + INTERVAL '10 minutes',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

ALTER TABLE public.arena_challenges OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_challenges_challenger ON public.arena_challenges(challenger_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_opponent ON public.arena_challenges(opponent_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_status ON public.arena_challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_channel ON public.arena_challenges(channel_name);

ALTER TABLE public.arena_challenges ENABLE ROW LEVEL SECURITY;

-- Users can only see challenges they're part of
CREATE POLICY "Users can view their own challenges"
    ON public.arena_challenges
    FOR SELECT
    TO authenticated
    USING (auth.uid() = challenger_id OR auth.uid() = opponent_id);

-- ============================================================
-- PART 2: arena_challenge_answers table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.arena_challenge_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_id UUID NOT NULL REFERENCES public.arena_challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    question_index INT NOT NULL,
    selected_category TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    answer_time_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE (challenge_id, user_id, question_index)
);

ALTER TABLE public.arena_challenge_answers OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_challenge_answers_challenge ON public.arena_challenge_answers(challenge_id, user_id);

ALTER TABLE public.arena_challenge_answers ENABLE ROW LEVEL SECURITY;

-- Users can see answers for challenges they're part of
CREATE POLICY "Users can view answers for their challenges"
    ON public.arena_challenge_answers
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.arena_challenges ac
            WHERE ac.id = challenge_id
            AND (ac.challenger_id = auth.uid() OR ac.opponent_id = auth.uid())
        )
    );

-- ============================================================
-- PART 3: RPC Functions
-- ============================================================

-- create_arena_challenge: create a new duel challenge
CREATE OR REPLACE FUNCTION public.create_arena_challenge(p_opponent_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge_id UUID;
    v_question_ids UUID[];
    v_channel_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_user_id = p_opponent_id THEN
        RAISE EXCEPTION 'Cannot challenge yourself';
    END IF;

    -- Select 10 random questions
    SELECT ARRAY(
        SELECT q.id
        FROM public.quiz_questions q
        WHERE q.is_active = true
        ORDER BY random()
        LIMIT 10
    ) INTO v_question_ids;

    IF array_length(v_question_ids, 1) < 10 THEN
        RAISE EXCEPTION 'Not enough questions available';
    END IF;

    v_challenge_id := gen_random_uuid();
    v_channel_name := 'duel:' || v_challenge_id::text;

    INSERT INTO public.arena_challenges (
        id, challenger_id, opponent_id, status, question_ids, channel_name
    ) VALUES (
        v_challenge_id, v_user_id, p_opponent_id, 'pending', v_question_ids, v_channel_name
    );

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'channel_name', v_channel_name,
        'status', 'pending'
    );
END;
$$;

ALTER FUNCTION public.create_arena_challenge(UUID) OWNER TO postgres;

-- accept_arena_challenge: accept a pending challenge
CREATE OR REPLACE FUNCTION public.accept_arena_challenge(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
    v_questions JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get challenge
    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;

    IF v_challenge.opponent_id != v_user_id AND v_challenge.challenger_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status != 'pending' THEN
        RAISE EXCEPTION 'Challenge is no longer pending (status: %)', v_challenge.status;
    END IF;

    -- Check expiry
    IF v_challenge.expires_at < timezone('utc', now()) THEN
        UPDATE public.arena_challenges SET status = 'expired' WHERE id = p_challenge_id;
        RAISE EXCEPTION 'Challenge has expired';
    END IF;

    -- Accept
    UPDATE public.arena_challenges
    SET status = 'accepted'
    WHERE id = p_challenge_id;

    -- Get questions in order
    SELECT json_agg(q ORDER BY ord.ordinality)
    INTO v_questions
    FROM unnest(v_challenge.question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'channel_name', v_challenge.channel_name,
        'questions', COALESCE(v_questions, '[]'::json),
        'challenger_id', v_challenge.challenger_id,
        'opponent_id', v_challenge.opponent_id
    );
END;
$$;

ALTER FUNCTION public.accept_arena_challenge(UUID) OWNER TO postgres;

-- decline_arena_challenge: decline or cancel a challenge
CREATE OR REPLACE FUNCTION public.decline_arena_challenge(p_challenge_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;

    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status NOT IN ('pending', 'accepted') THEN
        RAISE EXCEPTION 'Cannot decline challenge in status: %', v_challenge.status;
    END IF;

    IF v_challenge.challenger_id = v_user_id THEN
        UPDATE public.arena_challenges SET status = 'cancelled' WHERE id = p_challenge_id;
    ELSE
        UPDATE public.arena_challenges SET status = 'declined' WHERE id = p_challenge_id;
    END IF;
END;
$$;

ALTER FUNCTION public.decline_arena_challenge(UUID) OWNER TO postgres;

-- submit_duel_answer: submit + verify a single answer
CREATE OR REPLACE FUNCTION public.submit_duel_answer(
    p_challenge_id UUID,
    p_question_index INT,
    p_selected_category TEXT,
    p_answer_time_ms INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
    v_question_id UUID;
    v_correct_category TEXT;
    v_is_correct BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get challenge
    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;

    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status NOT IN ('accepted', 'in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    -- Update to in_progress if needed
    IF v_challenge.status = 'accepted' THEN
        UPDATE public.arena_challenges
        SET status = 'in_progress', started_at = timezone('utc', now())
        WHERE id = p_challenge_id AND status = 'accepted';
    END IF;

    -- Get the question at this index
    v_question_id := v_challenge.question_ids[p_question_index + 1]; -- 1-indexed array

    IF v_question_id IS NULL THEN
        RAISE EXCEPTION 'Invalid question index: %', p_question_index;
    END IF;

    -- Get correct answer
    SELECT correct_category INTO v_correct_category
    FROM public.quiz_questions
    WHERE id = v_question_id;

    v_is_correct := (p_selected_category = v_correct_category);

    -- Insert answer (upsert to handle retries)
    INSERT INTO public.arena_challenge_answers (
        challenge_id, user_id, question_index, selected_category, is_correct, answer_time_ms
    ) VALUES (
        p_challenge_id, v_user_id, p_question_index, p_selected_category, v_is_correct, p_answer_time_ms
    )
    ON CONFLICT (challenge_id, user_id, question_index) DO NOTHING;

    RETURN json_build_object(
        'is_correct', v_is_correct,
        'correct_category', v_correct_category,
        'question_index', p_question_index
    );
END;
$$;

ALTER FUNCTION public.submit_duel_answer(UUID, INT, TEXT, INT) OWNER TO postgres;

-- complete_arena_challenge: finalize scores and award points (idempotent)
CREATE OR REPLACE FUNCTION public.complete_arena_challenge(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
    v_challenger_correct INT;
    v_opponent_correct INT;
    v_challenger_score INT;
    v_opponent_score INT;
    v_winner_id UUID;
    v_challenger_points INT;
    v_opponent_points INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;

    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    -- If already completed, return existing result
    IF v_challenge.status = 'completed' THEN
        RETURN json_build_object(
            'challenge_id', p_challenge_id,
            'challenger_score', v_challenge.challenger_score,
            'opponent_score', v_challenge.opponent_score,
            'winner_id', v_challenge.winner_id,
            'already_completed', true
        );
    END IF;

    -- Calculate scores (20 points per correct answer)
    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_challenger_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_opponent_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    v_challenger_score := v_challenger_correct * 20;
    v_opponent_score := v_opponent_correct * 20;

    -- Determine winner
    IF v_challenger_score > v_opponent_score THEN
        v_winner_id := v_challenge.challenger_id;
    ELSIF v_opponent_score > v_challenger_score THEN
        v_winner_id := v_challenge.opponent_id;
    ELSE
        v_winner_id := NULL; -- tie
    END IF;

    -- Award points: winner 50, loser 10, tie each 30
    IF v_winner_id IS NULL THEN
        v_challenger_points := 30;
        v_opponent_points := 30;
    ELSIF v_winner_id = v_challenge.challenger_id THEN
        v_challenger_points := 50;
        v_opponent_points := 10;
    ELSE
        v_challenger_points := 10;
        v_opponent_points := 50;
    END IF;

    -- Update challenge
    UPDATE public.arena_challenges
    SET
        status = 'completed',
        challenger_score = v_challenger_score,
        opponent_score = v_opponent_score,
        winner_id = v_winner_id,
        completed_at = timezone('utc', now())
    WHERE id = p_challenge_id AND status != 'completed';

    -- Award credits
    UPDATE public.profiles SET credits = credits + v_challenger_points WHERE id = v_challenge.challenger_id;
    UPDATE public.profiles SET credits = credits + v_opponent_points WHERE id = v_challenge.opponent_id;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'challenger_score', v_challenger_score,
        'opponent_score', v_opponent_score,
        'winner_id', v_winner_id,
        'challenger_points', v_challenger_points,
        'opponent_points', v_opponent_points,
        'already_completed', false
    );
END;
$$;

ALTER FUNCTION public.complete_arena_challenge(UUID) OWNER TO postgres;

-- get_my_challenges: list challenges for the current user
CREATE OR REPLACE FUNCTION public.get_my_challenges(p_status TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Expire old pending challenges
    UPDATE public.arena_challenges
    SET status = 'expired'
    WHERE status = 'pending'
    AND expires_at < timezone('utc', now());

    SELECT json_agg(row_to_json(t))
    INTO v_result
    FROM (
        SELECT
            ac.id,
            ac.challenger_id,
            ac.opponent_id,
            ac.status,
            ac.challenger_score,
            ac.opponent_score,
            ac.winner_id,
            ac.channel_name,
            ac.created_at,
            ac.expires_at,
            ac.started_at,
            ac.completed_at,
            cp.display_name AS challenger_name,
            op.display_name AS opponent_name
        FROM public.arena_challenges ac
        JOIN public.profiles cp ON cp.id = ac.challenger_id
        JOIN public.profiles op ON op.id = ac.opponent_id
        WHERE (ac.challenger_id = v_user_id OR ac.opponent_id = v_user_id)
        AND (p_status IS NULL OR ac.status = p_status)
        ORDER BY ac.created_at DESC
        LIMIT 50
    ) t;

    RETURN COALESCE(v_result, '[]'::json);
END;
$$;

ALTER FUNCTION public.get_my_challenges(TEXT) OWNER TO postgres;

-- get_challenge_questions: get questions for an accepted challenge (for challenger)
CREATE OR REPLACE FUNCTION public.get_challenge_questions(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
    v_questions JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;

    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status NOT IN ('accepted', 'in_progress') THEN
        RAISE EXCEPTION 'Challenge is not ready for play';
    END IF;

    -- Get questions in order
    SELECT json_agg(q ORDER BY ord.ordinality)
    INTO v_questions
    FROM unnest(v_challenge.question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'channel_name', v_challenge.channel_name,
        'questions', COALESCE(v_questions, '[]'::json),
        'challenger_id', v_challenge.challenger_id,
        'opponent_id', v_challenge.opponent_id
    );
END;
$$;

ALTER FUNCTION public.get_challenge_questions(UUID) OWNER TO postgres;
