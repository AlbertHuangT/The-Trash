-- =====================================================
-- Migration: 007_fix_get_community_events.sql
-- Description: Fix/add function to get events for a specific community
-- Author: Albert Huang
-- Date: 2026-02-06
-- =====================================================

-- First drop the existing function to allow changing return type
DROP FUNCTION IF EXISTS public.get_community_events(TEXT);

-- Function to get events for a specific community
CREATE FUNCTION public.get_community_events(p_community_id TEXT)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    organizer TEXT,
    category TEXT,
    event_date TIMESTAMPTZ,
    location TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    icon_name TEXT,
    max_participants INTEGER,
    participant_count INTEGER,
    community_id TEXT,
    community_name TEXT,
    distance_km DECIMAL,
    is_registered BOOLEAN,
    is_personal BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
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

GRANT EXECUTE ON FUNCTION public.get_community_events(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_events(TEXT) TO anon;
