-- Ensure duel completion is atomic and only finalizes after both players answered all questions.
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
    v_total_questions INT;
    v_challenger_answers INT;
    v_opponent_answers INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Lock row to prevent concurrent completion from double-awarding credits.
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

    IF v_challenge.status = 'completed' THEN
        RETURN json_build_object(
            'challenge_id', p_challenge_id,
            'challenger_score', v_challenge.challenger_score,
            'opponent_score', v_challenge.opponent_score,
            'winner_id', v_challenge.winner_id,
            'already_completed', true
        );
    END IF;

    IF v_challenge.status NOT IN ('accepted', 'in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    v_total_questions := COALESCE(array_length(v_challenge.question_ids, 1), 0);
    IF v_total_questions <= 0 THEN
        RAISE EXCEPTION 'Challenge has no questions';
    END IF;

    SELECT COUNT(*) INTO v_challenger_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) INTO v_opponent_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    IF v_challenger_answers < v_total_questions OR v_opponent_answers < v_total_questions THEN
        RAISE EXCEPTION 'Challenge not complete yet';
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
    SET
        status = 'completed',
        challenger_score = v_challenger_score,
        opponent_score = v_opponent_score,
        winner_id = v_winner_id,
        completed_at = timezone('utc', now())
    WHERE id = p_challenge_id;

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
