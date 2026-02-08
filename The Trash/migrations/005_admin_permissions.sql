-- =====================================================
-- 005_admin_permissions.sql
-- Community admin permissions: applications, member management,
-- credit grants, audit logs
-- =====================================================

-- =====================================================
-- 1. Join Applications Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.community_join_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    message TEXT,
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),

    UNIQUE(community_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_applications_community ON public.community_join_applications(community_id, status);
CREATE INDEX IF NOT EXISTS idx_applications_user ON public.community_join_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON public.community_join_applications(status);

-- =====================================================
-- 2. Community Settings Columns
-- =====================================================

ALTER TABLE public.communities
ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS welcome_message TEXT,
ADD COLUMN IF NOT EXISTS rules TEXT,
ADD COLUMN IF NOT EXISTS tags TEXT[],
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false;

-- =====================================================
-- 3. Admin Action Logs Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.admin_action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN (
        'approve_member', 'reject_member', 'remove_member', 'grant_credits',
        'edit_community', 'edit_event', 'delete_event', 'pin_post', 'delete_post'
    )),
    target_user_id UUID REFERENCES auth.users(id),
    target_event_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_community ON public.admin_action_logs(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin ON public.admin_action_logs(admin_id);

-- =====================================================
-- 4. Credit Grants Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.credit_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    granted_by UUID NOT NULL REFERENCES auth.users(id),
    community_id TEXT REFERENCES public.communities(id) ON DELETE SET NULL,
    event_id UUID,
    amount INTEGER NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_credit_grants_user ON public.credit_grants(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_grants_community ON public.credit_grants(community_id);
CREATE INDEX IF NOT EXISTS idx_credit_grants_event ON public.credit_grants(event_id);

-- =====================================================
-- 5. RPC: Check if user is community admin
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_community_admin(
    p_community_id TEXT,
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
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

-- =====================================================
-- 6. RPC: Apply to join community (with approval support)
-- =====================================================

CREATE OR REPLACE FUNCTION public.apply_to_join_community(
    p_community_id TEXT,
    p_message TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_requires_approval BOOLEAN;
    v_community_name TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated', 'requires_approval', false);
    END IF;

    SELECT requires_approval, name INTO v_requires_approval, v_community_name
    FROM public.communities
    WHERE id = p_community_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Community not found', 'requires_approval', false);
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE user_id = v_user_id AND community_id = p_community_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Already a member', 'requires_approval', false);
    END IF;

    -- If no approval needed, join directly
    IF NOT COALESCE(v_requires_approval, false) THEN
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

    -- Approval required: create application
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

-- =====================================================
-- 7. RPC: Get pending applications (admin only)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_pending_applications(
    p_community_id TEXT
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username TEXT,
    user_credits INTEGER,
    message TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
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

-- =====================================================
-- 8. RPC: Review join application (admin only)
-- =====================================================

CREATE OR REPLACE FUNCTION public.review_join_application(
    p_application_id UUID,
    p_approve BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
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
        SET status = 'approved', reviewed_by = v_admin_id, reviewed_at = NOW(), updated_at = NOW()
        WHERE id = p_application_id;

        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, v_community_id, 'member')
        ON CONFLICT (user_id, community_id) DO NOTHING;

        UPDATE public.communities
        SET member_count = member_count + 1, updated_at = NOW()
        WHERE id = v_community_id;

        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'approve_member', v_user_id,
                json_build_object('username', v_username));

        RETURN json_build_object('success', true, 'message', 'Application approved');
    ELSE
        UPDATE public.community_join_applications
        SET status = 'rejected', reviewed_by = v_admin_id, reviewed_at = NOW(),
            rejection_reason = p_rejection_reason, updated_at = NOW()
        WHERE id = p_application_id;

        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'reject_member', v_user_id,
                json_build_object('username', v_username, 'reason', p_rejection_reason));

        RETURN json_build_object('success', true, 'message', 'Application rejected');
    END IF;
END;
$$;

-- =====================================================
-- 9. RPC: Update community info (admin only)
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_community_info(
    p_community_id TEXT,
    p_description TEXT DEFAULT NULL,
    p_welcome_message TEXT DEFAULT NULL,
    p_rules TEXT DEFAULT NULL,
    p_requires_approval BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;

    UPDATE public.communities
    SET
        description = COALESCE(p_description, description),
        welcome_message = COALESCE(p_welcome_message, welcome_message),
        rules = COALESCE(p_rules, rules),
        requires_approval = COALESCE(p_requires_approval, requires_approval),
        updated_at = NOW()
    WHERE id = p_community_id;

    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, details)
    VALUES (p_community_id, v_admin_id, 'edit_community',
            json_build_object('description', p_description, 'welcome_message', p_welcome_message, 'requires_approval', p_requires_approval));

    RETURN json_build_object('success', true, 'message', 'Community updated');
END;
$$;

-- =====================================================
-- 10. RPC: Remove community member (admin only)
-- =====================================================

CREATE OR REPLACE FUNCTION public.remove_community_member(
    p_community_id TEXT,
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
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

    UPDATE public.communities
    SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
    WHERE id = p_community_id;

    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
    VALUES (p_community_id, v_admin_id, 'remove_member', p_user_id,
            json_build_object('username', v_username, 'reason', p_reason));

    RETURN json_build_object('success', true, 'message', 'Member removed');
END;
$$;

-- =====================================================
-- 11. RPC: Grant event credits (admin only)
-- =====================================================

CREATE OR REPLACE FUNCTION public.grant_event_credits(
    p_event_id UUID,
    p_user_ids UUID[],
    p_credits_per_user INTEGER,
    p_reason TEXT
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_community_id TEXT;
    v_user_id UUID;
    v_granted_count INTEGER := 0;
BEGIN
    SELECT community_id INTO v_community_id
    FROM public.community_events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found', 'granted_count', 0);
    END IF;

    IF NOT (
        public.is_community_admin(v_community_id, v_admin_id) OR
        EXISTS (SELECT 1 FROM public.community_events WHERE id = p_event_id AND created_by = v_admin_id)
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied', 'granted_count', 0);
    END IF;

    IF p_credits_per_user <= 0 OR p_credits_per_user > 1000 THEN
        RETURN json_build_object('success', false, 'message', 'Invalid credit amount (must be 1-1000)', 'granted_count', 0);
    END IF;

    FOREACH v_user_id IN ARRAY p_user_ids LOOP
        IF EXISTS (
            SELECT 1 FROM public.event_registrations
            WHERE event_id = p_event_id AND user_id = v_user_id
        ) THEN
            UPDATE public.profiles
            SET credits = credits + p_credits_per_user
            WHERE id = v_user_id;

            INSERT INTO public.credit_grants (user_id, granted_by, community_id, event_id, amount, reason)
            VALUES (v_user_id, v_admin_id, v_community_id, p_event_id, p_credits_per_user, p_reason);

            v_granted_count := v_granted_count + 1;
        END IF;
    END LOOP;

    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_event_id, details)
    VALUES (v_community_id, v_admin_id, 'grant_credits', p_event_id,
            json_build_object('user_count', v_granted_count, 'credits_per_user', p_credits_per_user,
                'total_credits', v_granted_count * p_credits_per_user, 'reason', p_reason));

    RETURN json_build_object('success', true, 'message', format('Credits granted to %s users', v_granted_count), 'granted_count', v_granted_count);
END;
$$;

-- =====================================================
-- 12. RPC: Get community members (admin view)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_community_members_admin(
    p_community_id TEXT
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    credits INTEGER,
    status TEXT,
    joined_at TIMESTAMPTZ,
    is_admin BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
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

-- =====================================================
-- 13. RPC: Get admin action logs
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_admin_action_logs(
    p_community_id TEXT,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    admin_username TEXT,
    action_type TEXT,
    target_username TEXT,
    details JSONB,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
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

-- =====================================================
-- 14. RPC: Get event participants
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_event_participants(p_event_id UUID)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    credits INTEGER,
    registered_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
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

-- =====================================================
-- 15. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.is_community_admin(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_to_join_community(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_applications(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_join_application(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_community_info(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_community_member(TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_members_admin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_action_logs(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_event_participants(UUID) TO authenticated;

-- =====================================================
-- 16. RLS POLICIES
-- =====================================================

ALTER TABLE public.community_join_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own applications" ON public.community_join_applications;
CREATE POLICY "Users can view own applications"
ON public.community_join_applications FOR SELECT
USING (
    auth.uid() = user_id OR
    public.is_community_admin(community_id, auth.uid())
);

ALTER TABLE public.admin_action_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view action logs" ON public.admin_action_logs;
CREATE POLICY "Admins can view action logs"
ON public.admin_action_logs FOR SELECT
USING (public.is_community_admin(community_id, auth.uid()));

ALTER TABLE public.credit_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own credit grants" ON public.credit_grants;
CREATE POLICY "Users can view own credit grants"
ON public.credit_grants FOR SELECT
USING (
    auth.uid() = user_id OR
    (community_id IS NOT NULL AND public.is_community_admin(community_id, auth.uid()))
);
