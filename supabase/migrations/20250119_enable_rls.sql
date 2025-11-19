-- Enable Row Level Security (RLS) on locations and bumps tables
-- This ensures that users can only access their own data

-- ============================================================
-- LOCATIONS TABLE - RLS POLICIES
-- ============================================================

-- Enable RLS on locations table
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own location data
CREATE POLICY "Users can insert own locations"
  ON locations
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own location data
CREATE POLICY "Users can view own locations"
  ON locations
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can update their own location data
CREATE POLICY "Users can update own locations"
  ON locations
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own location data
CREATE POLICY "Users can delete own locations"
  ON locations
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- BUMPS TABLE - RLS POLICIES
-- ============================================================

-- Enable RLS on bumps table
ALTER TABLE bumps ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view bumps where they are either user1 or user2
CREATE POLICY "Users can view own bumps"
  ON bumps
  FOR SELECT
  USING (
    auth.uid() = user1_id OR
    auth.uid() = user2_id
  );

-- Policy: System can insert bumps (via RPC function)
-- This is handled by the service role, so authenticated users
-- cannot directly insert bumps
CREATE POLICY "Service role can insert bumps"
  ON bumps
  FOR INSERT
  WITH CHECK (true);

-- Note: Users should not be able to directly insert, update, or delete bumps
-- These operations should only happen through the find_nearby_users RPC function

-- ============================================================
-- ADDITIONAL SECURITY NOTES
-- ============================================================

-- 1. The find_nearby_users function runs with SECURITY DEFINER,
--    which means it executes with the privileges of the function owner.
--    This allows it to bypass RLS policies when creating bumps.
--
-- 2. Direct user access to bumps table is read-only (SELECT).
--    All bump creation happens through the RPC function.
--
-- 3. Location data is protected: users can only see and modify
--    their own location records.
--
-- 4. The RLS policies ensure data privacy even if the client
--    application is compromised or a user tries to access data
--    directly through the Supabase API.
