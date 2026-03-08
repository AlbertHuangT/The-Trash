-- ============================================================
-- Migration 018: Duel state hardening
-- Date: 2026-03-08
--
-- Fixes:
-- 1. Persist duel ready / finished state in the database.
-- 2. Add a structured duel-state RPC for recovery after reconnects.
-- 3. Replace exception-string completion flow with structured statuses.
-- ============================================================

ALTER TABLE public.arena_challenges
    ADD COLUMN IF NOT EXISTS challenger_ready_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS opponent_ready_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS challenger_finished_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS opponent_finished_at TIMESTAMPTZ;

UPDATE public.arena_challenges
SET challenger_ready_at = COALESCE(challenger_ready_at, started_at),
    opponent_ready_at = COALESCE(opponent_ready_at, started_at)
WHERE status IN ('in_progress', 'completed')
  AND started_at IS NOT NULL;

UPDATE public.arena_challenges
SET challenger_finished_at = COALESCE(challenger_finished_at, completed_at),
    opponent_finished_at = COALESCE(opponent_finished_at, completed_at)
WHERE status = 'completed'
  AND completed_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_duel_state(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_challenge RECORD;
    v_challenger_progress INT := 0;
    v_opponent_progress INT := 0;
    v_challenger_correct INT := 0;
    v_opponent_correct INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.id = p_challenge_id
      AND ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    SELECT COALESCE(MAX(question_index), -1) + 1,
           COUNT(*) FILTER (WHERE is_correct)
    INTO v_challenger_progress, v_challenger_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id
      AND user_id = v_challenge.challenger_id;

    SELECT COALESCE(MAX(question_index), -1) + 1,
           COUNT(*) FILTER (WHERE is_correct)
    INTO v_opponent_progress, v_opponent_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id
      AND user_id = v_challenge.opponent_id;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'status', v_challenge.status,
        'challenger_ready', v_challenge.challenger_ready_at IS NOT NULL,
        'opponent_ready', v_challenge.opponent_ready_at IS NOT NULL,
        'both_ready', v_challenge.challenger_ready_at IS NOT NULL AND v_challenge.opponent_ready_at IS NOT NULL,
        'challenger_finished', v_challenge.challenger_finished_at IS NOT NULL,
        'opponent_finished', v_challenge.opponent_finished_at IS NOT NULL,
        'challenger_progress', v_challenger_progress,
        'opponent_progress', v_opponent_progress,
        'challenger_correct', v_challenger_correct,
        'opponent_correct', v_opponent_correct,
        'started_at', v_challenge.started_at,
        'completed_at', v_challenge.completed_at
    );
END;
$$;

ALTER FUNCTION public.get_duel_state(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_duel_state(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_duel_ready(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_challenge RECORD;
    v_started_at TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id
    FOR UPDATE;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted', 'in_progress') THEN
        RAISE EXCEPTION 'Challenge is not ready for play';
    END IF;

    UPDATE public.arena_challenges
    SET challenger_ready_at = CASE
            WHEN challenger_id = v_user_id THEN COALESCE(challenger_ready_at, timezone('utc', now()))
            ELSE challenger_ready_at
        END,
        opponent_ready_at = CASE
            WHEN opponent_id = v_user_id THEN COALESCE(opponent_ready_at, timezone('utc', now()))
            ELSE opponent_ready_at
        END
    WHERE id = p_challenge_id;

    UPDATE public.arena_challenges
    SET started_at = COALESCE(started_at, timezone('utc', now())),
        status = CASE
            WHEN challenger_ready_at IS NOT NULL AND opponent_ready_at IS NOT NULL THEN 'in_progress'
            ELSE status
        END
    WHERE id = p_challenge_id
    RETURNING started_at INTO v_started_at;

    RETURN public.get_duel_state(p_challenge_id);
END;
$$;

ALTER FUNCTION public.mark_duel_ready(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.mark_duel_ready(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_duel_answer(
    p_challenge_id UUID,
    p_question_index INT,
    p_selected_category TEXT,
    p_answer_time_ms INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_challenge RECORD;
    v_question_id UUID;
    v_correct_category TEXT;
    v_is_correct BOOLEAN;
    v_total_questions INT;
    v_answer_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id
    FOR UPDATE;

    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    v_total_questions := COALESCE(array_length(v_challenge.question_ids, 1), 0);
    v_question_id := v_challenge.question_ids[p_question_index + 1];
    IF v_question_id IS NULL THEN RAISE EXCEPTION 'Invalid question index: %', p_question_index; END IF;

    SELECT correct_category INTO v_correct_category
    FROM public.quiz_questions
    WHERE id = v_question_id;
    IF v_correct_category IS NULL THEN RAISE EXCEPTION 'Question not found'; END IF;

    v_is_correct := (p_selected_category = v_correct_category);

    INSERT INTO public.arena_challenge_answers (
        challenge_id, user_id, question_index, selected_category, is_correct, answer_time_ms
    )
    VALUES (
        p_challenge_id, v_user_id, p_question_index, p_selected_category, v_is_correct, GREATEST(COALESCE(p_answer_time_ms, 0), 0)
    )
    ON CONFLICT (challenge_id, user_id, question_index) DO NOTHING;

    SELECT COUNT(*)
    INTO v_answer_count
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id
      AND user_id = v_user_id;

    IF v_answer_count >= v_total_questions THEN
        UPDATE public.arena_challenges
        SET challenger_finished_at = CASE
                WHEN challenger_id = v_user_id THEN COALESCE(challenger_finished_at, timezone('utc', now()))
                ELSE challenger_finished_at
            END,
            opponent_finished_at = CASE
                WHEN opponent_id = v_user_id THEN COALESCE(opponent_finished_at, timezone('utc', now()))
                ELSE opponent_finished_at
            END
        WHERE id = p_challenge_id;
    END IF;

    RETURN json_build_object(
        'is_correct', v_is_correct,
        'correct_category', v_correct_category,
        'question_index', p_question_index
    );
END;
$$;

ALTER FUNCTION public.submit_duel_answer(UUID, INT, TEXT, INT) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.complete_arena_challenge(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
    v_total_questions INT;
    v_challenger_answers INT;
    v_opponent_answers INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.id = p_challenge_id
      AND ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id
    FOR UPDATE;

    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status = 'completed' THEN
        RETURN json_build_object(
            'status', 'completed',
            'challenge_id', p_challenge_id,
            'challenger_score', v_challenge.challenger_score,
            'opponent_score', v_challenge.opponent_score,
            'winner_id', v_challenge.winner_id,
            'already_completed', true
        );
    END IF;

    IF v_challenge.status = 'expired' THEN
        RETURN json_build_object(
            'status', 'expired',
            'challenge_id', p_challenge_id,
            'message', 'Challenge has expired',
            'already_completed', false
        );
    END IF;

    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RETURN json_build_object(
            'status', 'inactive',
            'challenge_id', p_challenge_id,
            'message', format('Challenge is not active (status: %s)', v_challenge.status),
            'already_completed', false
        );
    END IF;

    v_total_questions := COALESCE(array_length(v_challenge.question_ids, 1), 0);
    IF v_total_questions <= 0 THEN
        RETURN json_build_object(
            'status', 'inactive',
            'challenge_id', p_challenge_id,
            'message', 'Challenge has no questions',
            'already_completed', false
        );
    END IF;

    SELECT COUNT(*) INTO v_challenger_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) INTO v_opponent_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    IF v_challenger_answers < v_total_questions OR v_opponent_answers < v_total_questions THEN
        RETURN json_build_object(
            'status', 'waiting_for_opponent',
            'challenge_id', p_challenge_id,
            'challenger_answers', v_challenger_answers,
            'opponent_answers', v_opponent_answers,
            'required_answers', v_total_questions,
            'already_completed', false
        );
    END IF;

    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_challenger_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_opponent_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    v_challenger_score := v_challenger_correct * 20;
    v_opponent_score := v_opponent_correct * 20;

    IF v_challenger_score > v_opponent_score THEN
        v_winner_id := v_challenge.challenger_id;
    ELSIF v_opponent_score > v_challenger_score THEN
        v_winner_id := v_challenge.opponent_id;
    ELSE
        v_winner_id := NULL;
    END IF;

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

    UPDATE public.arena_challenges
    SET status = 'completed',
        challenger_score = v_challenger_score,
        opponent_score = v_opponent_score,
        winner_id = v_winner_id,
        challenger_finished_at = COALESCE(challenger_finished_at, timezone('utc', now())),
        opponent_finished_at = COALESCE(opponent_finished_at, timezone('utc', now())),
        completed_at = timezone('utc', now())
    WHERE id = p_challenge_id;

    UPDATE public.profiles SET credits = credits + v_challenger_points WHERE id = v_challenge.challenger_id;
    UPDATE public.profiles SET credits = credits + v_opponent_points WHERE id = v_challenge.opponent_id;

    RETURN json_build_object(
        'status', 'completed',
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
GRANT EXECUTE ON FUNCTION public.get_duel_state(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_duel_ready(UUID) TO authenticated;
