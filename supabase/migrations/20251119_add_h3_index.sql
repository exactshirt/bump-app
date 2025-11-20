-- Migration: Add H3 index column to locations table
-- Date: 2025-11-19
-- Description: Adds h3_index column and index to enable H3-based spatial partitioning for efficient bump detection

-- 1. Add h3_index column to locations table
ALTER TABLE locations
ADD COLUMN IF NOT EXISTS h3_index BIGINT;

-- 2. Create index on h3_index for fast lookups
CREATE INDEX IF NOT EXISTS idx_locations_h3_index ON locations (h3_index);

-- 3. Update existing locations table index to include timestamp
-- This helps with time-based filtering
CREATE INDEX IF NOT EXISTS idx_locations_user_timestamp ON locations(user_id, timestamp DESC);

-- 4. Add comment to explain the column
COMMENT ON COLUMN locations.h3_index IS 'H3 hexagonal hierarchical spatial index at resolution 12 (~30m cell size)';
