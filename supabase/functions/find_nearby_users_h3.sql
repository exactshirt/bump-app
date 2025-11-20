-- Supabase RPC 함수: find_nearby_users (H3 최적화 버전)
--
-- 이 함수는 H3 공간 파티셔닝을 사용하여 현재 사용자와 가까운 거리에 있는
-- 다른 사용자를 효율적으로 찾아 Bump를 생성합니다.
--
-- 최적화 전략:
-- 1. H3 인덱스로 검색 공간을 대폭 축소 (O(n²) → O(n))
-- 2. 시간 필터링으로 최근 활동 사용자만 검색
-- 3. PostGIS로 정확한 거리 검증
--
-- 매개변수:
--   - current_user_id: 현재 사용자의 ID (UUID)
--   - distance_meters: 검색할 거리 (미터 단위, 예: 30)
--   - time_interval_hours: 중복 Bump를 방지하기 위한 시간 간격 (시간 단위, 예: 1)
--   - active_user_minutes: 최근 활동 사용자 기준 (분 단위, 예: 5)

CREATE OR REPLACE FUNCTION find_nearby_users(
    current_user_id UUID,
    distance_meters FLOAT DEFAULT 30,
    time_interval_hours INT DEFAULT 1,
    active_user_minutes INT DEFAULT 5
)
RETURNS TABLE (bump_id UUID, user1_id UUID, user2_id UUID, bumped_at TIMESTAMPTZ)
AS $$
DECLARE
    current_user_location GEOMETRY;
    current_user_h3_index BIGINT;
BEGIN
    -- 1. 현재 사용자의 최신 위치와 H3 인덱스를 가져옵니다.
    SELECT location, h3_index
    INTO current_user_location, current_user_h3_index
    FROM locations
    WHERE user_id = current_user_id
    ORDER BY timestamp DESC
    LIMIT 1;

    -- 사용자 위치가 없으면 빈 결과 반환
    IF current_user_location IS NULL THEN
        RETURN;
    END IF;

    -- 2. H3 인덱스와 시간 필터를 사용하여 근처 사용자를 찾습니다.
    --    성능 최적화:
    --    - 같은 H3 셀에 있는 사용자만 검색 (향후 kRing으로 확장 가능)
    --    - 최근 5분 내에 활동한 사용자만 검색
    --    - ST_DWithin으로 정확한 거리 검증
    RETURN QUERY
    WITH nearby_users AS (
        SELECT DISTINCT ON (l.user_id)
            l.user_id AS nearby_user_id,
            l.location,
            l.timestamp
        FROM locations l
        WHERE
            l.user_id != current_user_id AND
            -- H3 필터: 같은 셀에 있는 사용자 (검색 공간 95-99% 축소)
            l.h3_index = current_user_h3_index AND
            -- 시간 필터: 최근 활동 사용자만 (추가 50-80% 축소)
            l.timestamp > (NOW() - (active_user_minutes || ' minutes')::INTERVAL)
        ORDER BY l.user_id, l.timestamp DESC
    ),
    verified_nearby_users AS (
        SELECT
            nu.nearby_user_id,
            nu.timestamp
        FROM nearby_users nu
        WHERE
            -- PostGIS 검증: 정확한 거리 확인
            ST_DWithin(current_user_location, nu.location, distance_meters)
    ),
    new_bumps AS (
        INSERT INTO bumps (user1_id, user2_id)
        SELECT
            current_user_id,
            vnu.nearby_user_id
        FROM verified_nearby_users vnu
        WHERE NOT EXISTS (
            -- 중복 Bump 방지
            SELECT 1
            FROM bumps b
            WHERE
                ((b.user1_id = current_user_id AND b.user2_id = vnu.nearby_user_id) OR
                 (b.user1_id = vnu.nearby_user_id AND b.user2_id = current_user_id))
                AND b.bumped_at > (NOW() - (time_interval_hours || ' hours')::INTERVAL)
        )
        RETURNING *
    )
    SELECT
        nb.id AS bump_id,
        nb.user1_id,
        nb.user2_id,
        nb.bumped_at
    FROM new_bumps nb;

END;
$$ LANGUAGE plpgsql;

-- 사용 예시:
-- SELECT * FROM find_nearby_users(
--     'user-uuid-here'::UUID,  -- current_user_id
--     30.0,                     -- distance_meters (30m)
--     1,                        -- time_interval_hours (1시간)
--     5                         -- active_user_minutes (5분)
-- );
