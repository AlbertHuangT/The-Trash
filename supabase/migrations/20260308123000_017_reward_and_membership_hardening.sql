-- ============================================================
-- Migration 017: Reward, storage, and membership hardening
-- Date: 2026-03-08
--
-- Fixes:
-- 1. Move Verify rewards into one server-owned RPC with idempotency.
-- 2. Stop exposing feedback images publicly.
-- 3. Require linked identities for feedback / quiz candidate ingestion.
-- 4. Prevent duplicate event credit grants for the same event participant.
-- 5. Expose richer membership state for community browsing.
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_linked_account(
    p_user_id UUID DEFAULT public.current_user_id()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email TEXT;
    v_phone TEXT;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT NULLIF(BTRIM(email), ''), NULLIF(BTRIM(phone), '')
    INTO v_email, v_phone
    FROM auth.users
    WHERE id = p_user_id;

    RETURN v_email IS NOT NULL OR v_phone IS NOT NULL;
END;
$$;

ALTER FUNCTION public.is_linked_account(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.is_linked_account(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_linked_account(UUID) TO service_role;

CREATE TABLE IF NOT EXISTS public.verify_reward_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    scan_id UUID NOT NULL,
    reward_kind TEXT NOT NULL CHECK (reward_kind IN ('confirmed', 'correction')),
    credits_awarded INTEGER NOT NULL CHECK (credits_awarded > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (user_id, scan_id)
);

CREATE INDEX IF NOT EXISTS idx_verify_reward_events_user_created_at
    ON public.verify_reward_events(user_id, created_at DESC);

ALTER TABLE public.verify_reward_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Verify reward events select own" ON public.verify_reward_events;

CREATE POLICY "Verify reward events select own"
    ON public.verify_reward_events FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.check_and_grant_achievement(p_trigger_key TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_achievement RECORD;
    v_already_has BOOLEAN;
    v_auth_email TEXT;
    v_email_confirmed_at TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('granted', false, 'reason', 'Not authenticated');
    END IF;

    IF p_trigger_key <> 'ucsd_email' THEN
        RETURN json_build_object(
            'granted', false,
            'reason', 'Trigger is server-managed'
        );
    END IF;

    SELECT * INTO v_achievement
    FROM public.achievements
    WHERE trigger_key = p_trigger_key
      AND community_id IS NULL;

    IF NOT FOUND THEN
        RETURN json_build_object('granted', false, 'reason', 'Achievement not found');
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.user_achievements
        WHERE user_id = v_user_id
          AND achievement_id = v_achievement.id
    ) INTO v_already_has;

    IF v_already_has THEN
        RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END IF;

    SELECT email, email_confirmed_at
    INTO v_auth_email, v_email_confirmed_at
    FROM auth.users
    WHERE id = v_user_id;

    IF v_email_confirmed_at IS NULL OR v_auth_email IS NULL OR v_auth_email NOT ILIKE '%@ucsd.edu' THEN
        RETURN json_build_object('granted', false, 'reason', 'Not qualified');
    END IF;

    BEGIN
        INSERT INTO public.user_achievements (user_id, achievement_id)
        VALUES (v_user_id, v_achievement.id);
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END;

    RETURN json_build_object(
        'granted', true,
        'id', v_achievement.id,
        'name', v_achievement.name,
        'description', v_achievement.description,
        'icon_name', v_achievement.icon_name,
        'rarity', v_achievement.rarity
    );
END;
$$;

ALTER FUNCTION public.check_and_grant_achievement(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.check_and_grant_achievement(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.award_verify_reward(
    p_scan_id UUID,
    p_reward_kind TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_reward_amount INTEGER;
    v_profile RECORD;
    v_daily_count INTEGER;
    v_granted_achievements TEXT[] := ARRAY[]::TEXT[];
    v_achievement RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_linked_account(v_user_id) THEN
        RETURN json_build_object(
            'awarded', false,
            'reason', 'Linked account required',
            'credits_awarded', 0
        );
    END IF;

    IF p_scan_id IS NULL THEN
        RAISE EXCEPTION 'scan_id is required';
    END IF;

    CASE p_reward_kind
        WHEN 'confirmed' THEN v_reward_amount := 10;
        WHEN 'correction' THEN v_reward_amount := 20;
        ELSE
            RAISE EXCEPTION 'Unsupported reward kind: %', p_reward_kind;
    END CASE;

    SELECT COUNT(*)
    INTO v_daily_count
    FROM public.verify_reward_events
    WHERE user_id = v_user_id
      AND created_at >= date_trunc('day', timezone('utc', now()));

    IF v_daily_count >= 50 THEN
        RETURN json_build_object(
            'awarded', false,
            'reason', 'Daily Verify reward limit reached',
            'credits_awarded', 0
        );
    END IF;

    INSERT INTO public.verify_reward_events (
        user_id, scan_id, reward_kind, credits_awarded
    )
    VALUES (
        v_user_id, p_scan_id, p_reward_kind, v_reward_amount
    )
    ON CONFLICT (user_id, scan_id) DO NOTHING;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'awarded', false,
            'reason', 'Reward already claimed for this scan',
            'credits_awarded', 0
        );
    END IF;

    UPDATE public.profiles
    SET credits = COALESCE(credits, 0) + v_reward_amount,
        total_scans = COALESCE(total_scans, 0) + 1
    WHERE id = v_user_id
    RETURNING credits, total_scans
    INTO v_profile;

    FOR v_achievement IN
        SELECT id, name, trigger_key
        FROM public.achievements
        WHERE community_id IS NULL
          AND trigger_key IN (
              'first_scan',
              'scans_10',
              'scans_50',
              'credits_100',
              'credits_500',
              'credits_2000'
          )
    LOOP
        IF EXISTS (
            SELECT 1
            FROM public.user_achievements
            WHERE user_id = v_user_id
              AND achievement_id = v_achievement.id
        ) THEN
            CONTINUE;
        END IF;

        IF (
            v_achievement.trigger_key = 'first_scan' AND COALESCE(v_profile.total_scans, 0) >= 1
        ) OR (
            v_achievement.trigger_key = 'scans_10' AND COALESCE(v_profile.total_scans, 0) >= 10
        ) OR (
            v_achievement.trigger_key = 'scans_50' AND COALESCE(v_profile.total_scans, 0) >= 50
        ) OR (
            v_achievement.trigger_key = 'credits_100' AND COALESCE(v_profile.credits, 0) >= 100
        ) OR (
            v_achievement.trigger_key = 'credits_500' AND COALESCE(v_profile.credits, 0) >= 500
        ) OR (
            v_achievement.trigger_key = 'credits_2000' AND COALESCE(v_profile.credits, 0) >= 2000
        ) THEN
            BEGIN
                INSERT INTO public.user_achievements (user_id, achievement_id)
                VALUES (v_user_id, v_achievement.id);
            EXCEPTION
                WHEN unique_violation THEN
                    CONTINUE;
            END;
            v_granted_achievements := array_append(v_granted_achievements, v_achievement.name);
        END IF;
    END LOOP;

    RETURN json_build_object(
        'awarded', true,
        'credits_awarded', v_reward_amount,
        'total_credits', COALESCE(v_profile.credits, 0),
        'total_scans', COALESCE(v_profile.total_scans, 0),
        'granted_achievements', v_granted_achievements
    );
END;
$$;

ALTER FUNCTION public.award_verify_reward(UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.award_verify_reward(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.increment_credits(INTEGER) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_total_scans() FROM authenticated;

UPDATE storage.buckets
SET public = false
WHERE id = 'feedback_images';

DROP POLICY IF EXISTS "Feedback images upload (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Feedback images read (public bucket)" ON storage.objects;
DROP POLICY IF EXISTS "Feedback images delete (own folder)" ON storage.objects;

CREATE POLICY "Feedback images upload (own folder)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'feedback_images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Feedback images read (own folder)"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'feedback_images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Feedback images delete (own folder)"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'feedback_images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Quiz candidate images upload (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images read (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images delete (own folder)" ON storage.objects;

CREATE POLICY "Quiz candidate images upload (own folder)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'quiz-candidate-images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images read (own folder)"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'quiz-candidate-images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images delete (own folder)"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'quiz-candidate-images'
        AND public.is_linked_account(auth.uid())
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Feedback select own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback insert own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback update own" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback delete own" ON public.feedback_logs;

CREATE POLICY "Feedback select own"
    ON public.feedback_logs FOR SELECT TO authenticated
    USING (
        auth.uid() IS NOT NULL
        AND public.is_linked_account(auth.uid())
        AND user_id = auth.uid()
    );

CREATE POLICY "Feedback insert own"
    ON public.feedback_logs FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND public.is_linked_account(auth.uid())
        AND user_id = auth.uid()
    );

CREATE POLICY "Feedback update own"
    ON public.feedback_logs FOR UPDATE TO authenticated
    USING (
        auth.uid() IS NOT NULL
        AND public.is_linked_account(auth.uid())
        AND user_id = auth.uid()
    )
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND public.is_linked_account(auth.uid())
        AND user_id = auth.uid()
    );

CREATE POLICY "Feedback delete own"
    ON public.feedback_logs FOR DELETE TO authenticated
    USING (
        auth.uid() IS NOT NULL
        AND public.is_linked_account(auth.uid())
        AND user_id = auth.uid()
    );

DROP POLICY IF EXISTS "Quiz candidates insert own" ON public.quiz_question_candidates;

CREATE POLICY "Quiz candidates insert own"
    ON public.quiz_question_candidates FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND public.is_linked_account(auth.uid())
    );

DELETE FROM public.credit_grants cg
USING public.credit_grants newer
WHERE cg.event_id IS NOT NULL
  AND newer.event_id = cg.event_id
  AND newer.user_id = cg.user_id
  AND newer.created_at > cg.created_at;

DROP INDEX IF EXISTS public.uq_credit_grants_event_user_reason;

CREATE UNIQUE INDEX IF NOT EXISTS uq_credit_grants_event_user
    ON public.credit_grants (event_id, user_id)
    WHERE event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.grant_event_credits(
    p_event_id UUID,
    p_user_ids UUID[],
    p_credits_per_user INTEGER,
    p_reason TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := public.current_user_id();
    v_community_id TEXT;
    v_user_id UUID;
    v_granted_count INTEGER := 0;
    v_inserted_id UUID;
BEGIN
    SELECT community_id INTO v_community_id
    FROM public.community_events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found', 'granted_count', 0);
    END IF;

    IF NOT (
        public.is_community_admin(v_community_id, v_admin_id)
        OR EXISTS (
            SELECT 1
            FROM public.community_events
            WHERE id = p_event_id AND created_by = v_admin_id
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied', 'granted_count', 0);
    END IF;

    IF p_credits_per_user <= 0 OR p_credits_per_user > 1000 THEN
        RETURN json_build_object('success', false, 'message', 'Invalid credit amount (must be 1-1000)', 'granted_count', 0);
    END IF;

    FOREACH v_user_id IN ARRAY p_user_ids LOOP
        IF EXISTS (
            SELECT 1
            FROM public.event_registrations
            WHERE event_id = p_event_id
              AND user_id = v_user_id
              AND status = 'registered'
        ) THEN
            INSERT INTO public.credit_grants (
                user_id, granted_by, community_id, event_id, amount, reason
            )
            VALUES (
                v_user_id, v_admin_id, v_community_id, p_event_id, p_credits_per_user, p_reason
            )
            ON CONFLICT (event_id, user_id) WHERE event_id IS NOT NULL DO NOTHING
            RETURNING id INTO v_inserted_id;

            IF v_inserted_id IS NOT NULL THEN
                UPDATE public.profiles
                SET credits = credits + p_credits_per_user
                WHERE id = v_user_id;
                v_granted_count := v_granted_count + 1;
            END IF;

            v_inserted_id := NULL;
        END IF;
    END LOOP;

    INSERT INTO public.admin_action_logs (
        community_id, admin_id, action_type, target_event_id, details
    )
    VALUES (
        v_community_id,
        v_admin_id,
        'grant_credits',
        p_event_id,
        json_build_object(
            'user_count', v_granted_count,
            'credits_per_user', p_credits_per_user,
            'reason', p_reason
        )
    );

    RETURN json_build_object(
        'success', true,
        'message', 'Credits granted',
        'granted_count', v_granted_count
    );
END;
$$;

ALTER FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_communities_by_city(p_city TEXT)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    city TEXT,
    state TEXT,
    description TEXT,
    member_count INTEGER,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_member BOOLEAN,
    membership_status TEXT,
    is_admin BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := public.current_user_id();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

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
              AND m.user_id = v_uid
              AND m.status IN ('member', 'admin')
        ) AS is_member,
        COALESCE(
            (
                SELECT m.status::TEXT
                FROM public.user_community_memberships m
                WHERE m.community_id = c.id
                  AND m.user_id = v_uid
                LIMIT 1
            ),
            (
                SELECT 'pending'::TEXT
                FROM public.community_join_applications a
                WHERE a.community_id = c.id
                  AND a.user_id = v_uid
                  AND a.status = 'pending'
                LIMIT 1
            ),
            'none'
        ) AS membership_status,
        EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = c.id
              AND m.user_id = v_uid
              AND m.status = 'admin'
        ) AS is_admin
    FROM public.communities c
    WHERE c.city = p_city
      AND c.is_active = true
      AND public.can_view_community(c.id, v_uid)
    ORDER BY c.member_count DESC, c.name ASC;
END;
$$;

ALTER FUNCTION public.get_communities_by_city(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_communities_by_city(TEXT) TO authenticated;
