-- Drop the previous policy that was restricted only to 'anon'
DROP POLICY IF EXISTS "Allow anonymous inserts" ON public.waitlist;

-- Create a new policy that applies to 'public' (both anon and authenticated users)
CREATE POLICY "Allow public inserts" ON public.waitlist
  FOR INSERT TO public
  WITH CHECK (true);

-- Explicitly grant table-level INSERT permission to anon and authenticated roles
-- (Sometimes Supabase doesn't auto-grant this when tables are created via raw SQL)
GRANT INSERT ON TABLE public.waitlist TO anon, authenticated;

-- Ensure the RPC function is executable by clients
GRANT EXECUTE ON FUNCTION public.get_waitlist_count() TO anon, authenticated;
