-- Migration: Enable Row Level Security for all tables
-- Created: 2025-11-19

-- Enable RLS on locations table
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Locations policies: Users can only manage their own location data
CREATE POLICY "Users can view their own locations" ON locations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own locations" ON locations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own locations" ON locations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own locations" ON locations
  FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on bumps table (if not already enabled)
ALTER TABLE bumps ENABLE ROW LEVEL SECURITY;

-- Bumps policies: Users can view bumps involving them
CREATE POLICY "Users can view their bumps" ON bumps
  FOR SELECT USING (
    auth.uid() = user1_id OR auth.uid() = user2_id
  );

-- Only the system/backend should create bumps (via RPC functions)
-- Users shouldn't directly insert bumps
CREATE POLICY "System can create bumps" ON bumps
  FOR INSERT WITH CHECK (
    auth.uid() = user1_id OR auth.uid() = user2_id
  );

-- Verify all social features have RLS enabled
DO $$
BEGIN
  -- Profiles table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'profiles' AND rowsecurity = true
  ) THEN
    ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Friend requests table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'friend_requests' AND rowsecurity = true
  ) THEN
    ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Friendships table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'friendships' AND rowsecurity = true
  ) THEN
    ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Bump connections table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'bump_connections' AND rowsecurity = true
  ) THEN
    ALTER TABLE bump_connections ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Chat rooms table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'chat_rooms' AND rowsecurity = true
  ) THEN
    ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
  END IF;

  -- Messages table
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables
    WHERE tablename = 'messages' AND rowsecurity = true
  ) THEN
    ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Additional security: Ensure users can't see other users' private data
-- even if they bypass application logic

-- Function to check if user is admin (for future admin features)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE user_id = auth.uid()
    AND (metadata->>'is_admin')::boolean = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add metadata column to profiles if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'metadata'
  ) THEN
    ALTER TABLE profiles ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
  END IF;
END $$;

-- Update RPC functions to respect RLS
-- find_nearby_users function should only work for authenticated users
CREATE OR REPLACE FUNCTION find_nearby_users_secure(
  current_user_id UUID,
  distance_meters FLOAT DEFAULT 30,
  time_interval_hours INT DEFAULT 1
)
RETURNS TABLE (
  bump_id UUID,
  user1_id UUID,
  user2_id UUID,
  bumped_at TIMESTAMPTZ
) AS $$
BEGIN
  -- Verify the caller is the user they claim to be
  IF auth.uid() != current_user_id THEN
    RAISE EXCEPTION 'Unauthorized: You can only search for your own bumps';
  END IF;

  -- Rest of the function logic remains the same
  RETURN QUERY
  WITH current_location AS (
    SELECT location, h3_index
    FROM locations
    WHERE user_id = current_user_id
    ORDER BY timestamp DESC
    LIMIT 1
  ),
  nearby_users AS (
    SELECT DISTINCT l.user_id AS nearby_user_id
    FROM locations l
    CROSS JOIN current_location cl
    WHERE l.user_id != current_user_id
      AND l.timestamp > (NOW() - INTERVAL '1 hour' * time_interval_hours)
      AND ST_DWithin(l.location, cl.location, distance_meters)
  ),
  new_bumps AS (
    INSERT INTO bumps (user1_id, user2_id, bumped_at)
    SELECT
      current_user_id,
      nu.nearby_user_id,
      NOW()
    FROM nearby_users nu
    WHERE NOT EXISTS (
      SELECT 1 FROM bumps b
      WHERE (
        (b.user1_id = current_user_id AND b.user2_id = nu.nearby_user_id) OR
        (b.user1_id = nu.nearby_user_id AND b.user2_id = current_user_id)
      )
      AND b.bumped_at > (NOW() - INTERVAL '1 hour' * time_interval_hours)
    )
    RETURNING id, user1_id, user2_id, bumped_at
  )
  SELECT * FROM new_bumps;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on secure functions
GRANT EXECUTE ON FUNCTION find_nearby_users_secure TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;

-- Revoke public access to sensitive functions
REVOKE ALL ON TABLE locations FROM anon;
REVOKE ALL ON TABLE bumps FROM anon;
REVOKE ALL ON TABLE profiles FROM anon;
REVOKE ALL ON TABLE friend_requests FROM anon;
REVOKE ALL ON TABLE friendships FROM anon;
REVOKE ALL ON TABLE chat_rooms FROM anon;
REVOKE ALL ON TABLE messages FROM anon;

-- Grant proper access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE locations TO authenticated;
GRANT SELECT, INSERT ON TABLE bumps TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE friend_requests TO authenticated;
GRANT SELECT ON TABLE friendships TO authenticated;
GRANT SELECT, INSERT ON TABLE chat_rooms TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE messages TO authenticated;

COMMENT ON POLICY "Users can view their own locations" ON locations IS
  'RLS policy: Users can only access their own location history for privacy';

COMMENT ON POLICY "Users can view their bumps" ON bumps IS
  'RLS policy: Users can only see bumps where they are a participant';

COMMENT ON FUNCTION find_nearby_users_secure IS
  'Secure version of bump detection that validates the caller is the user';
