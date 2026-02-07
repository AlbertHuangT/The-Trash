-- =====================================================
-- Migration: 005_admin_only_community_events.sql
-- Description: Only community admins can create community events
-- Author: Albert Huang
-- Date: 2026-02-06
-- =====================================================

-- Update create_event function to require admin status for community events
CREATE OR REPLACE FUNCTION public.create_event(
    p_title TEXT,
    p_description TEXT,
    p_category TEXT,
    p_event_date TIMESTAMPTZ,
    p_location TEXT,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_max_participants INTEGER DEFAULT 50,
    p_community_id TEXT DEFAULT NULL,  -- NULL for personal event
    p_icon_name TEXT DEFAULT 'calendar'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

-- =====================================================
-- Update get_my_communities to include membership status
-- =====================================================

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
