-- =====================================================
-- Migration: 004_user_created_content.sql
-- Description: Support user-created communities and events with limits
-- Author: Albert Huang
-- Date: 2026-02-06
-- Features:
--   - Users can create up to 3 communities
--   - Users can create up to 7 events per week
--   - Events can be hosted by communities or individuals
-- =====================================================

-- =====================================================
-- 1. ADD CREATOR FIELD TO COMMUNITIES
-- =====================================================

ALTER TABLE public.communities
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Index for counting user's communities
CREATE INDEX IF NOT EXISTS idx_communities_created_by ON public.communities(created_by);

-- =====================================================
-- 2. ADD CREATOR AND INDIVIDUAL HOSTING TO EVENTS
-- =====================================================

-- Make community_id optional (NULL = personal event)
ALTER TABLE public.community_events
ALTER COLUMN community_id DROP NOT NULL;

-- Add creator field
ALTER TABLE public.community_events
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Add is_personal flag
ALTER TABLE public.community_events
ADD COLUMN IF NOT EXISTS is_personal BOOLEAN DEFAULT false;

-- Index for counting user's events
CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.community_events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_is_personal ON public.community_events(is_personal);

-- =====================================================
-- 3. FUNCTION: Check if user can create community (max 3)
-- =====================================================

CREATE OR REPLACE FUNCTION public.can_user_create_community()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

-- =====================================================
-- 4. FUNCTION: Check if user can create event (max 7/week)
-- =====================================================

CREATE OR REPLACE FUNCTION public.can_user_create_event()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

-- =====================================================
-- 5. FUNCTION: Create community
-- =====================================================

CREATE OR REPLACE FUNCTION public.create_community(
    p_id TEXT,
    p_name TEXT,
    p_city TEXT,
    p_state TEXT,
    p_description TEXT DEFAULT NULL,
    p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

-- =====================================================
-- 6. FUNCTION: Create event (community or personal)
-- =====================================================

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
        -- Check if user is member of the community
        IF NOT EXISTS (
            SELECT 1 FROM public.user_community_memberships
            WHERE user_id = v_user_id AND community_id = p_community_id AND status IN ('member', 'admin')
        ) THEN
            RETURN json_build_object('success', false, 'message', 'You must be a member of this community to create events');
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
-- 7. UPDATE get_nearby_events TO INCLUDE PERSONAL EVENTS
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_nearby_events(
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_max_distance_km DECIMAL DEFAULT 50,
    p_category TEXT DEFAULT NULL,
    p_only_joined_communities BOOLEAN DEFAULT false,
    p_sort_by TEXT DEFAULT 'date'
)
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
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
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

-- =====================================================
-- 8. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.can_user_create_community() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_user_create_event() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_community(TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_event(TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, DECIMAL, DECIMAL, INTEGER, TEXT, TEXT) TO authenticated;

-- =====================================================
-- 9. RLS POLICIES FOR NEW FIELDS
-- =====================================================

-- Allow users to see communities they created
CREATE POLICY IF NOT EXISTS "Users can view their created communities"
ON public.communities FOR SELECT
USING (true);

-- Allow users to update their own communities
CREATE POLICY IF NOT EXISTS "Users can update their own communities"
ON public.communities FOR UPDATE
USING (auth.uid() = created_by);

-- Allow authenticated users to create communities
CREATE POLICY IF NOT EXISTS "Authenticated users can create communities"
ON public.communities FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to see all events
CREATE POLICY IF NOT EXISTS "Users can view all events"
ON public.community_events FOR SELECT
USING (true);

-- Allow authenticated users to create events
CREATE POLICY IF NOT EXISTS "Authenticated users can create events"
ON public.community_events FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to update their own events
CREATE POLICY IF NOT EXISTS "Users can update their own events"
ON public.community_events FOR UPDATE
USING (auth.uid() = created_by);
