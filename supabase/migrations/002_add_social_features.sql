-- Migration: Add social features (profiles, friend requests)
-- Created: 2025-11-19

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name VARCHAR(100) NOT NULL,
  bio TEXT,
  avatar_url TEXT,
  interests TEXT[], -- Array of interest tags
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_profiles_display_name ON profiles(display_name);

-- Create friend_requests table
CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(sender_id, receiver_id),
  CHECK (sender_id != receiver_id)
);

CREATE INDEX idx_friend_requests_sender ON friend_requests(sender_id, status);
CREATE INDEX idx_friend_requests_receiver ON friend_requests(receiver_id, status);

-- Create friendships table (accepted friend requests become friendships)
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user1_id, user2_id),
  CHECK (user1_id != user2_id),
  CHECK (user1_id < user2_id) -- Ensure unique pair regardless of order
);

CREATE INDEX idx_friendships_user1 ON friendships(user1_id);
CREATE INDEX idx_friendships_user2 ON friendships(user2_id);

-- Create bump_connections table (bumps that led to connections)
CREATE TABLE IF NOT EXISTS bump_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bump_id UUID NOT NULL REFERENCES bumps(id) ON DELETE CASCADE,
  user1_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  connection_status VARCHAR(20) NOT NULL DEFAULT 'viewed', -- viewed, liked, connected
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bump_connections_bump ON bump_connections(bump_id);
CREATE INDEX idx_bump_connections_users ON bump_connections(user1_id, user2_id);

-- Function to automatically create friendship when friend request is accepted
CREATE OR REPLACE FUNCTION create_friendship_on_accept()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    -- Ensure user1_id < user2_id for consistency
    INSERT INTO friendships (user1_id, user2_id)
    VALUES (
      LEAST(NEW.sender_id, NEW.receiver_id),
      GREATEST(NEW.sender_id, NEW.receiver_id)
    )
    ON CONFLICT (user1_id, user2_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_friendship
AFTER UPDATE ON friend_requests
FOR EACH ROW
EXECUTE FUNCTION create_friendship_on_accept();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_friend_requests_updated_at
BEFORE UPDATE ON friend_requests
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_bump_connections_updated_at
BEFORE UPDATE ON bump_connections
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) Policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE bump_connections ENABLE ROW LEVEL SECURITY;

-- Profiles: Everyone can read, users can only update their own
CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Friend Requests: Users can see requests they sent or received
CREATE POLICY "Users can view their friend requests" ON friend_requests
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send friend requests" ON friend_requests
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update received friend requests" ON friend_requests
  FOR UPDATE USING (auth.uid() = receiver_id);

-- Friendships: Users can see friendships they're part of
CREATE POLICY "Users can view their friendships" ON friendships
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Bump Connections: Users can see and manage connections involving them
CREATE POLICY "Users can view their bump connections" ON bump_connections
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users can create bump connections" ON bump_connections
  FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users can update their bump connections" ON bump_connections
  FOR UPDATE USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Function to get mutual friends count
CREATE OR REPLACE FUNCTION get_mutual_friends_count(
  current_user_id UUID,
  other_user_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT f2.user2_id) INTO count
  FROM friendships f1
  JOIN friendships f2 ON (
    (f1.user2_id = f2.user1_id AND f1.user1_id = current_user_id) OR
    (f1.user1_id = f2.user1_id AND f1.user2_id = current_user_id)
  )
  WHERE (f2.user1_id = other_user_id OR f2.user2_id = other_user_id)
    AND f2.user1_id != current_user_id
    AND f2.user2_id != current_user_id;

  RETURN COALESCE(count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to get friend suggestions based on bumps and mutual friends
CREATE OR REPLACE FUNCTION get_friend_suggestions(
  current_user_id UUID,
  limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  display_name VARCHAR,
  bio TEXT,
  avatar_url TEXT,
  bump_count INTEGER,
  mutual_friends_count INTEGER,
  interests TEXT[]
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.user_id,
    p.display_name,
    p.bio,
    p.avatar_url,
    COUNT(DISTINCT b.id)::INTEGER AS bump_count,
    get_mutual_friends_count(current_user_id, p.user_id) AS mutual_friends_count,
    p.interests
  FROM profiles p
  LEFT JOIN bumps b ON (
    (b.user1_id = current_user_id AND b.user2_id = p.user_id) OR
    (b.user2_id = current_user_id AND b.user1_id = p.user_id)
  )
  WHERE p.user_id != current_user_id
    AND p.user_id NOT IN (
      -- Exclude existing friends
      SELECT user2_id FROM friendships WHERE user1_id = current_user_id
      UNION
      SELECT user1_id FROM friendships WHERE user2_id = current_user_id
    )
    AND p.user_id NOT IN (
      -- Exclude pending friend requests
      SELECT receiver_id FROM friend_requests
      WHERE sender_id = current_user_id AND status = 'pending'
    )
  GROUP BY p.user_id, p.display_name, p.bio, p.avatar_url, p.interests
  ORDER BY bump_count DESC, mutual_friends_count DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;
