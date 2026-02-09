-- =====================================================
-- Migration: 20260208100000_optimization_triggers.sql
-- Description: Optimization: Auto-counters via Triggers & Spatial Query Perf
-- Author: Albert Huang
-- Date: 2026-02-08
-- =====================================================

-- =====================================================
-- 1. TRIGGER FUNCTION: Update Community Member Count
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_community_member_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Only count if status is 'member' or 'admin'
        IF NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = member_count + 1, updated_at = NOW()
            WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Only decrement if status was 'member' or 'admin'
        IF OLD.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
            WHERE id = OLD.community_id;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Handle status changes (e.g. pending -> member)
        -- Case 1: Becoming a member
        IF OLD.status NOT IN ('member', 'admin') AND NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = member_count + 1, updated_at = NOW()
            WHERE id = NEW.community_id;
        -- Case 2: No longer a member (e.g. banned/left but kept record?) - usually DELETE is used, but covering bases
        ELSIF OLD.status IN ('member', 'admin') AND NEW.status NOT IN ('member', 'admin') THEN
            UPDATE public.communities
            SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
            WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

-- Trigger for user_community_memberships
DROP TRIGGER IF EXISTS on_community_member_change ON public.user_community_memberships;
CREATE TRIGGER on_community_member_change
AFTER INSERT OR UPDATE OR DELETE ON public.user_community_memberships
FOR EACH ROW EXECUTE FUNCTION public.handle_community_member_count();


-- =====================================================
-- 2. TRIGGER FUNCTION: Update Event Participant Count
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_event_participant_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
         IF NEW.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = participant_count + 1
            WHERE id = NEW.event_id;
         END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
         IF OLD.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = GREATEST(0, participant_count - 1)
            WHERE id = OLD.event_id;
         END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Case 1: Becoming registered
        IF OLD.status != 'registered' AND NEW.status = 'registered' THEN
            UPDATE public.community_events
            SET participant_count = participant_count + 1
            WHERE id = NEW.event_id;
        -- Case 2: No longer registered
        ELSIF OLD.status = 'registered' AND NEW.status != 'registered' THEN
            UPDATE public.community_events
            SET participant_count = GREATEST(0, participant_count - 1)
            WHERE id = NEW.event_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

-- Trigger for event_registrations
DROP TRIGGER IF EXISTS on_event_registration_change ON public.event_registrations;
CREATE TRIGGER on_event_registration_change
AFTER INSERT OR UPDATE OR DELETE ON public.event_registrations
FOR EACH ROW EXECUTE FUNCTION public.handle_event_participant_count();


-- =====================================================
-- 3. OPTIMIZATION: get_nearby_events with Bounding Box
-- =====================================================

-- Redefine get_nearby_events to use a bounding box pre-filter
-- This avoids calculating Haversine distance for points clearly outside the range.
-- 1 deg latitude ~= 111 km. 1 deg longitude varies but is <= 111km.
-- A crude box of +/- (max_dist_km / 111) degrees is a safe superset.

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
    v_lat_range DECIMAL;
    v_lon_range DECIMAL;
BEGIN
    -- Calculate rough bounding box (1 deg approx 111km)
    -- Adding a small buffer (1.1 factor) to be safe
    v_lat_range := (p_max_distance_km / 111.0) * 1.1;
    -- Longitude degrees shrink as we move away from equator, but using 111km is safe as a lower bound for the 'degree width' in denominator,
    -- meaning we might over-select, which is fine for a pre-filter.
    -- To be more precise: v_lon_range := (p_max_distance_km / (111.0 * cos(radians(p_latitude)))) * 1.1;
    -- For simplicity and speed in SQL without complex math in declaration:
    v_lon_range := (p_max_distance_km / 50.0) * 1.1; -- Very generous box to avoid complex cos() logic issues at poles

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
    -- Bounding Box Pre-filter
    AND e.latitude BETWEEN (p_latitude - v_lat_range) AND (p_latitude + v_lat_range)
    AND e.longitude BETWEEN (p_longitude - v_lon_range) AND (p_longitude + v_lon_range)
    -- Primary Filter
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
