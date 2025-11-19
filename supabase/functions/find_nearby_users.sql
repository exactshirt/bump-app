-- Supabase RPC 함수: find_nearby_users
--
-- 이 함수는 현재 사용자와 가까운 거리에 있는 다른 사용자를 찾아 Bump를 생성합니다.
--
-- 매개변수:
--   - current_user_id: 현재 사용자의 ID (UUID)
--   - distance_meters: 검색할 거리 (미터 단위, 예: 30)
--   - time_interval_hours: 중복 Bump를 방지하기 위한 시간 간격 (시간 단위, 예: 1)

CREATE OR REPLACE FUNCTION find_nearby_users(
    current_user_id UUID,
    distance_meters FLOAT,
    time_interval_hours INT
)
RETURNS TABLE (bump_id UUID, user1_id UUID, user2_id UUID, bumped_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_location GEOMETRY;
BEGIN
    -- 1. 현재 사용자의 최신 위치를 가져옵니다.
    SELECT location INTO current_user_location
    FROM locations
    WHERE user_id = current_user_id
    ORDER BY timestamp DESC
    LIMIT 1;

    -- 2. 가까운 거리에 있는 다른 사용자들을 찾습니다.
    --    - ST_DWithin 함수를 사용하여 30m 이내의 사용자를 찾습니다.
    --    - 최근 1시간 이내에 동일한 사용자와의 Bump가 있었는지 확인하여 중복을 방지합니다.
    RETURN QUERY
    WITH nearby_users AS (
        SELECT
            l.user_id AS nearby_user_id,
            l.location
        FROM locations l
        WHERE
            l.user_id != current_user_id AND
            ST_DWithin(current_user_location, l.location, distance_meters)
    ),
    new_bumps AS (
        INSERT INTO bumps (user1_id, user2_id)
        SELECT
            current_user_id,
            nu.nearby_user_id
        FROM nearby_users nu
        WHERE NOT EXISTS (
            SELECT 1
            FROM bumps b
            WHERE
                (b.user1_id = current_user_id AND b.user2_id = nu.nearby_user_id) OR
                (b.user1_id = nu.nearby_user_id AND b.user2_id = current_user_id)
                AND b.bumped_at > (NOW() - (time_interval_hours || ' hours')::INTERVAL)
        )
        RETURNING *
    )
    SELECT
        nb.id AS bump_id,
        nb.user1_id,
        nb.user2_id,
        nb.bumped_at AS bumped_at
    FROM new_bumps nb;

END;
$$;
