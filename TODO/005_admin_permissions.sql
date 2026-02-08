-- =====================================================
-- 005_admin_permissions.sql
-- 社区管理员权限功能
-- Created: 2026-02-08
-- Version: 1.0
-- =====================================================

-- =====================================================
-- 1. 加入申请表 (Join Applications)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.community_join_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    message TEXT, -- 用户申请时的留言
    rejection_reason TEXT, -- 拒绝理由
    reviewed_by UUID REFERENCES auth.users(id), -- 审批人
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    
    UNIQUE(community_id, user_id) -- 每个用户每个社区只能有一个pending申请
);

CREATE INDEX idx_applications_community ON public.community_join_applications(community_id, status);
CREATE INDEX idx_applications_user ON public.community_join_applications(user_id);
CREATE INDEX idx_applications_status ON public.community_join_applications(status);

COMMENT ON TABLE public.community_join_applications IS '社区加入申请表';

-- =====================================================
-- 2. 社区设置表 (Community Settings)
-- =====================================================

ALTER TABLE public.communities 
ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT false, -- 是否需要审批才能加入
ADD COLUMN IF NOT EXISTS welcome_message TEXT, -- 欢迎消息
ADD COLUMN IF NOT EXISTS rules TEXT, -- 社区规则
ADD COLUMN IF NOT EXISTS tags TEXT[], -- 社区标签
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false; -- 是否私密社区

COMMENT ON COLUMN public.communities.requires_approval IS '是否需要管理员审批才能加入';
COMMENT ON COLUMN public.communities.is_private IS '私密社区不会出现在公开列表中';

-- =====================================================
-- 3. 管理员操作日志表 (Admin Action Logs)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.admin_action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN (
        'approve_member', 'reject_member', 'remove_member', 'grant_credits',
        'edit_community', 'edit_event', 'delete_event', 'pin_post', 'delete_post'
    )),
    target_user_id UUID REFERENCES auth.users(id), -- 操作的目标用户
    target_event_id UUID, -- 操作的目标活动
    details JSONB, -- 操作详情
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX idx_admin_logs_community ON public.admin_action_logs(community_id, created_at DESC);
CREATE INDEX idx_admin_logs_admin ON public.admin_action_logs(admin_id);

COMMENT ON TABLE public.admin_action_logs IS '管理员操作日志，用于审计';

-- =====================================================
-- 4. 积分发放记录表 (Credit Grants)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.credit_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    granted_by UUID NOT NULL REFERENCES auth.users(id), -- 发放者
    community_id TEXT REFERENCES public.communities(id) ON DELETE SET NULL,
    event_id UUID, -- 关联的活动
    amount INTEGER NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

CREATE INDEX idx_credit_grants_user ON public.credit_grants(user_id);
CREATE INDEX idx_credit_grants_community ON public.credit_grants(community_id);
CREATE INDEX idx_credit_grants_event ON public.credit_grants(event_id);

COMMENT ON TABLE public.credit_grants IS '管理员手动发放积分的记录';

-- =====================================================
-- 5. RPC: 检查是否是社区管理员
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

COMMENT ON FUNCTION public.is_community_admin(TEXT, UUID) IS '检查用户是否是社区管理员';

-- =====================================================
-- 6. RPC: 申请加入社区
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

COMMENT ON FUNCTION public.apply_to_join_community IS '申请加入社区（如需审批则创建申请）';

-- =====================================================
-- 7. RPC: 获取待审批的申请
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

COMMENT ON FUNCTION public.get_pending_applications IS '获取社区待审批的加入申请（仅管理员）';

-- =====================================================
-- 8. RPC: 审批申请
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

COMMENT ON FUNCTION public.review_join_application IS '审批社区加入申请（仅管理员）';

-- =====================================================
-- 9. RPC: 更新社区信息
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

COMMENT ON FUNCTION public.update_community_info IS '更新社区信息（仅管理员）';

-- =====================================================
-- 10. RPC: 移除社区成员
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

COMMENT ON FUNCTION public.remove_community_member IS '移除社区成员（仅管理员）';

-- =====================================================
-- 11. RPC: 给活动参与者发放积分
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

COMMENT ON FUNCTION public.grant_event_credits IS '为活动参与者批量发放积分（仅管理员）';

-- =====================================================
-- 12. RPC: 获取社区成员列表（管理员视图）
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

COMMENT ON FUNCTION public.get_community_members_admin IS '获取社区成员列表（管理员视图，含详细信息）';

-- =====================================================
-- 13. RPC: 获取管理员操作日志
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

COMMENT ON FUNCTION public.get_admin_action_logs IS '获取管理员操作日志（仅管理员）';

-- =====================================================
-- 14. GRANT PERMISSIONS
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

-- =====================================================
-- 15. RLS POLICIES
-- =====================================================

-- 申请表：用户只能看自己的申请，管理员可以看所有申请
ALTER TABLE public.community_join_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own applications" ON public.community_join_applications;
CREATE POLICY "Users can view own applications"
ON public.community_join_applications FOR SELECT
USING (
    auth.uid() = user_id OR
    public.is_community_admin(community_id, auth.uid())
);

-- 操作日志：只有管理员可以查看
ALTER TABLE public.admin_action_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view action logs" ON public.admin_action_logs;
CREATE POLICY "Admins can view action logs"
ON public.admin_action_logs FOR SELECT
USING (public.is_community_admin(community_id, auth.uid()));

-- 积分发放记录：用户可以看自己的，管理员可以看社区的
ALTER TABLE public.credit_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own credit grants" ON public.credit_grants;
CREATE POLICY "Users can view own credit grants"
ON public.credit_grants FOR SELECT
USING (
    auth.uid() = user_id OR
    (community_id IS NOT NULL AND public.is_community_admin(community_id, auth.uid()))
);
