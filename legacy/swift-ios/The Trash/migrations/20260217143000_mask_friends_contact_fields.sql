BEGIN;

CREATE OR REPLACE FUNCTION public.find_friends_leaderboard(
    p_emails text[] DEFAULT ARRAY[]::text[],
    p_phones text[] DEFAULT ARRAY[]::text[]
)
RETURNS TABLE(id uuid, username text, credits integer, email text, phone text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
BEGIN
    RETURN QUERY
    WITH normalized_emails AS (
        SELECT DISTINCT lower(trim(e)) AS email
        FROM unnest(COALESCE(p_emails, ARRAY[]::text[])) AS e
        WHERE trim(e) <> ''
    ),
    normalized_phones AS (
        SELECT DISTINCT public.normalize_phone_number(raw_phone) AS phone
        FROM unnest(COALESCE(p_phones, ARRAY[]::text[])) AS raw_phone
        WHERE public.normalize_phone_number(raw_phone) IS NOT NULL
    ),
    profiles_with_auth AS (
        SELECT
            p.id,
            COALESCE(p.username, 'Anonymous')::text AS username,
            COALESCE(p.credits, 0) AS credits,
            u.email::text AS raw_email,
            u.phone::text AS raw_phone,
            public.normalize_phone_number(u.phone) AS normalized_phone,
            regexp_replace(
                COALESCE(public.normalize_phone_number(u.phone), ''),
                '[^0-9]',
                '',
                'g'
            ) AS normalized_phone_digits
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT
        pa.id,
        pa.username,
        pa.credits,
        CASE
            WHEN pa.raw_email IS NULL OR btrim(pa.raw_email) = '' THEN NULL
            ELSE regexp_replace(lower(pa.raw_email), '(^.).*(@.*$)', '\1***\2')
        END AS email,
        CASE
            WHEN pa.raw_phone IS NULL OR btrim(pa.raw_phone) = '' THEN NULL
            WHEN pa.normalized_phone_digits IS NULL OR pa.normalized_phone_digits = '' THEN '+***'
            WHEN length(pa.normalized_phone_digits) < 4 THEN '+***'
            ELSE '+***' || right(pa.normalized_phone_digits, 4)
        END AS phone
    FROM profiles_with_auth pa
    WHERE (
        EXISTS (
            SELECT 1
            FROM normalized_emails ne
            WHERE ne.email = lower(pa.raw_email)
        )
        OR (
            pa.normalized_phone IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM normalized_phones np
                WHERE np.phone = pa.normalized_phone
            )
        )
    );
END;
$$;

ALTER FUNCTION public.find_friends_leaderboard(text[], text[]) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.find_friends_leaderboard(text[], text[]) FROM anon;

COMMIT;
