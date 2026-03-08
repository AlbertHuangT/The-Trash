-- Drop the legacy numeric overload so PostgREST can resolve the RPC unambiguously.
DROP FUNCTION IF EXISTS public.update_user_location(TEXT, TEXT, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION public.update_user_location(
    p_city TEXT,
    p_state TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();

    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.profiles
    SET location_city = p_city,
        location_state = p_state,
        location_latitude = p_latitude,
        location_longitude = p_longitude
    WHERE id = v_user_id;

    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_user_location(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
