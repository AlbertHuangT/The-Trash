BEGIN;

CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE(
    user_achievement_id uuid,
    achievement_id uuid,
    name text,
    description text,
    icon_name text,
    community_id text,
    community_name text,
    granted_at timestamptz,
    is_equipped boolean,
    rarity text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_user_id uuid;
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
        COALESCE((p.selected_achievement_id = a.id), false) AS is_equipped,
        COALESCE(a.rarity, 'common') AS rarity
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    LEFT JOIN public.communities c ON c.id = a.community_id
    LEFT JOIN public.profiles p ON p.id = ua.user_id
    WHERE ua.user_id = v_user_id
    ORDER BY ua.granted_at DESC;
END;
$$;

ALTER FUNCTION public.get_my_achievements() OWNER TO postgres;

COMMIT;
