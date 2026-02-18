BEGIN;

-- Fix lint/runtime issue: remove legacy reference to non-existent table
CREATE OR REPLACE FUNCTION public.can_view_community_roster(p_community_id text, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    IF p_community_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_community_memberships m
        WHERE m.community_id = p_community_id
          AND m.user_id = p_user_id
          AND m.status IN ('member', 'admin')
    );
END;
$$;

-- Harden SECURITY DEFINER search_path
ALTER FUNCTION public.complete_arena_challenge(uuid)
    SET search_path = public, pg_temp;

-- Fix achievement grant logic and harden search_path
CREATE OR REPLACE FUNCTION public.check_and_grant_achievement(p_trigger_key text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
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

    SELECT * INTO v_achievement
    FROM public.achievements
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
            v_qualifies := EXISTS (
                SELECT 1
                FROM public.arena_challenges ac
                WHERE ac.status = 'completed'
                  AND ac.winner_id = v_user_id
            );
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
    VALUES (v_user_id, v_achievement.id)
    ON CONFLICT (user_id, achievement_id) DO NOTHING;

    IF NOT FOUND THEN
        RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END IF;

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

-- Remove duplicate counter updates from membership join flow
CREATE OR REPLACE FUNCTION public.apply_to_join_community(p_community_id text, p_message text DEFAULT NULL::text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_requires_approval BOOLEAN;
    v_membership_status TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT requires_approval INTO v_requires_approval
    FROM public.communities
    WHERE id = p_community_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Community not found');
    END IF;

    SELECT status INTO v_membership_status
    FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id;

    IF FOUND THEN
        IF v_membership_status IN ('member', 'admin') THEN
            RETURN json_build_object('success', false, 'message', 'Already a member');
        ELSIF v_membership_status = 'banned' THEN
            RETURN json_build_object('success', false, 'message', 'You are banned from this community');
        ELSE
            RETURN json_build_object('success', false, 'message', 'Application already pending');
        END IF;
    END IF;

    IF NOT v_requires_approval THEN
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member')
        ON CONFLICT (user_id, community_id) DO UPDATE
        SET status = 'member', joined_at = NOW();

        RETURN json_build_object(
            'success', true,
            'message', 'Joined successfully',
            'requires_approval', false
        );
    END IF;

    INSERT INTO public.community_join_applications (community_id, user_id, message)
    VALUES (p_community_id, v_user_id, p_message)
    ON CONFLICT (community_id, user_id)
    DO UPDATE SET
        status = 'pending',
        message = EXCLUDED.message,
        rejection_reason = NULL,
        reviewed_by = NULL,
        reviewed_at = NULL,
        updated_at = NOW();

    RETURN json_build_object(
        'success', true,
        'message', 'Application submitted',
        'requires_approval', true
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_community(
    p_id text,
    p_name text,
    p_city text,
    p_state text,
    p_description text DEFAULT NULL::text,
    p_latitude numeric DEFAULT NULL::numeric,
    p_longitude numeric DEFAULT NULL::numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_can_create json;
    v_community_id TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    v_can_create := public.can_user_create_community();
    IF NOT (v_can_create->>'allowed')::boolean THEN
        RETURN json_build_object('success', false, 'message', v_can_create->>'reason');
    END IF;

    IF EXISTS (SELECT 1 FROM public.communities WHERE id = p_id) THEN
        RETURN json_build_object('success', false, 'message', 'Community ID already exists');
    END IF;

    INSERT INTO public.communities (
        id, name, city, state, description, latitude, longitude, created_by, member_count
    )
    VALUES (
        p_id, p_name, p_city, p_state, p_description, p_latitude, p_longitude, v_user_id, 0
    )
    RETURNING id INTO v_community_id;

    INSERT INTO public.user_community_memberships (user_id, community_id, status)
    VALUES (v_user_id, v_community_id, 'admin')
    ON CONFLICT (user_id, community_id) DO UPDATE
    SET status = 'admin', joined_at = NOW();

    RETURN json_build_object('success', true, 'message', 'Community created', 'community_id', v_community_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.join_community(p_community_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.communities WHERE id = p_community_id AND is_active = true
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Community not found');
    END IF;

    SELECT * INTO v_existing
    FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id;

    IF FOUND THEN
        IF v_existing.status IN ('member', 'admin') THEN
            RETURN json_build_object('success', false, 'message', 'Already a member');
        ELSIF v_existing.status = 'banned' THEN
            RETURN json_build_object('success', false, 'message', 'You are banned from this community');
        ELSE
            UPDATE public.user_community_memberships
            SET status = 'member', joined_at = NOW()
            WHERE id = v_existing.id;
        END IF;
    ELSE
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member');
    END IF;

    RETURN json_build_object('success', true, 'message', 'Joined community successfully');
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_community(p_community_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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

    RETURN json_build_object('success', true, 'message', 'Left community successfully');
END;
$$;

CREATE OR REPLACE FUNCTION public.review_join_application(
    p_application_id uuid,
    p_approve boolean,
    p_rejection_reason text DEFAULT NULL::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_community_id TEXT;
    v_user_id UUID;
    v_username TEXT;
BEGIN
    SELECT community_id, user_id INTO v_community_id, v_user_id
    FROM public.community_join_applications
    WHERE id = p_application_id AND status = 'pending';

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;

    IF NOT public.is_community_admin(v_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;

    SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;

    IF p_approve THEN
        UPDATE public.community_join_applications
        SET status = 'approved',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = p_application_id;

        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, v_community_id, 'member')
        ON CONFLICT (user_id, community_id) DO UPDATE
        SET status = 'member', joined_at = NOW();

        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (
            v_community_id,
            v_admin_id,
            'approve_member',
            v_user_id,
            json_build_object('username', v_username)
        );

        RETURN json_build_object('success', true, 'message', 'Application approved');
    ELSE
        UPDATE public.community_join_applications
        SET status = 'rejected',
            reviewed_by = v_admin_id,
            reviewed_at = NOW(),
            rejection_reason = p_rejection_reason,
            updated_at = NOW()
        WHERE id = p_application_id;

        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (
            v_community_id,
            v_admin_id,
            'reject_member',
            v_user_id,
            json_build_object('username', v_username, 'reason', p_rejection_reason)
        );

        RETURN json_build_object('success', true, 'message', 'Application rejected');
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_community_member(
    p_community_id text,
    p_user_id uuid,
    p_reason text DEFAULT NULL::text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_username TEXT;
BEGIN
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;

    IF public.is_community_admin(p_community_id, p_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Cannot remove admin');
    END IF;

    SELECT username INTO v_username FROM public.profiles WHERE id = p_user_id;

    DELETE FROM public.user_community_memberships
    WHERE community_id = p_community_id AND user_id = p_user_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'User is not a member');
    END IF;

    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
    VALUES (
        p_community_id,
        v_admin_id,
        'remove_member',
        p_user_id,
        json_build_object('username', v_username, 'reason', p_reason)
    );

    RETURN json_build_object('success', true, 'message', 'Member removed');
END;
$$;

CREATE OR REPLACE FUNCTION public.register_for_event(p_event_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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

    RETURN json_build_object('success', true, 'message', 'Registration successful');
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_event_registration(p_event_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
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

    RETURN json_build_object('success', true, 'message', 'Registration cancelled');
END;
$$;

-- Remove broad read policies that leak data
DROP POLICY IF EXISTS "Enable read access for all users" ON public.feedback_logs;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;

CREATE POLICY "Profiles readable (authenticated)"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Remove direct-write policies for sensitive tables
DROP POLICY IF EXISTS "Membership self-management" ON public.user_community_memberships;
DROP POLICY IF EXISTS "Registrations self-management" ON public.event_registrations;
DROP POLICY IF EXISTS "User achievements grant" ON public.user_achievements;

CREATE POLICY "User achievements grant (admins only)"
ON public.user_achievements
FOR INSERT
TO authenticated
WITH CHECK (
    community_id IS NOT NULL
    AND public.is_community_admin(community_id, public.current_user_id())
    AND EXISTS (
        SELECT 1
        FROM public.achievements a
        WHERE a.id = user_achievements.achievement_id
          AND a.community_id = user_achievements.community_id
    )
);

-- Revoke direct DML access; force client writes through vetted RPCs
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_community_memberships FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.event_registrations FROM anon, authenticated;
REVOKE INSERT ON TABLE public.user_achievements FROM anon;
REVOKE UPDATE, DELETE ON TABLE public.user_achievements FROM anon, authenticated;

-- Reduce anonymous surface for mutating RPCs
REVOKE EXECUTE ON FUNCTION public.apply_to_join_community(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.cancel_event_registration(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_and_grant_achievement(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.complete_arena_challenge(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_community(text, text, text, text, text, numeric, numeric) FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_event(text, text, text, timestamptz, text, numeric, numeric, integer, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.grant_event_credits(uuid, uuid[], integer, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.increment_credits(integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.increment_total_scans() FROM anon;
REVOKE EXECUTE ON FUNCTION public.join_community(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.leave_community(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.register_for_event(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.remove_community_member(text, uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.review_join_application(uuid, boolean, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.submit_daily_challenge(integer, integer, numeric, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.submit_duel_answer(uuid, integer, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.submit_streak_record(integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_community_info(text, text, text, text, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_user_location(text, text, numeric, numeric) FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_user_location(text, text, double precision, double precision) FROM anon;

-- Harden default privilege baseline for future objects
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM authenticated;

-- Reconcile denormalized counters after fixing double-update logic
UPDATE public.communities c
SET member_count = COALESCE(m.member_count, 0),
    updated_at = NOW()
FROM (
    SELECT community_id, COUNT(*)::int AS member_count
    FROM public.user_community_memberships
    WHERE status IN ('member', 'admin')
    GROUP BY community_id
) m
WHERE c.id = m.community_id;

UPDATE public.communities c
SET member_count = 0,
    updated_at = NOW()
WHERE NOT EXISTS (
    SELECT 1
    FROM public.user_community_memberships m
    WHERE m.community_id = c.id
      AND m.status IN ('member', 'admin')
);

UPDATE public.community_events e
SET participant_count = COALESCE(r.participant_count, 0),
    updated_at = NOW()
FROM (
    SELECT event_id, COUNT(*)::int AS participant_count
    FROM public.event_registrations
    WHERE status = 'registered'
    GROUP BY event_id
) r
WHERE e.id = r.event_id;

UPDATE public.community_events e
SET participant_count = 0,
    updated_at = NOW()
WHERE NOT EXISTS (
    SELECT 1
    FROM public.event_registrations r
    WHERE r.event_id = e.id
      AND r.status = 'registered'
);

COMMIT;
