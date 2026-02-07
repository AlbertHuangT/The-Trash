-- =====================================================
-- Migration: 006_update_get_my_communities.sql
-- Description: Add status field to get_my_communities response
-- Author: Albert Huang
-- Date: 2026-02-06
-- =====================================================

-- Drop and recreate get_my_communities to include membership status
DROP FUNCTION IF EXISTS public.get_my_communities();

CREATE OR REPLACE FUNCTION public.get_my_communities()
RETURNS TABLE (
    id TEXT,
    name TEXT,
    city TEXT,
    state TEXT,
    description TEXT,
    member_count INTEGER,
    joined_at TIMESTAMPTZ,
    status TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
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

GRANT EXECUTE ON FUNCTION public.get_my_communities() TO authenticated;
