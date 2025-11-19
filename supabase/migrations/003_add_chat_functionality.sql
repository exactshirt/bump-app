-- Migration: Add chat functionality
-- Created: 2025-11-19

-- Create chat_rooms table
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_message_at TIMESTAMPTZ,
  UNIQUE(user1_id, user2_id),
  CHECK (user1_id != user2_id),
  CHECK (user1_id < user2_id) -- Ensure unique pair regardless of order
);

CREATE INDEX idx_chat_rooms_user1 ON chat_rooms(user1_id, last_message_at DESC);
CREATE INDEX idx_chat_rooms_user2 ON chat_rooms(user2_id, last_message_at DESC);
CREATE INDEX idx_chat_rooms_last_message ON chat_rooms(last_message_at DESC);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  message_type VARCHAR(20) NOT NULL DEFAULT 'text', -- text, image, location
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_chat_room ON messages(chat_room_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_unread ON messages(chat_room_id, is_read) WHERE is_read = false;

-- Function to update last_message_at when a new message is sent
CREATE OR REPLACE FUNCTION update_chat_room_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_rooms
  SET last_message_at = NEW.created_at
  WHERE id = NEW.chat_room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_last_message
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION update_chat_room_last_message();

-- Function to get or create chat room between two users
CREATE OR REPLACE FUNCTION get_or_create_chat_room(
  user1_id UUID,
  user2_id UUID
)
RETURNS UUID AS $$
DECLARE
  room_id UUID;
  normalized_user1_id UUID;
  normalized_user2_id UUID;
BEGIN
  -- Normalize user IDs (smaller ID first)
  IF user1_id < user2_id THEN
    normalized_user1_id := user1_id;
    normalized_user2_id := user2_id;
  ELSE
    normalized_user1_id := user2_id;
    normalized_user2_id := user1_id;
  END IF;

  -- Try to find existing room
  SELECT id INTO room_id
  FROM chat_rooms
  WHERE chat_rooms.user1_id = normalized_user1_id
    AND chat_rooms.user2_id = normalized_user2_id;

  -- If not found, create new room
  IF room_id IS NULL THEN
    INSERT INTO chat_rooms (user1_id, user2_id)
    VALUES (normalized_user1_id, normalized_user2_id)
    RETURNING id INTO room_id;
  END IF;

  RETURN room_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get unread message count for a user
CREATE OR REPLACE FUNCTION get_unread_message_count(
  for_user_id UUID,
  in_chat_room_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  count INTEGER;
BEGIN
  IF in_chat_room_id IS NOT NULL THEN
    -- Count unread messages in specific chat room
    SELECT COUNT(*) INTO count
    FROM messages
    WHERE chat_room_id = in_chat_room_id
      AND sender_id != for_user_id
      AND is_read = false;
  ELSE
    -- Count all unread messages for user
    SELECT COUNT(*) INTO count
    FROM messages m
    JOIN chat_rooms cr ON m.chat_room_id = cr.id
    WHERE (cr.user1_id = for_user_id OR cr.user2_id = for_user_id)
      AND m.sender_id != for_user_id
      AND m.is_read = false;
  END IF;

  RETURN COALESCE(count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_as_read(
  in_chat_room_id UUID,
  for_user_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  WITH updated AS (
    UPDATE messages
    SET is_read = true
    WHERE chat_room_id = in_chat_room_id
      AND sender_id != for_user_id
      AND is_read = false
    RETURNING id
  )
  SELECT COUNT(*) INTO updated_count FROM updated;

  RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security (RLS) Policies
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Chat Rooms: Users can only see rooms they're part of
CREATE POLICY "Users can view their chat rooms" ON chat_rooms
  FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users can create chat rooms" ON chat_rooms
  FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Messages: Users can see messages in their chat rooms
CREATE POLICY "Users can view messages in their chat rooms" ON messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = messages.chat_room_id
        AND (chat_rooms.user1_id = auth.uid() OR chat_rooms.user2_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their chat rooms" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = messages.chat_room_id
        AND (chat_rooms.user1_id = auth.uid() OR chat_rooms.user2_id = auth.uid())
    )
  );

CREATE POLICY "Users can update their own messages" ON messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE chat_rooms.id = messages.chat_room_id
        AND (chat_rooms.user1_id = auth.uid() OR chat_rooms.user2_id = auth.uid())
    )
  );

-- Enable Realtime for messages table
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;
