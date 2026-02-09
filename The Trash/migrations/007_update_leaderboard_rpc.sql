-- 007_update_leaderboard_rpc.sql
-- Update get_community_leaderboard to include achievement icon

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INT,
    community_name TEXT,
    achievement_icon TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        COALESCE(u.username, 'Anonymous'),
        COALESCE(u.credits, 0),
        c.name,
        a.icon_name
    FROM public.community_members cm
    JOIN public.users u ON cm.user_id = u.id
    JOIN public.communities c ON cm.community_id = c.id
    LEFT JOIN public.achievements a ON u.selected_achievement_id = a.id
    WHERE cm.community_id = p_community_id
    AND cm.status IN ('member', 'admin')
    ORDER BY u.credits DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
