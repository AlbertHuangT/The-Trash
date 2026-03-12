-- ============================================================
-- Migration 021: Clean up legacy profile security drift
-- and deprecate old reward RPCs
-- Date: 2026-03-12
--
-- Fixes:
-- 1. Remove legacy profile trigger/function that blocks credits writes
-- 2. Remove stale profile policies left over from old remote schema
-- 3. Keep deprecated reward RPC names callable but always failing loudly
-- ============================================================

DROP TRIGGER IF EXISTS ensure_profile_security ON public.profiles;
DROP FUNCTION IF EXISTS public.protect_sensitive_profile_fields();

DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
DROP POLICY IF EXISTS "Profiles readable (authenticated)" ON public.profiles;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'profiles'
          AND policyname = 'Profiles readable (self)'
    ) THEN
        EXECUTE $policy$
            CREATE POLICY "Profiles readable (self)"
                ON public.profiles FOR SELECT TO authenticated
                USING (id = public.current_user_id())
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'profiles'
          AND policyname = 'Profiles update (self)'
    ) THEN
        EXECUTE $policy$
            CREATE POLICY "Profiles update (self)"
                ON public.profiles FOR UPDATE TO authenticated
                USING (id = public.current_user_id())
                WITH CHECK (id = public.current_user_id())
        $policy$;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.increment_credits(amount INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RAISE EXCEPTION 'Deprecated RPC: use award_verify_reward';
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_total_scans()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RAISE EXCEPTION 'Deprecated RPC: use award_verify_reward';
END;
$$;

ALTER FUNCTION public.increment_credits(INTEGER) OWNER TO postgres;
ALTER FUNCTION public.increment_total_scans() OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.increment_credits(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_credits(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.increment_total_scans() TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_total_scans() TO service_role;

COMMENT ON FUNCTION public.increment_credits(INTEGER)
    IS 'Deprecated. Verify rewards must flow through award_verify_reward.';

COMMENT ON FUNCTION public.increment_total_scans()
    IS 'Deprecated. Verify rewards must flow through award_verify_reward.';
