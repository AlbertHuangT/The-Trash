


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."accept_arena_challenge"("p_challenge_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."accept_arena_challenge"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_requires_approval BOOLEAN;
    v_community_name TEXT;
BEGIN
    -- 检查是否登录
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- 检查社区是否存在并获取设置
    SELECT requires_approval, name INTO v_requires_approval, v_community_name
    FROM public.communities
    WHERE id = p_community_id AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Community not found');
    END IF;
    
    -- 检查是否已经是成员
    IF EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE user_id = v_user_id AND community_id = p_community_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Already a member');
    END IF;
    
    -- 如果不需要审批，直接加入
    IF NOT v_requires_approval THEN
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member');
        
        UPDATE public.communities
        SET member_count = member_count + 1, updated_at = NOW()
        WHERE id = p_community_id;
        
        RETURN json_build_object(
            'success', true, 
            'message', 'Joined successfully',
            'requires_approval', false
        );
    END IF;
    
    -- 需要审批：创建申请
    INSERT INTO public.community_join_applications (community_id, user_id, message)
    VALUES (p_community_id, v_user_id, p_message)
    ON CONFLICT (community_id, user_id) 
    DO UPDATE SET 
        status = 'pending',
        message = EXCLUDED.message,
        updated_at = NOW();
    
    RETURN json_build_object(
        'success', true,
        'message', 'Application submitted',
        'requires_approval', true
    );
END;
$$;


ALTER FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text") IS '申请加入社区（如需审批则创建申请）';



CREATE OR REPLACE FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    R CONSTANT DECIMAL := 6371; -- 地球半径（公里）
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2) * sin(dlat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN R * c;
END;
$$;


ALTER FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_user_create_community"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_count INTEGER;
    v_max_allowed INTEGER := 3;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('allowed', false, 'reason', 'Not authenticated', 'current_count', 0, 'max_allowed', v_max_allowed);
    END IF;
    
    SELECT COUNT(*) INTO v_count
    FROM public.communities
    WHERE created_by = v_user_id;
    
    IF v_count >= v_max_allowed THEN
        RETURN json_build_object('allowed', false, 'reason', 'Maximum community limit reached', 'current_count', v_count, 'max_allowed', v_max_allowed);
    END IF;
    
    RETURN json_build_object('allowed', true, 'reason', NULL, 'current_count', v_count, 'max_allowed', v_max_allowed);
END;
$$;


ALTER FUNCTION "public"."can_user_create_community"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_user_create_event"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_count INTEGER;
    v_max_allowed INTEGER := 7;
    v_week_start TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('allowed', false, 'reason', 'Not authenticated', 'current_count', 0, 'max_allowed', v_max_allowed);
    END IF;
    
    -- Calculate start of current week (Monday)
    v_week_start := date_trunc('week', NOW());
    
    SELECT COUNT(*) INTO v_count
    FROM public.community_events
    WHERE created_by = v_user_id
    AND created_at >= v_week_start;
    
    IF v_count >= v_max_allowed THEN
        RETURN json_build_object('allowed', false, 'reason', 'Weekly event limit reached', 'current_count', v_count, 'max_allowed', v_max_allowed);
    END IF;
    
    RETURN json_build_object('allowed', true, 'reason', NULL, 'current_count', v_count, 'max_allowed', v_max_allowed);
END;
$$;


ALTER FUNCTION "public"."can_user_create_event"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $_$
DECLARE
    v_result BOOLEAN := FALSE;
BEGIN
    IF p_community_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF to_regclass('public.user_community_memberships') IS NOT NULL THEN
        EXECUTE $sql$
            SELECT EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = $1
                  AND m.user_id = $2
                  AND m.status IN ('member', 'admin')
            )
        $sql$
        INTO v_result
        USING p_community_id, p_user_id;

        RETURN v_result;
    END IF;

    IF to_regclass('public.user_community_membership') IS NOT NULL THEN
        EXECUTE $sql$
            SELECT EXISTS (
                SELECT 1
                FROM public.user_community_membership m
                WHERE m.community_id = $1
                  AND m.user_id = $2
                  AND m.status IN ('member', 'admin')
            )
        $sql$
        INTO v_result
        USING p_community_id, p_user_id;

        RETURN v_result;
    END IF;

    RETURN FALSE;
END;
$_$;


ALTER FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.event_registrations
    SET status = 'cancelled'
    WHERE event_id = p_event_id
      AND user_id = v_user_id
      AND status = 'registered';

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Registration not found');
    END IF;

    UPDATE public.community_events
    SET participant_count = GREATEST(0, COALESCE(participant_count, 0) - 1),
        updated_at = NOW()
    WHERE id = p_event_id;

    RETURN json_build_object('success', true, 'message', 'Registration cancelled');
END;
$$;


ALTER FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_and_grant_achievement"("p_trigger_key" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_achievement RECORD;
    v_profile RECORD;
    v_already_has BOOLEAN;
    v_qualifies BOOLEAN := false;
    v_auth_email TEXT;
    v_email_confirmed_at TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('granted', false, 'reason', 'Not authenticated');
    END IF;

    SELECT * INTO v_achievement FROM public.achievements
    WHERE trigger_key = p_trigger_key AND community_id IS NULL;

    IF NOT FOUND THEN
        RETURN json_build_object('granted', false, 'reason', 'Achievement not found');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.user_achievements
        WHERE user_id = v_user_id AND achievement_id = v_achievement.id
    ) INTO v_already_has;

    IF v_already_has THEN
        RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    CASE p_trigger_key
        WHEN 'first_scan' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 1;
        WHEN 'scans_10' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 10;
        WHEN 'scans_50' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 50;
        WHEN 'credits_100' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 100;
        WHEN 'credits_500' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 500;
        WHEN 'credits_2000' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 2000;
        WHEN 'join_community' THEN
            v_qualifies := EXISTS (
                SELECT 1 FROM public.user_community_memberships
                WHERE user_id = v_user_id AND status IN ('member', 'admin')
            );
        WHEN 'arena_win' THEN
            v_qualifies := true;
        WHEN 'ucsd_email' THEN
            SELECT email, email_confirmed_at INTO v_auth_email, v_email_confirmed_at
            FROM auth.users
            WHERE id = v_user_id;
            v_qualifies := v_email_confirmed_at IS NOT NULL
                AND v_auth_email ILIKE '%@ucsd.edu';
        ELSE
            v_qualifies := false;
    END CASE;

    IF NOT v_qualifies THEN
        RETURN json_build_object('granted', false, 'reason', 'Not qualified');
    END IF;

    INSERT INTO public.user_achievements (user_id, achievement_id)
    VALUES (v_user_id, v_achievement.id);

    RETURN json_build_object(
        'granted', true,
        'achievement_id', v_achievement.id,
        'name', v_achievement.name,
        'description', v_achievement.description,
        'icon_name', v_achievement.icon_name,
        'rarity', v_achievement.rarity
    );
END;
$$;


ALTER FUNCTION "public"."check_and_grant_achievement"("p_trigger_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_arena_challenge"("p_challenge_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."complete_arena_challenge"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_arena_challenge"("p_opponent_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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

    -- Expire stale pending challenges first
    UPDATE public.arena_challenges
    SET status = 'expired'
    WHERE status = 'pending'
    AND expires_at < timezone('utc', now());

    -- Check for existing pending challenge to this opponent
    IF EXISTS (
        SELECT 1 FROM public.arena_challenges
        WHERE challenger_id = v_user_id
        AND opponent_id = p_opponent_id
        AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'You already have a pending challenge to this player';
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
        id, challenger_id, opponent_id, status, question_ids, channel_name,
        expires_at
    ) VALUES (
        v_challenge_id, v_user_id, p_opponent_id, 'pending', v_question_ids, v_channel_name,
        timezone('utc', now()) + INTERVAL '1 minute'
    );

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'channel_name', v_channel_name,
        'status', 'pending'
    );
END;
$$;


ALTER FUNCTION "public"."create_arena_challenge"("p_opponent_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_community"("p_id" "text", "p_name" "text", "p_city" "text", "p_state" "text", "p_description" "text" DEFAULT NULL::"text", "p_latitude" numeric DEFAULT NULL::numeric, "p_longitude" numeric DEFAULT NULL::numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_can_create json;
    v_community_id TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- Check limit
    v_can_create := public.can_user_create_community();
    IF NOT (v_can_create->>'allowed')::boolean THEN
        RETURN json_build_object('success', false, 'message', v_can_create->>'reason');
    END IF;
    
    -- Check if ID already exists
    IF EXISTS (SELECT 1 FROM public.communities WHERE id = p_id) THEN
        RETURN json_build_object('success', false, 'message', 'Community ID already exists');
    END IF;
    
    -- Create community
    INSERT INTO public.communities (id, name, city, state, description, latitude, longitude, created_by, member_count)
    VALUES (p_id, p_name, p_city, p_state, p_description, p_latitude, p_longitude, v_user_id, 1)
    RETURNING id INTO v_community_id;
    
    -- Auto-join creator as admin
    INSERT INTO public.user_community_memberships (user_id, community_id, status)
    VALUES (v_user_id, v_community_id, 'admin');
    
    RETURN json_build_object('success', true, 'message', 'Community created', 'community_id', v_community_id);
END;
$$;


ALTER FUNCTION "public"."create_community"("p_id" "text", "p_name" "text", "p_city" "text", "p_state" "text", "p_description" "text", "p_latitude" numeric, "p_longitude" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_event"("p_title" "text", "p_description" "text", "p_category" "text", "p_event_date" timestamp with time zone, "p_location" "text", "p_latitude" numeric, "p_longitude" numeric, "p_max_participants" integer DEFAULT 50, "p_community_id" "text" DEFAULT NULL::"text", "p_icon_name" "text" DEFAULT 'calendar'::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_can_create json;
    v_event_id UUID;
    v_organizer TEXT;
    v_is_personal BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- Check limit
    v_can_create := public.can_user_create_event();
    IF NOT (v_can_create->>'allowed')::boolean THEN
        RETURN json_build_object('success', false, 'message', v_can_create->>'reason');
    END IF;
    
    -- Determine if personal or community event
    v_is_personal := (p_community_id IS NULL);
    
    -- Get organizer name
    IF v_is_personal THEN
        SELECT COALESCE(username, email, 'Anonymous') INTO v_organizer
        FROM public.profiles
        WHERE id = v_user_id;
    ELSE
        -- 🔥 CHANGED: Only admins can create community events
        IF NOT EXISTS (
            SELECT 1 FROM public.user_community_memberships
            WHERE user_id = v_user_id AND community_id = p_community_id AND status = 'admin'
        ) THEN
            RETURN json_build_object('success', false, 'message', 'Only community admins can create community events');
        END IF;
        
        SELECT name INTO v_organizer
        FROM public.communities
        WHERE id = p_community_id;
    END IF;
    
    -- Create event
    INSERT INTO public.community_events (
        community_id, title, description, organizer, category, event_date,
        location, latitude, longitude, max_participants, icon_name,
        created_by, is_personal
    )
    VALUES (
        p_community_id, p_title, p_description, v_organizer, p_category, p_event_date,
        p_location, p_latitude, p_longitude, p_max_participants, p_icon_name,
        v_user_id, v_is_personal
    )
    RETURNING id INTO v_event_id;
    
    RETURN json_build_object('success', true, 'message', 'Event created', 'event_id', v_event_id);
END;
$$;


ALTER FUNCTION "public"."create_event"("p_title" "text", "p_description" "text", "p_category" "text", "p_event_date" timestamp with time zone, "p_location" "text", "p_latitude" numeric, "p_longitude" numeric, "p_max_participants" integer, "p_community_id" "text", "p_icon_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT auth.uid();
$$;


ALTER FUNCTION "public"."current_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decline_arena_challenge"("p_challenge_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."decline_arena_challenge"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[] DEFAULT ARRAY[]::"text"[], "p_phones" "text"[] DEFAULT ARRAY[]::"text"[]) RETURNS TABLE("id" "uuid", "username" "text", "credits" integer, "email" "text", "phone" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
BEGIN
    RETURN QUERY
    WITH normalized_emails AS (
        SELECT DISTINCT LOWER(TRIM(e)) AS email
        FROM unnest(COALESCE(p_emails, ARRAY[]::TEXT[])) AS e
        WHERE TRIM(e) <> ''
    ),
    normalized_phones AS (
        SELECT DISTINCT public.normalize_phone_number(raw_phone) AS phone
        FROM unnest(COALESCE(p_phones, ARRAY[]::TEXT[])) AS raw_phone
        CROSS JOIN LATERAL public.normalize_phone_number(raw_phone)
        WHERE public.normalize_phone_number(raw_phone) IS NOT NULL
    ),
    profiles_with_auth AS (
        SELECT
            p.id,
            COALESCE(p.username, 'Anonymous')::TEXT AS username,
            COALESCE(p.credits, 0) AS credits,
            u.email::TEXT AS email,
            u.phone::TEXT AS phone,
            public.normalize_phone_number(u.phone) AS normalized_phone
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT
        pa.id,
        pa.username,
        pa.credits,
        pa.email,
        pa.phone
    FROM profiles_with_auth pa
    WHERE (
        EXISTS (
            SELECT 1
            FROM normalized_emails ne
            WHERE ne.email = LOWER(pa.email)
        )
        OR (
            pa.normalized_phone IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM normalized_phones np
                WHERE np.phone = pa.normalized_phone
            )
        )
    );
END;
$$;


ALTER FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer DEFAULT 50) RETURNS TABLE("id" "uuid", "admin_username" "text", "action_type" "text", "target_username" "text", "details" "jsonb", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    -- 检查权限
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied: Only admins can view action logs';
    END IF;
    
    RETURN QUERY
    SELECT 
        l.id,
        COALESCE(admin_p.username, 'Unknown')::TEXT AS admin_username,
        l.action_type,
        COALESCE(target_p.username, NULL)::TEXT AS target_username,
        l.details,
        l.created_at
    FROM public.admin_action_logs l
    LEFT JOIN public.profiles admin_p ON l.admin_id = admin_p.id
    LEFT JOIN public.profiles target_p ON l.target_user_id = target_p.id
    WHERE l.community_id = p_community_id
    ORDER BY l.created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer) IS '获取管理员操作日志（仅管理员）';



CREATE OR REPLACE FUNCTION "public"."get_challenge_questions"("p_challenge_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."get_challenge_questions"("p_challenge_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_communities_by_city"("p_city" "text") RETURNS TABLE("id" "text", "name" "text", "city" "text", "state" "text", "description" "text", "member_count" integer, "latitude" double precision, "longitude" double precision, "is_member" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();

    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.city,
        c.state,
        c.description,
        COALESCE(c.member_count, 0),
        c.latitude::DOUBLE PRECISION,
        c.longitude::DOUBLE PRECISION,
        EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = c.id
              AND m.user_id = v_user_id
              AND m.status IN ('member', 'admin')
        )
    FROM public.communities c
    WHERE c.city = p_city
      AND c.is_active = true
    ORDER BY c.member_count DESC, c.name ASC;
END;
$$;


ALTER FUNCTION "public"."get_communities_by_city"("p_city" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_community_events"("p_community_id" "text") RETURNS TABLE("id" "uuid", "title" "text", "description" "text", "organizer" "text", "category" "text", "event_date" timestamp with time zone, "location" "text", "latitude" numeric, "longitude" numeric, "icon_name" "text", "max_participants" integer, "participant_count" integer, "community_id" "text", "community_name" "text", "distance_km" numeric, "is_registered" boolean, "is_personal" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.title,
        e.description,
        e.organizer,
        e.category,
        e.event_date,
        e.location,
        e.latitude,
        e.longitude,
        e.icon_name,
        e.max_participants,
        e.participant_count,
        e.community_id,
        c.name as community_name,
        0::DECIMAL as distance_km,
        EXISTS (
            SELECT 1 FROM public.event_registrations r
            WHERE r.event_id = e.id AND r.user_id = auth.uid() AND r.status = 'registered'
        ) as is_registered,
        COALESCE(e.is_personal, false) as is_personal
    FROM public.community_events e
    LEFT JOIN public.communities c ON e.community_id = c.id
    WHERE e.community_id = p_community_id
    ORDER BY e.event_date DESC;
END;
$$;


ALTER FUNCTION "public"."get_community_events"("p_community_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer DEFAULT 100) RETURNS TABLE("id" "uuid", "username" "text", "credits" integer, "community_name" "text", "achievement_icon" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS credits,
        c.name AS community_name,
        a.icon_name AS achievement_icon
    FROM public.user_community_memberships cm
    JOIN public.profiles p ON p.id = cm.user_id
    JOIN public.communities c ON c.id = cm.community_id
    LEFT JOIN public.achievements a ON a.id = p.selected_achievement_id
    WHERE cm.community_id = p_community_id
      AND cm.status IN ('member', 'admin')
    ORDER BY COALESCE(p.credits, 0) DESC, p.username ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;


ALTER FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_community_members_admin"("p_community_id" "text") RETURNS TABLE("user_id" "uuid", "username" "text", "credits" integer, "status" "text", "joined_at" timestamp with time zone, "is_admin" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    -- 检查权限
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied: Only admins can view member details';
    END IF;
    
    RETURN QUERY
    SELECT 
        m.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS credits,
        m.status,
        m.joined_at,
        (m.status = 'admin') AS is_admin
    FROM public.user_community_memberships m
    LEFT JOIN public.profiles p ON m.user_id = p.id
    WHERE m.community_id = p_community_id
    AND m.status IN ('member', 'admin')
    ORDER BY 
        CASE WHEN m.status = 'admin' THEN 0 ELSE 1 END,
        m.joined_at;
END;
$$;


ALTER FUNCTION "public"."get_community_members_admin"("p_community_id" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_community_members_admin"("p_community_id" "text") IS '获取社区成员列表（管理员视图，含详细信息）';



CREATE OR REPLACE FUNCTION "public"."get_community_members_for_grant"("p_community_id" "text", "p_achievement_id" "uuid") RETURNS TABLE("user_id" "uuid", "username" "text", "already_has" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := public.current_user_id();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RAISE EXCEPTION 'Only community admins can view this list';
    END IF;

    RETURN QUERY
    SELECT
        m.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        EXISTS (
            SELECT 1
            FROM public.user_achievements ua
            WHERE ua.user_id = m.user_id
              AND ua.achievement_id = p_achievement_id
        ) AS already_has
    FROM public.user_community_memberships m
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.community_id = p_community_id
      AND m.status IN ('member', 'admin')
    ORDER BY p.username ASC;
END;
$$;


ALTER FUNCTION "public"."get_community_members_for_grant"("p_community_id" "text", "p_achievement_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_daily_challenge"() RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."get_daily_challenge"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_daily_leaderboard"("p_date" "date" DEFAULT NULL::"date", "p_limit" integer DEFAULT 50) RETURNS TABLE("rank" bigint, "user_id" "uuid", "display_name" "text", "score" integer, "correct_count" integer, "time_seconds" numeric, "max_combo" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_date DATE;
BEGIN
    v_date := COALESCE(p_date, (timezone('utc', now()))::date);

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY dr.score DESC, dr.time_seconds ASC) AS rank,
        dr.user_id,
        COALESCE(p.username, 'Anonymous') AS display_name,
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


ALTER FUNCTION "public"."get_daily_leaderboard"("p_date" "date", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_event_participants"("p_event_id" "uuid") RETURNS TABLE("user_id" "uuid", "username" "text", "credits" integer, "registered_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS credits,
        r.registered_at
    FROM public.event_registrations r
    LEFT JOIN public.profiles p ON r.user_id = p.id
    WHERE r.event_id = p_event_id
    ORDER BY r.registered_at;
END;
$$;


ALTER FUNCTION "public"."get_event_participants"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_achievements"() RETURNS TABLE("user_achievement_id" "uuid", "achievement_id" "uuid", "name" "text", "description" "text", "icon_name" "text", "community_id" "text", "community_name" "text", "granted_at" timestamp with time zone, "is_equipped" boolean, "rarity" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        ua.id AS user_achievement_id,
        a.id AS achievement_id,
        a.name,
        a.description,
        a.icon_name,
        a.community_id,
        c.name AS community_name,
        ua.granted_at,
        (p.selected_achievement_id = a.id) AS is_equipped,
        COALESCE(a.rarity, 'common') AS rarity
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    LEFT JOIN public.communities c ON c.id = a.community_id
    LEFT JOIN public.profiles p ON p.id = ua.user_id
    WHERE ua.user_id = v_user_id
    ORDER BY ua.granted_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_my_achievements"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_challenges"("p_status" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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
            cp.username AS challenger_name,
            op.username AS opponent_name
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


ALTER FUNCTION "public"."get_my_challenges"("p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_communities"() RETURNS TABLE("id" "text", "name" "text", "city" "text", "state" "text", "description" "text", "member_count" integer, "joined_at" timestamp with time zone, "status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.city,
        c.state,
        c.description,
        c.member_count,
        m.joined_at,
        m.status
    FROM public.user_community_memberships m
    JOIN public.communities c ON m.community_id = c.id
    WHERE m.user_id = auth.uid() AND m.status IN ('member', 'admin')
    ORDER BY m.joined_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_my_communities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_registrations"() RETURNS TABLE("registration_id" "uuid", "event_id" "uuid", "event_title" "text", "event_date" timestamp with time zone, "event_location" "text", "event_category" "text", "community_name" "text", "registration_status" "text", "registered_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        r.id AS registration_id,
        e.id AS event_id,
        e.title AS event_title,
        e.event_date,
        e.location AS event_location,
        e.category AS event_category,
        COALESCE(c.name, 'Personal') AS community_name,
        r.status AS registration_status,
        r.registered_at
    FROM public.event_registrations r
    JOIN public.community_events e ON e.id = r.event_id
    LEFT JOIN public.communities c ON c.id = e.community_id
    WHERE r.user_id = v_user_id
    ORDER BY e.event_date DESC;
END;
$$;


ALTER FUNCTION "public"."get_my_registrations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 50, "p_category" "text" DEFAULT NULL::"text", "p_only_joined_communities" boolean DEFAULT false, "p_sort_by" "text" DEFAULT 'date'::"text") RETURNS TABLE("id" "uuid", "title" "text", "description" "text", "organizer" "text", "category" "text", "event_date" timestamp with time zone, "location" "text", "latitude" numeric, "longitude" numeric, "icon_name" "text", "max_participants" integer, "participant_count" integer, "community_id" "text", "community_name" "text", "distance_km" numeric, "is_registered" boolean, "is_personal" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_lat_range DECIMAL;
    v_lon_range DECIMAL;
BEGIN
    -- Calculate rough bounding box (1 deg approx 111km)
    -- Adding a small buffer (1.1 factor) to be safe
    v_lat_range := (p_max_distance_km / 111.0) * 1.1;
    -- Longitude degrees shrink as we move away from equator, but using 111km is safe as a lower bound for the 'degree width' in denominator,
    -- meaning we might over-select, which is fine for a pre-filter.
    -- To be more precise: v_lon_range := (p_max_distance_km / (111.0 * cos(radians(p_latitude)))) * 1.1;
    -- For simplicity and speed in SQL without complex math in declaration:
    v_lon_range := (p_max_distance_km / 50.0) * 1.1; -- Very generous box to avoid complex cos() logic issues at poles

    RETURN QUERY
    SELECT
        e.id,
        e.title,
        e.description,
        e.organizer,
        e.category,
        e.event_date,
        e.location,
        e.latitude,
        e.longitude,
        e.icon_name,
        e.max_participants,
        e.participant_count,
        e.community_id,
        c.name AS community_name,
        public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) AS distance_km,
        EXISTS (
            SELECT 1 FROM public.event_registrations r
            WHERE r.event_id = e.id AND r.user_id = v_user_id AND r.status = 'registered'
        ) AS is_registered,
        COALESCE(e.is_personal, false) AS is_personal
    FROM public.community_events e
    LEFT JOIN public.communities c ON e.community_id = c.id
    WHERE e.status = 'upcoming'
    AND e.event_date >= NOW()
    -- Bounding Box Pre-filter
    AND e.latitude BETWEEN (p_latitude - v_lat_range) AND (p_latitude + v_lat_range)
    AND e.longitude BETWEEN (p_longitude - v_lon_range) AND (p_longitude + v_lon_range)
    -- Primary Filter
    AND public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) <= p_max_distance_km
    AND (p_category IS NULL OR e.category = p_category)
    AND (
        NOT p_only_joined_communities
        OR e.is_personal = true
        OR EXISTS (
            SELECT 1 FROM public.user_community_memberships m
            WHERE m.community_id = e.community_id AND m.user_id = v_user_id AND m.status IN ('member', 'admin')
        )
    )
    ORDER BY
        CASE WHEN p_sort_by = 'date' THEN e.event_date END ASC,
        CASE WHEN p_sort_by = 'distance' THEN public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) END ASC,
        CASE WHEN p_sort_by = 'popularity' THEN e.participant_count END DESC;
END;
$$;


ALTER FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_pending_applications"("p_community_id" "text") RETURNS TABLE("id" "uuid", "user_id" "uuid", "username" "text", "user_credits" integer, "message" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    -- 检查权限
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied: Only admins can view applications';
    END IF;
    
    RETURN QUERY
    SELECT 
        a.id,
        a.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS user_credits,
        a.message,
        a.created_at
    FROM public.community_join_applications a
    LEFT JOIN public.profiles p ON a.user_id = p.id
    WHERE a.community_id = p_community_id
    AND a.status = 'pending'
    ORDER BY a.created_at;
END;
$$;


ALTER FUNCTION "public"."get_pending_applications"("p_community_id" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_pending_applications"("p_community_id" "text") IS '获取社区待审批的加入申请（仅管理员）';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."quiz_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "image_url" "text" NOT NULL,
    "correct_category" "text" NOT NULL,
    "item_name" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "is_active" boolean DEFAULT true
);


ALTER TABLE "public"."quiz_questions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_quiz_questions"() RETURNS SETOF "public"."quiz_questions"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
    SELECT * FROM public.get_quiz_questions_batch(10);
$$;


ALTER FUNCTION "public"."get_quiz_questions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_quiz_questions_batch"("p_limit" integer DEFAULT 10) RETURNS SETOF "public"."quiz_questions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."get_quiz_questions_batch"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_streak_leaderboard"("p_limit" integer DEFAULT 20) RETURNS TABLE("user_id" "uuid", "display_name" "text", "best_streak" integer, "total_games" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        sr.user_id,
        COALESCE(p.username, 'Anonymous') AS display_name,
        MAX(sr.streak_count) AS best_streak,
        COUNT(sr.id) AS total_games
    FROM public.streak_records sr
    JOIN public.profiles p ON p.id = sr.user_id
    GROUP BY sr.user_id, p.username
    ORDER BY best_streak DESC, total_games DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_streak_leaderboard"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_community_id TEXT;
    v_user_id UUID;
    v_granted_count INTEGER := 0;
BEGIN
    -- 获取活动所属社区
    SELECT community_id INTO v_community_id
    FROM public.community_events
    WHERE id = p_event_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found');
    END IF;
    
    -- 检查权限（必须是社区管理员或活动创建者）
    IF NOT (
        public.is_community_admin(v_community_id, v_admin_id) OR
        EXISTS (SELECT 1 FROM public.community_events WHERE id = p_event_id AND created_by = v_admin_id)
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    
    -- 验证积分数量
    IF p_credits_per_user <= 0 OR p_credits_per_user > 1000 THEN
        RETURN json_build_object('success', false, 'message', 'Invalid credit amount (must be 1-1000)');
    END IF;
    
    -- 为每个用户发放积分
    FOREACH v_user_id IN ARRAY p_user_ids LOOP
        -- 检查用户是否报名了该活动
        IF EXISTS (
            SELECT 1 FROM public.event_registrations
            WHERE event_id = p_event_id AND user_id = v_user_id
        ) THEN
            -- 增加积分
            UPDATE public.profiles
            SET credits = credits + p_credits_per_user
            WHERE id = v_user_id;
            
            -- 记录发放历史
            INSERT INTO public.credit_grants (user_id, granted_by, community_id, event_id, amount, reason)
            VALUES (v_user_id, v_admin_id, v_community_id, p_event_id, p_credits_per_user, p_reason);
            
            v_granted_count := v_granted_count + 1;
        END IF;
    END LOOP;
    
    -- 记录管理员操作日志
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_event_id, details)
    VALUES (v_community_id, v_admin_id, 'grant_credits', p_event_id,
            json_build_object(
                'user_count', v_granted_count,
                'credits_per_user', p_credits_per_user,
                'total_credits', v_granted_count * p_credits_per_user,
                'reason', p_reason
            ));
    
    RETURN json_build_object(
        'success', true, 
        'message', format('Credits granted to %s users', v_granted_count),
        'granted_count', v_granted_count
    );
END;
$$;


ALTER FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") IS '为活动参与者批量发放积分（仅管理员）';



CREATE OR REPLACE FUNCTION "public"."handle_community_member_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Only count if status is 'member' or 'admin'
        IF NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = member_count + 1, updated_at = NOW()
            WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Only decrement if status was 'member' or 'admin'
        IF OLD.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
            WHERE id = OLD.community_id;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Handle status changes (e.g. pending -> member)
        -- Case 1: Becoming a member
        IF OLD.status NOT IN ('member', 'admin') AND NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = member_count + 1, updated_at = NOW()
            WHERE id = NEW.community_id;
        -- Case 2: No longer a member (e.g. banned/left but kept record?) - usually DELETE is used, but covering bases
        ELSIF OLD.status IN ('member', 'admin') AND NEW.status NOT IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
            WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."handle_community_member_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_event_participant_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
         IF NEW.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = participant_count + 1
            WHERE id = NEW.event_id;
         END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
         IF OLD.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = GREATEST(0, participant_count - 1)
            WHERE id = OLD.event_id;
         END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Case 1: Becoming registered
        IF OLD.status != 'registered' AND NEW.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = participant_count + 1
            WHERE id = NEW.event_id;
        -- Case 2: No longer registered
        ELSIF OLD.status = 'registered' AND NEW.status != 'registered' THEN
            UPDATE public.community_events
            SET participant_count = GREATEST(0, participant_count - 1)
            WHERE id = NEW.event_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."handle_event_participant_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  insert into public.profiles (id, email, phone, credits)
  values (new.id, new.email, new.phone, 0);
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_user_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE public.profiles
  SET 
    email = NEW.email,
    phone = NEW.phone
    -- 如果你有 updated_at 字段，可以加上: , updated_at = NOW()
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_user_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_credits"("amount" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE public.profiles
  SET credits = credits + amount
  where id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."increment_credits"("amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_total_scans"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    UPDATE public.profiles
    SET total_scans = COALESCE(total_scans, 0) + 1
    WHERE id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."increment_total_scans"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE community_id = p_community_id
        AND user_id = p_user_id
        AND status = 'admin'
    );
END;
$$;


ALTER FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid") IS '检查用户是否是社区管理员';



CREATE OR REPLACE FUNCTION "public"."join_community"("p_community_id" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- 检查社区是否存在
    IF NOT EXISTS (SELECT 1 FROM public.communities WHERE id = p_community_id AND is_active = true) THEN
        RETURN json_build_object('success', false, 'message', 'Community not found');
    END IF;
    
    -- 检查是否已加入
    SELECT * INTO v_existing FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id;
    
    IF FOUND THEN
        IF v_existing.status = 'member' THEN
            RETURN json_build_object('success', false, 'message', 'Already a member');
        ELSIF v_existing.status = 'banned' THEN
            RETURN json_build_object('success', false, 'message', 'You are banned from this community');
        ELSE
            -- 重新激活
            UPDATE public.user_community_memberships
            SET status = 'member', joined_at = NOW()
            WHERE id = v_existing.id;
        END IF;
    ELSE
        -- 新加入
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member');
    END IF;
    
    -- 更新社区成员数
    UPDATE public.communities
    SET member_count = member_count + 1, updated_at = NOW()
    WHERE id = p_community_id;
    
    RETURN json_build_object('success', true, 'message', 'Joined community successfully');
END;
$$;


ALTER FUNCTION "public"."join_community"("p_community_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."leave_community"("p_community_id" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
    v_deleted_count INTEGER;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    DELETE FROM public.user_community_memberships
    WHERE user_id = v_user_id
      AND community_id = p_community_id
      AND status IN ('member', 'admin');

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    IF COALESCE(v_deleted_count, 0) = 0 THEN
        RETURN json_build_object('success', false, 'message', 'Not a member of this community');
    END IF;

    UPDATE public.communities
    SET member_count = GREATEST(0, COALESCE(member_count, 0) - v_deleted_count),
        updated_at = NOW()
    WHERE id = p_community_id;

    RETURN json_build_object('success', true, 'message', 'Left community successfully');
END;
$$;


ALTER FUNCTION "public"."leave_community"("p_community_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_phone_number"("p_input" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    digits TEXT;
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;

    digits := regexp_replace(p_input, '[^0-9]', '', 'g');

    IF digits IS NULL OR digits = '' THEN
        RETURN NULL;
    END IF;

    IF length(digits) = 10 THEN
        RETURN '+1' || digits;
    ELSIF length(digits) = 11 AND left(digits, 1) = '1' THEN
        RETURN '+' || digits;
    ELSE
        RETURN '+' || digits;
    END IF;
END;
$$;


ALTER FUNCTION "public"."normalize_phone_number"("p_input" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_sensitive_profile_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
    -- 仅限制普通通过 API 访问的用户，不限制 Service Role 或 Postgres Admin
    IF auth.role() = 'authenticated' THEN
        IF NEW.credits IS DISTINCT FROM OLD.credits OR 
           NEW.status IS DISTINCT FROM OLD.status OR 
           NEW.banned_until IS DISTINCT FROM OLD.banned_until THEN
            RAISE EXCEPTION 'Permission denied: Cannot modify sensitive fields (credits/status/ban).';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."protect_sensitive_profile_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_for_event"("p_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
    v_event RECORD;
    v_existing RECORD;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT * INTO v_event
    FROM public.community_events
    WHERE id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found');
    END IF;

    IF v_event.status NOT IN ('upcoming', 'ongoing') THEN
        RETURN json_build_object('success', false, 'message', 'Event is not open for registration');
    END IF;

    IF v_event.max_participants IS NOT NULL
       AND COALESCE(v_event.participant_count, 0) >= v_event.max_participants THEN
        RETURN json_build_object('success', false, 'message', 'Event is full');
    END IF;

    SELECT * INTO v_existing
    FROM public.event_registrations
    WHERE event_id = p_event_id
      AND user_id = v_user_id;

    IF FOUND THEN
        IF v_existing.status = 'registered' THEN
            RETURN json_build_object('success', false, 'message', 'Already registered');
        ELSIF v_existing.status = 'cancelled' THEN
            UPDATE public.event_registrations
            SET status = 'registered',
                registered_at = NOW()
            WHERE id = v_existing.id;
        ELSE
            RETURN json_build_object('success', false, 'message', 'Cannot register for this event');
        END IF;
    ELSE
        INSERT INTO public.event_registrations (event_id, user_id, status, registered_at)
        VALUES (p_event_id, v_user_id, 'registered', NOW());
    END IF;

    UPDATE public.community_events
    SET participant_count = COALESCE(participant_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_event_id;

    RETURN json_build_object('success', true, 'message', 'Registration successful');
END;
$$;


ALTER FUNCTION "public"."register_for_event"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_username TEXT;
BEGIN
    -- 检查权限
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    
    -- 不能移除管理员
    IF public.is_community_admin(p_community_id, p_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Cannot remove admin');
    END IF;
    
    -- 获取用户名
    SELECT username INTO v_username FROM public.profiles WHERE id = p_user_id;
    
    -- 删除成员
    DELETE FROM public.user_community_memberships
    WHERE community_id = p_community_id AND user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'User is not a member');
    END IF;
    
    -- 更新成员数
    UPDATE public.communities
    SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
    WHERE id = p_community_id;
    
    -- 记录日志
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
    VALUES (p_community_id, v_admin_id, 'remove_member', p_user_id,
            json_build_object('username', v_username, 'reason', p_reason));
    
    RETURN json_build_object('success', true, 'message', 'Member removed');
END;
$$;


ALTER FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text") IS '移除社区成员（仅管理员）';



CREATE OR REPLACE FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_community_id TEXT;
    v_user_id UUID;
    v_username TEXT;
BEGIN
    -- 获取申请信息
    SELECT community_id, user_id INTO v_community_id, v_user_id
    FROM public.community_join_applications
    WHERE id = p_application_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;
    
    -- 检查权限
    IF NOT public.is_community_admin(v_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    
    -- 获取用户名（用于日志）
    SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;
    
    IF p_approve THEN
        -- 批准：更新申请状态并添加为成员
        UPDATE public.community_join_applications
        SET status = 'approved',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = p_application_id;
        
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, v_community_id, 'member')
        ON CONFLICT (user_id, community_id) DO NOTHING;
        
        UPDATE public.communities
        SET member_count = member_count + 1, updated_at = NOW()
        WHERE id = v_community_id;
        
        -- 记录日志
        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'approve_member', v_user_id, 
                json_build_object('username', v_username));
        
        RETURN json_build_object('success', true, 'message', 'Application approved');
    ELSE
        -- 拒绝：更新申请状态
        UPDATE public.community_join_applications
        SET status = 'rejected',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            rejection_reason = p_rejection_reason,
            updated_at = NOW()
        WHERE id = p_application_id;
        
        -- 记录日志
        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'reject_member', v_user_id,
                json_build_object('username', v_username, 'reason', p_rejection_reason));
        
        RETURN json_build_object('success', true, 'message', 'Application rejected');
    END IF;
END;
$$;


ALTER FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text") IS '审批社区加入申请（仅管理员）';



CREATE OR REPLACE FUNCTION "public"."set_primary_achievement"("achievement_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF achievement_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.user_achievements ua
        WHERE ua.user_id = v_user_id
          AND ua.achievement_id = set_primary_achievement.achievement_id
    ) THEN
        RAISE EXCEPTION 'User does not own this achievement';
    END IF;

    UPDATE public.profiles
    SET selected_achievement_id = set_primary_achievement.achievement_id
    WHERE id = v_user_id;
END;
$$;


ALTER FUNCTION "public"."set_primary_achievement"("achievement_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_daily_challenge"("p_score" integer, "p_correct_count" integer, "p_time_seconds" numeric, "p_max_combo" integer) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."submit_daily_challenge"("p_score" integer, "p_correct_count" integer, "p_time_seconds" numeric, "p_max_combo" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_duel_answer"("p_challenge_id" "uuid", "p_question_index" integer, "p_selected_category" "text", "p_answer_time_ms" integer) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."submit_duel_answer"("p_challenge_id" "uuid", "p_question_index" integer, "p_selected_category" "text", "p_answer_time_ms" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_streak_record"("p_streak_count" integer) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
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


ALTER FUNCTION "public"."submit_streak_record"("p_streak_count" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text" DEFAULT NULL::"text", "p_welcome_message" "text" DEFAULT NULL::"text", "p_rules" "text" DEFAULT NULL::"text", "p_requires_approval" boolean DEFAULT NULL::boolean) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    -- 检查权限
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    
    -- 更新社区信息
    UPDATE public.communities
    SET 
        description = COALESCE(p_description, description),
        welcome_message = COALESCE(p_welcome_message, welcome_message),
        rules = COALESCE(p_rules, rules),
        requires_approval = COALESCE(p_requires_approval, requires_approval),
        updated_at = NOW()
    WHERE id = p_community_id;
    
    -- 记录日志
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, details)
    VALUES (p_community_id, v_admin_id, 'edit_community', 
            json_build_object(
                'description', p_description,
                'welcome_message', p_welcome_message,
                'requires_approval', p_requires_approval
            ));
    
    RETURN json_build_object('success', true, 'message', 'Community updated');
END;
$$;


ALTER FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text", "p_welcome_message" "text", "p_rules" "text", "p_requires_approval" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text", "p_welcome_message" "text", "p_rules" "text", "p_requires_approval" boolean) IS '更新社区信息（仅管理员）';



CREATE OR REPLACE FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.profiles
    SET location_city = p_city,
        location_state = p_state,
        location_latitude = p_latitude,
        location_longitude = p_longitude
    WHERE id = v_user_id;

    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;


ALTER FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    UPDATE public.profiles
    SET
        location_city = p_city,
        location_state = p_state,
        location_latitude = p_latitude,
        location_longitude = p_longitude
    WHERE id = v_user_id;
    
    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;


ALTER FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "text",
    "name" "text" NOT NULL,
    "description" "text",
    "icon_name" "text" NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "points" integer DEFAULT 0,
    "is_hidden" boolean DEFAULT false,
    "rarity" "text" DEFAULT 'common'::"text",
    "trigger_key" "text",
    CONSTRAINT "achievements_rarity_check" CHECK (("rarity" = ANY (ARRAY['common'::"text", 'rare'::"text", 'epic'::"text", 'legendary'::"text"])))
);


ALTER TABLE "public"."achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."admin_action_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "text" NOT NULL,
    "admin_id" "uuid" NOT NULL,
    "action_type" "text" NOT NULL,
    "target_user_id" "uuid",
    "target_event_id" "uuid",
    "details" "jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "admin_action_logs_action_type_check" CHECK (("action_type" = ANY (ARRAY['approve_member'::"text", 'reject_member'::"text", 'remove_member'::"text", 'grant_credits'::"text", 'edit_community'::"text", 'edit_event'::"text", 'delete_event'::"text", 'pin_post'::"text", 'delete_post'::"text"])))
);


ALTER TABLE "public"."admin_action_logs" OWNER TO "postgres";


COMMENT ON TABLE "public"."admin_action_logs" IS '管理员操作日志，用于审计';



CREATE TABLE IF NOT EXISTS "public"."arena_challenge_answers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "challenge_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "question_index" integer NOT NULL,
    "selected_category" "text" NOT NULL,
    "is_correct" boolean NOT NULL,
    "answer_time_ms" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."arena_challenge_answers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."arena_challenges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "challenger_id" "uuid" NOT NULL,
    "opponent_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "question_ids" "uuid"[] NOT NULL,
    "channel_name" "text",
    "challenger_score" integer DEFAULT 0,
    "opponent_score" integer DEFAULT 0,
    "winner_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "expires_at" timestamp with time zone DEFAULT ("timezone"('utc'::"text", "now"()) + '00:01:00'::interval),
    "started_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    CONSTRAINT "arena_challenges_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text", 'in_progress'::"text", 'completed'::"text", 'expired'::"text", 'declined'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."arena_challenges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."communities" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "city" "text" NOT NULL,
    "state" "text",
    "country" "text" DEFAULT 'US'::"text",
    "description" "text",
    "logo_url" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "member_count" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "created_by" "uuid",
    "requires_approval" boolean DEFAULT false,
    "welcome_message" "text",
    "rules" "text",
    "tags" "text"[],
    "is_private" boolean DEFAULT false
);


ALTER TABLE "public"."communities" OWNER TO "postgres";


COMMENT ON COLUMN "public"."communities"."requires_approval" IS '是否需要管理员审批才能加入';



COMMENT ON COLUMN "public"."communities"."is_private" IS '私密社区不会出现在公开列表中';



CREATE TABLE IF NOT EXISTS "public"."community_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "text",
    "title" "text" NOT NULL,
    "description" "text",
    "organizer" "text" NOT NULL,
    "category" "text" NOT NULL,
    "event_date" timestamp with time zone NOT NULL,
    "location" "text" NOT NULL,
    "latitude" numeric(10,8) NOT NULL,
    "longitude" numeric(11,8) NOT NULL,
    "image_url" "text",
    "icon_name" "text" DEFAULT 'calendar'::"text",
    "max_participants" integer DEFAULT 100,
    "participant_count" integer DEFAULT 0,
    "credits_reward" integer DEFAULT 10,
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "created_by" "uuid",
    "is_personal" boolean DEFAULT false,
    CONSTRAINT "community_events_category_check" CHECK (("category" = ANY (ARRAY['cleanup'::"text", 'workshop'::"text", 'competition'::"text", 'education'::"text", 'other'::"text"]))),
    CONSTRAINT "community_events_status_check" CHECK (("status" = ANY (ARRAY['upcoming'::"text", 'ongoing'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."community_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_join_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "message" "text",
    "rejection_reason" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "community_join_applications_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."community_join_applications" OWNER TO "postgres";


COMMENT ON TABLE "public"."community_join_applications" IS '社区加入申请表';



CREATE TABLE IF NOT EXISTS "public"."credit_grants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "granted_by" "uuid" NOT NULL,
    "community_id" "text",
    "event_id" "uuid",
    "amount" integer NOT NULL,
    "reason" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "credit_grants_amount_check" CHECK (("amount" > 0))
);


ALTER TABLE "public"."credit_grants" OWNER TO "postgres";


COMMENT ON TABLE "public"."credit_grants" IS '管理员手动发放积分的记录';



CREATE TABLE IF NOT EXISTS "public"."daily_challenge_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "challenge_date" "date" NOT NULL,
    "score" integer DEFAULT 0 NOT NULL,
    "correct_count" integer DEFAULT 0 NOT NULL,
    "time_seconds" numeric DEFAULT 0 NOT NULL,
    "max_combo" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."daily_challenge_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_challenges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "challenge_date" "date" NOT NULL,
    "question_ids" "uuid"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."daily_challenges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'registered'::"text",
    "registered_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "attended_at" timestamp with time zone,
    "credits_earned" integer DEFAULT 0,
    CONSTRAINT "event_registrations_status_check" CHECK (("status" = ANY (ARRAY['registered'::"text", 'attended'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."event_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedback_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "user_id" "uuid",
    "predicted_label" "text",
    "predicted_category" "text",
    "user_correction" "text",
    "user_comment" "text",
    "image_path" "text"
);


ALTER TABLE "public"."feedback_logs" OWNER TO "postgres";


ALTER TABLE "public"."feedback_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."feedback_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "phone" "text",
    "email" "text",
    "credits" integer DEFAULT 0,
    "username" "text",
    "status" "text" DEFAULT 'active'::"text",
    "banned_until" timestamp with time zone,
    "location_city" "text",
    "location_state" "text",
    "location_latitude" numeric(10,8),
    "location_longitude" numeric(11,8),
    "selected_achievement_id" "uuid",
    "total_scans" integer DEFAULT 0
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."streak_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "streak_count" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."streak_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_achievements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "achievement_id" "uuid",
    "community_id" "text",
    "granted_at" timestamp with time zone DEFAULT "now"(),
    "granted_by" "uuid"
);


ALTER TABLE "public"."user_achievements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_community_memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "community_id" "text" NOT NULL,
    "status" "text" DEFAULT 'member'::"text",
    "joined_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "user_community_memberships_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'member'::"text", 'admin'::"text", 'banned'::"text"])))
);


ALTER TABLE "public"."user_community_memberships" OWNER TO "postgres";


ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_trigger_key_key" UNIQUE ("trigger_key");



ALTER TABLE ONLY "public"."admin_action_logs"
    ADD CONSTRAINT "admin_action_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."arena_challenge_answers"
    ADD CONSTRAINT "arena_challenge_answers_challenge_id_user_id_question_index_key" UNIQUE ("challenge_id", "user_id", "question_index");



ALTER TABLE ONLY "public"."arena_challenge_answers"
    ADD CONSTRAINT "arena_challenge_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."arena_challenges"
    ADD CONSTRAINT "arena_challenges_channel_name_key" UNIQUE ("channel_name");



ALTER TABLE ONLY "public"."arena_challenges"
    ADD CONSTRAINT "arena_challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."communities"
    ADD CONSTRAINT "communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_join_applications"
    ADD CONSTRAINT "community_join_applications_community_id_user_id_key" UNIQUE ("community_id", "user_id");



ALTER TABLE ONLY "public"."community_join_applications"
    ADD CONSTRAINT "community_join_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_grants"
    ADD CONSTRAINT "credit_grants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_challenge_results"
    ADD CONSTRAINT "daily_challenge_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_challenge_results"
    ADD CONSTRAINT "daily_challenge_results_user_id_challenge_date_key" UNIQUE ("user_id", "challenge_date");



ALTER TABLE ONLY "public"."daily_challenges"
    ADD CONSTRAINT "daily_challenges_challenge_date_key" UNIQUE ("challenge_date");



ALTER TABLE ONLY "public"."daily_challenges"
    ADD CONSTRAINT "daily_challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback_logs"
    ADD CONSTRAINT "feedback_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quiz_questions"
    ADD CONSTRAINT "quiz_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."streak_records"
    ADD CONSTRAINT "streak_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_user_id_achievement_id_key" UNIQUE ("user_id", "achievement_id");



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_user_id_community_id_key" UNIQUE ("user_id", "community_id");



CREATE INDEX "idx_admin_logs_admin" ON "public"."admin_action_logs" USING "btree" ("admin_id");



CREATE INDEX "idx_admin_logs_community" ON "public"."admin_action_logs" USING "btree" ("community_id", "created_at" DESC);



CREATE INDEX "idx_applications_community" ON "public"."community_join_applications" USING "btree" ("community_id", "status");



CREATE INDEX "idx_applications_status" ON "public"."community_join_applications" USING "btree" ("status");



CREATE INDEX "idx_applications_user" ON "public"."community_join_applications" USING "btree" ("user_id");



CREATE INDEX "idx_challenge_answers_challenge" ON "public"."arena_challenge_answers" USING "btree" ("challenge_id", "user_id");



CREATE INDEX "idx_challenges_challenger" ON "public"."arena_challenges" USING "btree" ("challenger_id", "status");



CREATE INDEX "idx_challenges_channel" ON "public"."arena_challenges" USING "btree" ("channel_name");



CREATE INDEX "idx_challenges_opponent" ON "public"."arena_challenges" USING "btree" ("opponent_id", "status");



CREATE INDEX "idx_challenges_status" ON "public"."arena_challenges" USING "btree" ("status");



CREATE UNIQUE INDEX "idx_challenges_unique_pending" ON "public"."arena_challenges" USING "btree" ("challenger_id", "opponent_id") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_communities_city" ON "public"."communities" USING "btree" ("city");



CREATE INDEX "idx_communities_created_by" ON "public"."communities" USING "btree" ("created_by");



CREATE INDEX "idx_communities_is_active" ON "public"."communities" USING "btree" ("is_active");



CREATE INDEX "idx_communities_location" ON "public"."communities" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_communities_state" ON "public"."communities" USING "btree" ("state");



CREATE INDEX "idx_credit_grants_community" ON "public"."credit_grants" USING "btree" ("community_id");



CREATE INDEX "idx_credit_grants_event" ON "public"."credit_grants" USING "btree" ("event_id");



CREATE INDEX "idx_credit_grants_user" ON "public"."credit_grants" USING "btree" ("user_id");



CREATE INDEX "idx_daily_challenges_date" ON "public"."daily_challenges" USING "btree" ("challenge_date" DESC);



CREATE INDEX "idx_daily_results_date" ON "public"."daily_challenge_results" USING "btree" ("challenge_date", "score" DESC);



CREATE INDEX "idx_daily_results_user" ON "public"."daily_challenge_results" USING "btree" ("user_id");



CREATE INDEX "idx_events_category" ON "public"."community_events" USING "btree" ("category");



CREATE INDEX "idx_events_community" ON "public"."community_events" USING "btree" ("community_id");



CREATE INDEX "idx_events_created_by" ON "public"."community_events" USING "btree" ("created_by");



CREATE INDEX "idx_events_date" ON "public"."community_events" USING "btree" ("event_date");



CREATE INDEX "idx_events_is_personal" ON "public"."community_events" USING "btree" ("is_personal");



CREATE INDEX "idx_events_location" ON "public"."community_events" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_events_status" ON "public"."community_events" USING "btree" ("status");



CREATE INDEX "idx_memberships_community" ON "public"."user_community_memberships" USING "btree" ("community_id");



CREATE INDEX "idx_memberships_status" ON "public"."user_community_memberships" USING "btree" ("status");



CREATE INDEX "idx_memberships_user" ON "public"."user_community_memberships" USING "btree" ("user_id");



CREATE INDEX "idx_profiles_coordinates" ON "public"."profiles" USING "btree" ("location_latitude", "location_longitude");



CREATE INDEX "idx_profiles_location" ON "public"."profiles" USING "btree" ("location_city", "location_state");



CREATE INDEX "idx_registrations_event" ON "public"."event_registrations" USING "btree" ("event_id");



CREATE INDEX "idx_registrations_status" ON "public"."event_registrations" USING "btree" ("status");



CREATE INDEX "idx_registrations_user" ON "public"."event_registrations" USING "btree" ("user_id");



CREATE INDEX "idx_streak_records_streak_count" ON "public"."streak_records" USING "btree" ("streak_count" DESC);



CREATE INDEX "idx_streak_records_user_id" ON "public"."streak_records" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "ensure_profile_security" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_sensitive_profile_fields"();



CREATE OR REPLACE TRIGGER "on_community_member_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."user_community_memberships" FOR EACH ROW EXECUTE FUNCTION "public"."handle_community_member_count"();



CREATE OR REPLACE TRIGGER "on_event_registration_change" AFTER INSERT OR DELETE OR UPDATE ON "public"."event_registrations" FOR EACH ROW EXECUTE FUNCTION "public"."handle_event_participant_count"();



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."achievements"
    ADD CONSTRAINT "achievements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."admin_action_logs"
    ADD CONSTRAINT "admin_action_logs_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_action_logs"
    ADD CONSTRAINT "admin_action_logs_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_action_logs"
    ADD CONSTRAINT "admin_action_logs_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."arena_challenge_answers"
    ADD CONSTRAINT "arena_challenge_answers_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "public"."arena_challenges"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."arena_challenge_answers"
    ADD CONSTRAINT "arena_challenge_answers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."arena_challenges"
    ADD CONSTRAINT "arena_challenges_challenger_id_fkey" FOREIGN KEY ("challenger_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."arena_challenges"
    ADD CONSTRAINT "arena_challenges_opponent_id_fkey" FOREIGN KEY ("opponent_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."arena_challenges"
    ADD CONSTRAINT "arena_challenges_winner_id_fkey" FOREIGN KEY ("winner_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."communities"
    ADD CONSTRAINT "communities_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."community_join_applications"
    ADD CONSTRAINT "community_join_applications_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."community_join_applications"
    ADD CONSTRAINT "community_join_applications_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."community_join_applications"
    ADD CONSTRAINT "community_join_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_grants"
    ADD CONSTRAINT "credit_grants_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."credit_grants"
    ADD CONSTRAINT "credit_grants_granted_by_fkey" FOREIGN KEY ("granted_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."credit_grants"
    ADD CONSTRAINT "credit_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_challenge_results"
    ADD CONSTRAINT "daily_challenge_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."community_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback_logs"
    ADD CONSTRAINT "feedback_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_selected_achievement_id_fkey" FOREIGN KEY ("selected_achievement_id") REFERENCES "public"."achievements"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."streak_records"
    ADD CONSTRAINT "streak_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_achievement_id_fkey" FOREIGN KEY ("achievement_id") REFERENCES "public"."achievements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_granted_by_fkey" FOREIGN KEY ("granted_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_achievements"
    ADD CONSTRAINT "user_achievements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Achievements insert (admins)" ON "public"."achievements" FOR INSERT TO "authenticated" WITH CHECK ((("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "achievements"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text"))))));



CREATE POLICY "Achievements readable (auth)" ON "public"."achievements" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Achievements update (admins)" ON "public"."achievements" FOR UPDATE TO "authenticated" USING ((("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "achievements"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text")))))) WITH CHECK ((("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "achievements"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text"))))));



CREATE POLICY "Admins can view action logs" ON "public"."admin_action_logs" FOR SELECT TO "authenticated" USING ("public"."is_community_admin"("community_id", "public"."current_user_id"()));



CREATE POLICY "Communities delete own" ON "public"."communities" FOR DELETE TO "authenticated" USING ((("created_by" = "public"."current_user_id"()) OR (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "communities"."id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text"))))));



CREATE POLICY "Communities insert (authenticated)" ON "public"."communities" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = "public"."current_user_id"()) AND ("public"."current_user_id"() IS NOT NULL)));



CREATE POLICY "Communities readable (authenticated)" ON "public"."communities" FOR SELECT TO "authenticated" USING ((("public"."current_user_id"() IS NOT NULL) AND ((COALESCE("is_private", false) = false) OR ("created_by" = "public"."current_user_id"()) OR (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "communities"."id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = ANY (ARRAY['member'::"text", 'admin'::"text"]))))))));



CREATE POLICY "Communities update own" ON "public"."communities" FOR UPDATE TO "authenticated" USING ((("created_by" = "public"."current_user_id"()) OR (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "communities"."id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text")))))) WITH CHECK ((("created_by" = "public"."current_user_id"()) OR (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "communities"."id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text"))))));



CREATE POLICY "Daily challenges are readable by authenticated users" ON "public"."daily_challenges" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Daily results are readable by authenticated users" ON "public"."daily_challenge_results" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."feedback_logs" FOR SELECT USING (true);



CREATE POLICY "Events are viewable by everyone" ON "public"."community_events" FOR SELECT USING (true);



CREATE POLICY "Events delete (owner-or-admin)" ON "public"."community_events" FOR DELETE TO "authenticated" USING ((("created_by" = "public"."current_user_id"()) OR (("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "m"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text")))))));



CREATE POLICY "Events insert (authenticated)" ON "public"."community_events" FOR INSERT TO "authenticated" WITH CHECK ((("created_by" = "public"."current_user_id"()) AND (("is_personal" IS TRUE) OR ("community_id" IS NULL) OR (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "m"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = ANY (ARRAY['member'::"text", 'admin'::"text"]))))))));



CREATE POLICY "Events readable (members)" ON "public"."community_events" FOR SELECT TO "authenticated" USING ((("public"."current_user_id"() IS NOT NULL) AND ((("is_personal" IS TRUE) AND ("created_by" = "public"."current_user_id"())) OR (("is_personal" IS NOT TRUE) AND (("community_id" IS NULL) OR (EXISTS ( SELECT 1
   FROM ("public"."communities" "c"
     LEFT JOIN "public"."user_community_memberships" "m" ON ((("m"."community_id" = "c"."id") AND ("m"."user_id" = "public"."current_user_id"()))))
  WHERE (("c"."id" = "community_events"."community_id") AND ((COALESCE("c"."is_private", false) = false) OR ("m"."status" = ANY (ARRAY['member'::"text", 'admin'::"text"])) OR ("c"."created_by" = "public"."current_user_id"()))))))))));



CREATE POLICY "Events update (owner-or-admin)" ON "public"."community_events" FOR UPDATE TO "authenticated" USING ((("created_by" = "public"."current_user_id"()) OR (("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "m"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text"))))))) WITH CHECK ((("created_by" = "public"."current_user_id"()) OR (("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "m"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text")))))));



CREATE POLICY "Feedback readable" ON "public"."feedback_logs" FOR SELECT TO "authenticated" USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Feedback self-manage" ON "public"."feedback_logs" TO "authenticated" USING (("user_id" = "public"."current_user_id"())) WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Membership roster visibility" ON "public"."user_community_memberships" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."can_view_community_roster"("community_id", "auth"."uid"())));



CREATE POLICY "Membership self-management" ON "public"."user_community_memberships" TO "authenticated" USING (("user_id" = "public"."current_user_id"())) WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Quiz questions are readable by authenticated users" ON "public"."quiz_questions" FOR SELECT TO "authenticated" USING (("is_active" = true));



CREATE POLICY "Registrations readable (owner)" ON "public"."event_registrations" FOR SELECT TO "authenticated" USING (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Registrations self-management" ON "public"."event_registrations" TO "authenticated" USING (("user_id" = "public"."current_user_id"())) WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Streak records are readable by authenticated users" ON "public"."streak_records" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "User achievements grant" ON "public"."user_achievements" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."achievements" "a"
     LEFT JOIN "public"."user_community_memberships" "m" ON ((("m"."community_id" = "a"."community_id") AND ("m"."user_id" = "public"."current_user_id"()))))
  WHERE (("a"."id" = "user_achievements"."achievement_id") AND (("a"."community_id" IS NULL) OR ("m"."status" = 'admin'::"text"))))));



CREATE POLICY "User achievements readable" ON "public"."user_achievements" FOR SELECT TO "authenticated" USING ((("user_id" = "public"."current_user_id"()) OR (("community_id" IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM "public"."user_community_memberships" "m"
  WHERE (("m"."community_id" = "user_achievements"."community_id") AND ("m"."user_id" = "public"."current_user_id"()) AND ("m"."status" = 'admin'::"text")))))));



CREATE POLICY "Users can insert their own daily results" ON "public"."daily_challenge_results" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can insert their own streak records" ON "public"."streak_records" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "public"."current_user_id"()));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view answers for their challenges" ON "public"."arena_challenge_answers" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."arena_challenges" "ac"
  WHERE (("ac"."id" = "arena_challenge_answers"."challenge_id") AND (("ac"."challenger_id" = "public"."current_user_id"()) OR ("ac"."opponent_id" = "public"."current_user_id"()))))));



CREATE POLICY "Users can view own applications" ON "public"."community_join_applications" FOR SELECT TO "authenticated" USING ((("public"."current_user_id"() = "user_id") OR "public"."is_community_admin"("community_id", "public"."current_user_id"())));



CREATE POLICY "Users can view own credit grants" ON "public"."credit_grants" FOR SELECT TO "authenticated" USING ((("public"."current_user_id"() = "user_id") OR (("community_id" IS NOT NULL) AND "public"."is_community_admin"("community_id", "public"."current_user_id"()))));



CREATE POLICY "Users can view their own challenges" ON "public"."arena_challenges" FOR SELECT TO "authenticated" USING ((("public"."current_user_id"() = "challenger_id") OR ("public"."current_user_id"() = "opponent_id")));



ALTER TABLE "public"."achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."admin_action_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."arena_challenge_answers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."arena_challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_join_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."credit_grants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_challenge_results" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."daily_challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_registrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quiz_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."streak_records" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_achievements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_community_memberships" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."accept_arena_challenge"("p_challenge_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."accept_arena_challenge"("p_challenge_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."accept_arena_challenge"("p_challenge_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_to_join_community"("p_community_id" "text", "p_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_create_community"() TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_create_community"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_create_community"() TO "service_role";



GRANT ALL ON FUNCTION "public"."can_user_create_event"() TO "anon";
GRANT ALL ON FUNCTION "public"."can_user_create_event"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_user_create_event"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_view_community_roster"("p_community_id" "text", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_and_grant_achievement"("p_trigger_key" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_and_grant_achievement"("p_trigger_key" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_and_grant_achievement"("p_trigger_key" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_arena_challenge"("p_challenge_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_arena_challenge"("p_challenge_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_arena_challenge"("p_challenge_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_arena_challenge"("p_opponent_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_arena_challenge"("p_opponent_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_arena_challenge"("p_opponent_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_community"("p_id" "text", "p_name" "text", "p_city" "text", "p_state" "text", "p_description" "text", "p_latitude" numeric, "p_longitude" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."create_community"("p_id" "text", "p_name" "text", "p_city" "text", "p_state" "text", "p_description" "text", "p_latitude" numeric, "p_longitude" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_community"("p_id" "text", "p_name" "text", "p_city" "text", "p_state" "text", "p_description" "text", "p_latitude" numeric, "p_longitude" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_event"("p_title" "text", "p_description" "text", "p_category" "text", "p_event_date" timestamp with time zone, "p_location" "text", "p_latitude" numeric, "p_longitude" numeric, "p_max_participants" integer, "p_community_id" "text", "p_icon_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_event"("p_title" "text", "p_description" "text", "p_category" "text", "p_event_date" timestamp with time zone, "p_location" "text", "p_latitude" numeric, "p_longitude" numeric, "p_max_participants" integer, "p_community_id" "text", "p_icon_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_event"("p_title" "text", "p_description" "text", "p_category" "text", "p_event_date" timestamp with time zone, "p_location" "text", "p_latitude" numeric, "p_longitude" numeric, "p_max_participants" integer, "p_community_id" "text", "p_icon_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."decline_arena_challenge"("p_challenge_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."decline_arena_challenge"("p_challenge_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."decline_arena_challenge"("p_challenge_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_admin_action_logs"("p_community_id" "text", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_challenge_questions"("p_challenge_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_challenge_questions"("p_challenge_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_challenge_questions"("p_challenge_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_community_events"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_community_events"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_community_events"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_community_members_admin"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_community_members_admin"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_community_members_admin"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_community_members_for_grant"("p_community_id" "text", "p_achievement_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_community_members_for_grant"("p_community_id" "text", "p_achievement_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_community_members_for_grant"("p_community_id" "text", "p_achievement_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_daily_challenge"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_daily_challenge"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_daily_challenge"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_daily_leaderboard"("p_date" "date", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_daily_leaderboard"("p_date" "date", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_daily_leaderboard"("p_date" "date", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_event_participants"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_event_participants"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_event_participants"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_achievements"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_achievements"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_achievements"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_challenges"("p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_challenges"("p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_challenges"("p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_pending_applications"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_pending_applications"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_pending_applications"("p_community_id" "text") TO "service_role";



GRANT ALL ON TABLE "public"."quiz_questions" TO "anon";
GRANT ALL ON TABLE "public"."quiz_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."quiz_questions" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_quiz_questions_batch"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_quiz_questions_batch"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_quiz_questions_batch"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_streak_leaderboard"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_streak_leaderboard"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_streak_leaderboard"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."grant_event_credits"("p_event_id" "uuid", "p_user_ids" "uuid"[], "p_credits_per_user" integer, "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_community_member_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_community_member_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_community_member_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_event_participant_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_event_participant_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_event_participant_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_total_scans"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_total_scans"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_total_scans"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_community_admin"("p_community_id" "text", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."normalize_phone_number"("p_input" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."normalize_phone_number"("p_input" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_phone_number"("p_input" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_community_member"("p_community_id" "text", "p_user_id" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."review_join_application"("p_application_id" "uuid", "p_approve" boolean, "p_rejection_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_primary_achievement"("achievement_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."set_primary_achievement"("achievement_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_primary_achievement"("achievement_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_daily_challenge"("p_score" integer, "p_correct_count" integer, "p_time_seconds" numeric, "p_max_combo" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."submit_daily_challenge"("p_score" integer, "p_correct_count" integer, "p_time_seconds" numeric, "p_max_combo" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_daily_challenge"("p_score" integer, "p_correct_count" integer, "p_time_seconds" numeric, "p_max_combo" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_duel_answer"("p_challenge_id" "uuid", "p_question_index" integer, "p_selected_category" "text", "p_answer_time_ms" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."submit_duel_answer"("p_challenge_id" "uuid", "p_question_index" integer, "p_selected_category" "text", "p_answer_time_ms" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_duel_answer"("p_challenge_id" "uuid", "p_question_index" integer, "p_selected_category" "text", "p_answer_time_ms" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_streak_record"("p_streak_count" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."submit_streak_record"("p_streak_count" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_streak_record"("p_streak_count" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text", "p_welcome_message" "text", "p_rules" "text", "p_requires_approval" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text", "p_welcome_message" "text", "p_rules" "text", "p_requires_approval" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_community_info"("p_community_id" "text", "p_description" "text", "p_welcome_message" "text", "p_rules" "text", "p_requires_approval" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" double precision, "p_longitude" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "service_role";


















GRANT ALL ON TABLE "public"."achievements" TO "anon";
GRANT ALL ON TABLE "public"."achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."achievements" TO "service_role";



GRANT ALL ON TABLE "public"."admin_action_logs" TO "anon";
GRANT ALL ON TABLE "public"."admin_action_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."admin_action_logs" TO "service_role";



GRANT ALL ON TABLE "public"."arena_challenge_answers" TO "anon";
GRANT ALL ON TABLE "public"."arena_challenge_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."arena_challenge_answers" TO "service_role";



GRANT ALL ON TABLE "public"."arena_challenges" TO "anon";
GRANT ALL ON TABLE "public"."arena_challenges" TO "authenticated";
GRANT ALL ON TABLE "public"."arena_challenges" TO "service_role";



GRANT ALL ON TABLE "public"."communities" TO "anon";
GRANT ALL ON TABLE "public"."communities" TO "authenticated";
GRANT ALL ON TABLE "public"."communities" TO "service_role";



GRANT ALL ON TABLE "public"."community_events" TO "anon";
GRANT ALL ON TABLE "public"."community_events" TO "authenticated";
GRANT ALL ON TABLE "public"."community_events" TO "service_role";



GRANT ALL ON TABLE "public"."community_join_applications" TO "anon";
GRANT ALL ON TABLE "public"."community_join_applications" TO "authenticated";
GRANT ALL ON TABLE "public"."community_join_applications" TO "service_role";



GRANT ALL ON TABLE "public"."credit_grants" TO "anon";
GRANT ALL ON TABLE "public"."credit_grants" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_grants" TO "service_role";



GRANT ALL ON TABLE "public"."daily_challenge_results" TO "anon";
GRANT ALL ON TABLE "public"."daily_challenge_results" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_challenge_results" TO "service_role";



GRANT ALL ON TABLE "public"."daily_challenges" TO "anon";
GRANT ALL ON TABLE "public"."daily_challenges" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_challenges" TO "service_role";



GRANT ALL ON TABLE "public"."event_registrations" TO "anon";
GRANT ALL ON TABLE "public"."event_registrations" TO "authenticated";
GRANT ALL ON TABLE "public"."event_registrations" TO "service_role";



GRANT ALL ON TABLE "public"."feedback_logs" TO "anon";
GRANT ALL ON TABLE "public"."feedback_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."streak_records" TO "anon";
GRANT ALL ON TABLE "public"."streak_records" TO "authenticated";
GRANT ALL ON TABLE "public"."streak_records" TO "service_role";



GRANT ALL ON TABLE "public"."user_achievements" TO "anon";
GRANT ALL ON TABLE "public"."user_achievements" TO "authenticated";
GRANT ALL ON TABLE "public"."user_achievements" TO "service_role";



GRANT ALL ON TABLE "public"."user_community_memberships" TO "anon";
GRANT ALL ON TABLE "public"."user_community_memberships" TO "authenticated";
GRANT ALL ON TABLE "public"."user_community_memberships" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































drop extension if exists "pg_net";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();


  create policy "Allow public select 1d1lroy_0"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'feedback_images'::text));



  create policy "Allow uploads 1d1lroy_0"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check ((bucket_id = 'feedback_images'::text));



