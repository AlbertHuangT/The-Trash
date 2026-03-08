-- ============================================================
-- Migration 019: Linked-account Arena rewards
-- Date: 2026-03-08
--
-- Fixes:
-- 1. Align Arena reward eligibility with Verify reward eligibility.
-- 2. Keep game scores intact while withholding profile credits for guests.
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_classic_session(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_points_awarded INT := 0;
    v_answer RECORD;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'classic';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Classic session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Session is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    IF public.is_linked_account(v_user_id) THEN
        v_points_awarded := v_score;
        UPDATE public.profiles
        SET credits = credits + v_points_awarded
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'session_id', p_session_id,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo,
        'points_awarded', v_points_awarded
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_points_awarded,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;

ALTER FUNCTION public.complete_classic_session(UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.complete_speed_sort_session(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_points_awarded INT := 0;
    v_answer RECORD;
    v_time_bonus INT;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'speed_sort';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Speed Sort session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Session is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;

            v_time_bonus := FLOOR((GREATEST(0, 5000 - COALESCE(v_answer.answer_time_ms, 0))::NUMERIC / 1000.0) * 4);
            v_score := v_score + GREATEST(v_time_bonus, 0);
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    IF public.is_linked_account(v_user_id) THEN
        v_points_awarded := v_score;
        UPDATE public.profiles
        SET credits = credits + v_points_awarded
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'session_id', p_session_id,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo,
        'points_awarded', v_points_awarded
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_points_awarded,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;

ALTER FUNCTION public.complete_speed_sort_session(UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.submit_streak_record(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_answers INT;
    v_streak_count INT := 0;
    v_points INT := 0;
    v_points_awarded INT := 0;
    v_answer RECORD;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'streak';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Streak session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    SELECT COALESCE(MAX(question_index), -1) + 1
    INTO v_total_answers
    FROM public.arena_solo_session_answers
    WHERE session_id = p_session_id;

    IF v_total_answers <= 0 THEN
        RAISE EXCEPTION 'No streak answers submitted';
    END IF;

    FOR v_idx IN 0..(v_total_answers - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        EXIT WHEN v_answer IS NULL OR NOT v_answer.is_correct;
        v_streak_count := v_streak_count + 1;
    END LOOP;

    INSERT INTO public.streak_records (user_id, streak_count)
    VALUES (v_user_id, v_streak_count);

    v_points := v_streak_count * 5;
    IF v_points > 0 AND public.is_linked_account(v_user_id) THEN
        v_points_awarded := v_points;
        UPDATE public.profiles
        SET credits = credits + v_points_awarded
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'session_id', p_session_id,
        'streak_count', v_streak_count,
        'points_awarded', v_points_awarded
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_points_awarded,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;

ALTER FUNCTION public.submit_streak_record(UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.submit_daily_challenge(
    p_session_id UUID,
    p_time_seconds DECIMAL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_today DATE := (timezone('utc', now()))::date;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_points_awarded INT := 0;
    v_answer RECORD;
    v_result_id UUID;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'daily'
      AND challenge_date = v_today;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Daily session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.daily_challenge_results
        WHERE user_id = v_user_id
          AND challenge_date = v_today
    ) THEN
        RAISE EXCEPTION 'Already completed today''s challenge';
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Daily challenge is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    INSERT INTO public.daily_challenge_results (
        user_id, challenge_date, score, correct_count, time_seconds, max_combo
    )
    VALUES (
        v_user_id, v_today, v_score, v_correct_count, p_time_seconds, v_max_combo
    )
    RETURNING id INTO v_result_id;

    IF v_score > 0 AND public.is_linked_account(v_user_id) THEN
        v_points_awarded := v_score;
        UPDATE public.profiles
        SET credits = credits + v_points_awarded
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'result_id', v_result_id,
        'points_awarded', v_points_awarded,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_points_awarded,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;

ALTER FUNCTION public.submit_daily_challenge(UUID, DECIMAL) OWNER TO postgres;

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
    v_challenger_awarded INT;
    v_opponent_awarded INT;
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

    v_challenger_awarded := CASE
        WHEN public.is_linked_account(v_challenge.challenger_id) THEN v_challenger_points
        ELSE 0
    END;
    v_opponent_awarded := CASE
        WHEN public.is_linked_account(v_challenge.opponent_id) THEN v_opponent_points
        ELSE 0
    END;

    UPDATE public.arena_challenges
    SET status = 'completed',
        challenger_score = v_challenger_score,
        opponent_score = v_opponent_score,
        winner_id = v_winner_id,
        challenger_finished_at = COALESCE(challenger_finished_at, timezone('utc', now())),
        opponent_finished_at = COALESCE(opponent_finished_at, timezone('utc', now())),
        completed_at = timezone('utc', now())
    WHERE id = p_challenge_id;

    IF v_challenger_awarded > 0 THEN
        UPDATE public.profiles SET credits = credits + v_challenger_awarded WHERE id = v_challenge.challenger_id;
    END IF;
    IF v_opponent_awarded > 0 THEN
        UPDATE public.profiles SET credits = credits + v_opponent_awarded WHERE id = v_challenge.opponent_id;
    END IF;

    RETURN json_build_object(
        'status', 'completed',
        'challenge_id', p_challenge_id,
        'challenger_score', v_challenger_score,
        'opponent_score', v_opponent_score,
        'winner_id', v_winner_id,
        'challenger_points', v_challenger_awarded,
        'opponent_points', v_opponent_awarded,
        'already_completed', false
    );
END;
$$;

ALTER FUNCTION public.complete_arena_challenge(UUID) OWNER TO postgres;
