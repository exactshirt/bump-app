# CLAUDE.md - Bump App 개발 가이드

## 프로젝트 개요

**Bump App**은 Flutter 기반의 모바일 애플리케이션으로, 위치 기반 사회적 만남을 촉진합니다. 앱은 사용자의 위치를 실시간으로 추적하고, 두 사용자가 근접한 거리(30미터) 내에 있을 때 "Bump" 이벤트를 생성하여 물리적 만남을 기록합니다.

**핵심 목적**: 물리적으로 가까이 있는 사람들 간의 자연스러운 실시간 연결 촉진

**프로젝트 타입**: 크로스 플랫폼 모바일 앱 (iOS, Android, Web, macOS, Linux, Windows)

**Repository**: exactshirt/bump-app
**Primary Branch**: `main`
**Development Branch Pattern**: `claude/claude-md-*` (AI 보조 개발용)

---

## 제품 전략 분석

### Aha-Moment 정의

Bump 앱의 **Aha-moment**는 사용자가 처음으로 "의미 있는 만남"을 경험하는 순간입니다. 이는 사용자가 앱의 핵심 가치를 체감하는 결정적 순간입니다.

### 핵심 성공 지표

**Primary Metric: 첫 번째 의미 있는 Bump**
- **목표**: 가입 후 7일 이내에 첫 번째 의미 있는 Bump 경험
- **의미 있는 Bump 정의**: 관심사가 맞는 사람과의 만남 + 연결 의사 확인

**Secondary Metrics**:
- **Bump 빈도**: 활성 사용자 기준 하루 2-5회
- **연결 성공률**: 가입 후 14일 이내 최소 1회 이상의 연결 성공
- **참여도**: Bump 알림 후 1시간 이내 앱 실행

### 사용자 여정 및 행동 모델

#### Phase 1: 온보딩 (1일차)
- 앱 다운로드 및 프로필 생성 (5-10분)
- 위치 권한 허용
- 설정 완료

#### Phase 2: 발견 (1-7일)
- 백그라운드에서 앱 실행
- 일상적인 이동 중 Bump 발생
- **핵심**: 첫 주에 최소 3-5회의 Bump 경험 필요

#### Phase 3: 참여 (7-30일)
- Bump 히스토리 적극 확인
- 연결 요청 송수신
- 대화 시작
- **핵심**: 최소 1회 이상의 성공적인 연결 → 대화 전환

#### Phase 4: 유지 (30일 이상)
- 정기적인 앱 사용
- 여러 활성 연결 유지
- 친구 추천

### 사용 패턴 및 밀도 요구사항

**일주일에 3-5회 Bump를 경험하기 위한 조건:**

1. **평균 도시 사용자의 이동 패턴**:
   - 하루 3-5개 위치 방문 (집, 직장, 점심, 헬스장 등)
   - 각 위치 체류 시간: 2-4시간
   - 하루 총 활동 시간: 12-16시간

2. **Bump 탐지 파라미터**:
   - 탐지 반경: 30미터
   - 위치 업데이트 주기: 5초
   - 최소 중복 시간: 30초 (6회 위치 업데이트)

3. **필요 사용자 밀도**:
   - 주당 3-5회 Bump를 위해: 사용자의 일상 활동 반경 내 50-100명의 활성 사용자 필요
   - 일상 활동 반경: 집 기준 반경 5-10km
   - 도시 밀도: km² 당 1,000-5,000명

### 임계 질량 (Critical Mass)

**도시별 최소 활성 사용자 수:**
- **Tier 1 도시** (서울, 뉴욕, 도쿄): 10,000-20,000명
- **Tier 2 도시** (대전, 부산, 포틀랜드): 5,000-10,000명
- **Tier 3 도시** (소규모 광역시): 2,000-5,000명

**"활성 사용자" 정의:**
- 주 3회 이상 앱 실행
- 위치 추적 활성화
- 주당 최소 10시간 이상 공공장소 체류

### 평균 사용 시간 및 이동 거리

**일일 사용 패턴:**
- **수동적 사용 (백그라운드 추적)**: 하루 12-16시간
- **능동적 사용 (앱 실행)**: 하루 3-5회, 회당 2-5분, 총 10-20분

**일일 평균 이동 거리:**
- **도심 통근자**: 하루 20-40km
- **교외 통근자**: 하루 40-80km
- **학생/지역 주민**: 하루 5-15km

**높은 Bump 발생 확률 장소:**
1. 대중교통 허브 (지하철역, 버스 터미널)
2. 쇼핑 지역
3. 대학 캠퍼스
4. 카페 및 레스토랑
5. 헬스장 및 피트니스 센터
6. 공원 및 레크리에이션 시설

### 사용자 리텐션 벤치마크

**일반 모바일 앱 대비 Bump 목표:**

| 지표 | 업계 평균 | Bump 목표 | 조건 |
|------|----------|----------|------|
| Day 1 리텐션 | 25-30% | 35-40% | 좋은 온보딩 제공 시 |
| Day 7 리텐션 | 10-15% | 20-25% | 3회 이상 Bump 경험 시 |
| Day 30 리텐션 | 5-8% | 15-20% | 1회 이상 연결 성공 시 |

**핵심 리텐션 드라이버:**
1. **Bump 빈도**: 첫 주 5회 이상 Bump 경험 시 리텐션 3배 증가
2. **연결 성공**: 첫 2주 내 1회 이상 연결 시 리텐션 5배 증가
3. **소셜 프루프**: 친구가 앱을 사용 중일 때 리텐션 2배 증가
4. **알림 타이밍**: 실시간 Bump 알림 시 참여도 40% 증가

---

## 인프라 비용 분석

### 비용 구성 요소

Bump 앱의 주요 인프라 비용은 다음과 같습니다:

1. **Supabase** (Backend-as-a-Service)
2. **Google Maps API** (위치 정보 및 지도)
3. **컴퓨팅 리소스** (데이터베이스 및 API 서버)
4. **스토리지** (위치 데이터 및 사용자 프로필)
5. **대역폭** (데이터 전송)

### 사용량 시나리오

**시나리오 A: 초기 단계 (1,000명 활성 사용자)**
- **일일 활성 사용자(DAU)**: 1,000명
- **사용자당 위치 업데이트**: 하루 8,640회 (12시간 x 5초마다)
- **사용자당 Bump 탐지 쿼리**: 하루 288회 (5분마다)
- **사용자당 평균 Bump**: 하루 0.7회 (주당 5회)

**시나리오 B: 성장 단계 (10,000명)**
**시나리오 C: 스케일 단계 (100,000명)**

### Supabase 비용 분석

#### 데이터베이스 운영

**위치 데이터 스토리지:**
- 하루 레코드 수: DAU × 8,640 업데이트
- 레코드 크기: ~100 bytes (user_id, lat, lon, timestamp, accuracy)
- 일일 스토리지 증가:
  - 시나리오 A: 1,000 × 8,640 × 100 bytes = 864 MB/일
  - 시나리오 B: 10,000 × 8,640 × 100 bytes = 8.64 GB/일
  - 시나리오 C: 100,000 × 8,640 × 100 bytes = 86.4 GB/일

**데이터 보관 정책:**
- 24시간 데이터만 보관 (개인정보 보호 및 비용 절감)
- 일일 정리를 통해 스토리지를 정상 상태로 유지

**정상 상태 스토리지:**
- 시나리오 A: ~1 GB (위치) + 0.1 GB (사용자/Bump) = 1.1 GB
- 시나리오 B: ~10 GB (위치) + 1 GB (사용자/Bump) = 11 GB
- 시나리오 C: ~100 GB (위치) + 10 GB (사용자/Bump) = 110 GB

#### API 요청

**위치 업데이트:**
- 시나리오 A: 1,000 × 8,640 = 8.64M 요청/일
- 시나리오 B: 10,000 × 8,640 = 86.4M 요청/일
- 시나리오 C: 100,000 × 8,640 = 864M 요청/일

**Bump 탐지 쿼리:**
- 시나리오 A: 1,000 × 288 = 288K 쿼리/일
- 시나리오 B: 10,000 × 288 = 2.88M 쿼리/일
- 시나리오 C: 100,000 × 288 = 28.8M 쿼리/일

#### Supabase 월 비용 계산

| 사용자 규모 | Supabase | Google Geolocation | Google Maps | **월 총액** | **사용자당 비용** |
|------------|----------|-------------------|-------------|-------------|----------------|
| **1,000명** | $25 | $0 | $329 | **$354** | **$0.35** |
| **10,000명** | $123 | $100 | $5,054 | **$5,277** | **$0.53** |
| **100,000명** | $915 | $1,450 | $52,304 | **$54,669** | **$0.55** |

### Bump 탐지 연산 비용 (현재 구현)

#### 단순 All-for-All 비교 방식의 문제점

**연산 복잡도:**
- N명의 동시 사용자에 대해: N × (N-1) / 2 비교
- 시나리오 A (1,000명): 499,500 비교/사이클
- 시나리오 B (10,000명): 49,995,000 비교/사이클
- 시나리오 C (100,000명): 4,999,950,000 비교/사이클

**탐지 빈도:**
- 5분마다: 하루 288 사이클

**일일 비교 횟수:**
- 시나리오 A: 499,500 × 288 = 143.9M 비교/일
- 시나리오 B: 50M × 288 = 14.4B 비교/일
- 시나리오 C: 5B × 288 = 1.44T 비교/일

**연산 비용 추정:**
- 각 비교당 PostGIS ST_DWithin 쿼리 1회 필요
- 쿼리 비용: ~0.1ms (공간 인덱스 사용 시)

**일일 컴퓨팅 시간:**
- 시나리오 A: 143.9M × 0.1ms = 14,390초 = 4시간
- 시나리오 B: 14.4B × 0.1ms = 1,440,000초 = 400시간
- 시나리오 C: 1.44T × 0.1ms = 144,000,000초 = 40,000시간

**⚠️ 이 방식은 스케일 불가능합니다!**

---

## 서버 최적화 전략

### 문제 정의

단순 all-for-all 비교 방식은 연산 비용이 기하급수적으로 증가하며 확장 불가능합니다.

**목표**: 연산 복잡도를 O(n²)에서 준선형 O(n)으로 줄이면서 높은 정확도 유지

### 해결책 1: H3 기반 공간 파티셔닝 (핵심 솔루션)

Uber의 H3 육각형 계층적 공간 인덱스를 활용하여 세계를 이산적인 셀로 분할하고 검색 공간을 대폭 축소합니다.

#### H3 작동 방식

1. **인덱싱**: 사용자의 위치 업데이트 시, 위도/경도를 특정 해상도의 H3 인덱스로 변환 (예: resolution 12, ~30m 셀 크기)
2. **저장**: `locations` 테이블에 H3 인덱스를 함께 저장
3. **쿼리**: 근처 사용자를 찾을 때, 같은 H3 셀과 인접 셀의 사용자만 비교 (`kRing` 함수 사용)

#### H3의 장점

- **검색 공간 축소**: 작은 지리적 영역 내의 사용자만 비교
- **정수 기반 조회**: H3 인덱스는 64비트 정수로, 조회가 매우 빠름
- **계층 구조**: 다중 해상도 쿼리 가능 (큰 셀로 시작 → 드릴다운)
- **오픈 소스**: 다양한 언어 라이브러리 지원

#### 구현 단계

**Step 1: 데이터베이스 스키마 수정**

```sql
ALTER TABLE locations
ADD COLUMN h3_index BIGINT;

CREATE INDEX idx_locations_h3_index ON locations (h3_index);
```

**Step 2: LocationService 업데이트**

```dart
// H3 라이브러리 사용
import 'package:h3_flutter/h3_flutter.dart';

Future<void> _saveCurrentLocation(String userId) async {
  final position = await Geolocator.getCurrentPosition();
  final h3Index = h3.geoToH3(position.latitude, position.longitude, 12);

  await _supabase.from('locations').insert({
    'user_id': userId,
    'location': 'POINT(${position.longitude} ${position.latitude})',
    'h3_index': h3Index,
    // ... 기타 필드
  });
}
```

**Step 3: Bump 탐지 로직 재작성**

```sql
CREATE OR REPLACE FUNCTION find_nearby_users_h3(
    current_user_id UUID,
    time_interval_hours INT
)
RETURNS TABLE (bump_id UUID, user1_id UUID, user2_id UUID, bumped_at TIMESTAMPTZ)
AS $$
DECLARE
    current_user_h3_index BIGINT;
BEGIN
    -- 1. 현재 사용자의 H3 인덱스 가져오기
    SELECT h3_index INTO current_user_h3_index
    FROM locations
    WHERE user_id = current_user_id
    ORDER BY timestamp DESC
    LIMIT 1;

    -- 2. 인접 H3 셀 가져오기 (k-ring size 1)
    -- 3. 같은 셀 및 인접 셀의 사용자 찾기
    RETURN QUERY
    WITH nearby_users AS (
        SELECT l.user_id AS nearby_user_id
        FROM locations l
        WHERE
            l.user_id != current_user_id AND
            l.h3_index IN (
                -- 현재 및 인접 H3 셀 목록
                -- 예: (current_user_h3_index, neighbor1, neighbor2, ...)
            )
    ),
    -- ... (나머지 로직은 동일)
END;
$$ LANGUAGE plpgsql;
```

### 추가 최적화 전략

#### 전략 2: 시간 필터링 (Temporal Filtering)

**문제**: 몇 시간 전에 활동한 사용자까지 비교

**해결**: 최근 5-10분 내 활동한 사용자만 비교

```sql
-- WHERE 절에 추가
AND l.timestamp > (NOW() - INTERVAL '5 minutes')
```

**효과**: 비교 대상 50-80% 감소

#### 전략 3: 캐싱 레이어 (Redis)

**문제**: 동일한 위치 데이터를 반복적으로 데이터베이스에서 조회

**해결**: Redis를 사용한 인메모리 캐시

**구현**:
1. 위치 업데이트 시 Supabase와 Redis에 동시 저장
2. Bump 탐지 시 Redis에서 먼저 조회
3. Redis에 없으면 Supabase 조회 후 캐시 채우기

**효과**: 데이터베이스 부하 70-90% 감소, 쿼리 응답 시간 단축

#### 전략 4: 적응형 위치 업데이트 빈도

**문제**: 일정한 5초 간격 업데이트는 배터리를 빠르게 소모하고 불필요한 데이터 생성

**해결**: 사용자의 컨텍스트에 따라 업데이트 빈도 조정

- **높은 빈도 (5초)**: 사용자가 이동 중일 때 (걷기, 운전)
- **중간 빈도 (30초)**: 사용자가 정지 상태일 때 (직장, 집)
- **낮은 빈도 (5분)**: 휴대폰이 유휴 상태이거나 충전 중일 때

**구현**:
- 기기의 모션 센서(가속도계) 활용
- `activity_recognition_flutter` 같은 플러그인 사용

**효과**: 배터리 소모 30-50% 감소, 데이터량 및 비용 절감

#### 전략 5: 배치 처리 및 비동기 작업

**문제**: 실시간 Bump 탐지는 리소스 집약적

**해결**: Bump 탐지를 백그라운드 작업으로 이동 (주기적 실행, 예: 1-5분마다)

**구현**:
- 메시지 큐(RabbitMQ, AWS SQS) 사용하여 위치 업데이트 버퍼링
- 별도의 워커 프로세스가 업데이트를 소비하고 배치로 Bump 탐지 실행

**효과**: 위치 업데이트와 Bump 탐지 분리, 시스템 복원력 향상

### 비용 절감 효과 추정

#### H3 파티셔닝 적용 시

**연산 비용 감소**: 95-99%
- 100,000명 사용자 기준 1.44T 비교/일 → 129.6M 비교/일
  - 셀당 평균 사용자: ~10명
  - 셀당 비교: 10 × 9 / 2 = 45
  - 사용자가 있는 총 셀: ~10,000개
  - 총 비교: 45 × 10,000 = 450,000/사이클
  - 일일 비교: 450,000 × 288 = 129.6M/일

**새로운 연산 시간 (100,000명)**:
- 129.6M × 0.1ms = 12,960초 = 3.6시간 (기존 40,000시간 대비)

#### 모든 최적화 적용 시

| 최적화 전략 | 비용 절감 | 구현 복잡도 |
|-----------|---------|----------|
| H3 파티셔닝 | 95-99% (연산) | 중간 |
| 시간 필터링 | 50-80% (연산) | 낮음 |
| 캐싱 (Redis) | 70-90% (DB 부하) | 중간 |
| 적응형 빈도 | 30-50% (데이터/배터리) | 높음 |
| 배치 처리 | 20-30% (연산) | 높음 |

**종합 효과**: 연산 비용 99% 이상 감소, 데이터베이스 및 대역폭 비용 대폭 절감

---

## 개발 로드맵

### Phase 1: 초기 단계 (0-10,000명)

**목표**: 제품-시장 적합성(Product-Market Fit) 달성

**핵심 작업:**
1. ✅ **H3 파티셔닝 구현** - Supabase RPC 함수 수정
2. ✅ **시간 필터링 추가** - 최근 활동 사용자만 쿼리
3. **사용자 인증 구현** - 하드코딩된 테스트 사용자 ID 제거
4. **푸시 알림 시스템** - 실시간 Bump 알림
5. **RLS 정책 적용** - 데이터 보안 강화

**예상 비용**: 월 $354 → $5,277
**예상 기간**: 3-6개월

### Phase 2: 성장 단계 (10,000-100,000명)

**목표**: 수익성 있는 성장 및 사용자 경험 최적화

**핵심 작업:**
1. **Redis 캐싱 레이어 도입** - 데이터베이스 부하 감소
2. **적응형 위치 업데이트** - 배터리 수명 개선
3. **지도 제공자 다변화** - Google Maps 비용 절감 (Mapbox 등 고려)
4. **소셜 기능 추가** - 프로필, 친구 요청, 채팅
5. **국제화 (i18n)** - 다국어 지원

**예상 비용**: 월 $5,277 → $20,000 (최적화 후)
**예상 기간**: 6-12개월

### Phase 3: 스케일 단계 (100,000명 이상)

**목표**: 글로벌 확장 및 수평 확장성 확보

**핵심 작업:**
1. **비동기 배치 처리** - 메시지 큐 도입
2. **데이터베이스 샤딩** - 지역별 DB 분산
3. **커스텀 인프라** - Supabase 의존성 감소
4. **자체 지도 렌더링** - Google Maps 비용 완전 제거
5. **기업용 요금제 협상** - 볼륨 할인

**예상 비용**: 월 $20,000 → $30,000 (완전 최적화 후)
**예상 기간**: 12개월 이상

---

## 기술 스택

### Frontend
- **Flutter SDK**: ^3.10.0
- **Dart**: ^3.10.0
- **State Management**: Built-in StatefulWidget (추후 Provider/Riverpod 고려)
- **UI**: Material Design 3

### Backend & Services
- **Supabase**: Backend-as-a-Service
  - PostgreSQL database with PostGIS extension
  - Real-time subscriptions
  - Authentication
  - RESTful API (auto-generated)
- **Production URL**: `https://uilmcneizmsqiercrlrt.supabase.co`

### 신규 추가 예정 기술
- **H3**: Uber의 공간 인덱스 라이브러리
- **Redis**: 인메모리 캐싱
- **Message Queue**: RabbitMQ 또는 AWS SQS (Phase 3)

### 주요 의존성
```yaml
dependencies:
  supabase_flutter: ^2.10.3      # Supabase 클라이언트
  google_maps_flutter: ^2.14.0   # 지도 통합
  geolocator: ^14.0.2            # 위치 서비스
  permission_handler: ^12.0.1    # 런타임 권한
  h3_flutter: ^latest            # H3 공간 인덱싱 (추가 예정)

dev_dependencies:
  flutter_test: sdk              # 테스트 프레임워크
  flutter_lints: ^6.0.0          # 린팅 규칙
  supabase: ^2.58.5              # Supabase CLI
```

---

## 아키텍처

### 프로젝트 구조

```
bump-app/
├── lib/
│   ├── main.dart              # 앱 진입점, Supabase 초기화
│   ├── models/
│   │   └── bump.dart          # Bump 데이터 모델
│   └── services/
│       ├── location_service.dart  # 위치 추적 및 저장
│       └── bump_service.dart      # Bump 탐지 로직
├── test/
│   └── widget_test.dart       # 위젯 테스트 (업데이트 필요)
├── supabase/
│   ├── config.toml            # 로컬 Supabase 설정
│   └── functions/
│       └── find_nearby_users.sql  # PostGIS 근접 탐지
├── android/                   # Android 특화 설정
├── ios/                       # iOS 특화 설정
└── pubspec.yaml               # Flutter 의존성
```

### 서비스 레이어 아키텍처

#### 1. LocationService (`lib/services/location_service.dart`)

**싱글톤 패턴**: 앱 전체에서 하나의 인스턴스만 존재

**책임:**
- 위치 권한 요청 및 관리
- 5초 간격으로 사용자 위치 추적
- Supabase `locations` 테이블에 위치 데이터 저장
- 위치 추적 생명주기 관리 (시작/중지)
- 일회성 위치 조회 제공
- 오래된 위치 데이터 정리 (24시간 보관)

**주요 메서드:**
```dart
Future<bool> requestLocationPermission()
Future<void> startLocationTracking(String userId)
void stopLocationTracking()
Future<Position?> getCurrentLocation()
Future<void> deleteOldLocationData(String userId)
```

**구현 세부사항:**
- `Timer.periodic`를 5초 간격으로 사용
- 저장 데이터: latitude, longitude, accuracy, altitude, timestamp, h3_index
- `userId` 필수 (데이터 연관)
- 24시간 후 자동 정리 (수동 트리거)

#### 2. BumpService (`lib/services/bump_service.dart`)

**책임:**
- PostGIS 공간 쿼리를 사용한 근처 사용자 탐지
- 근접 만남에 대한 Bump 레코드 생성
- 시간 창 내 중복 Bump 방지

**주요 메서드:**
```dart
Future<List<Bump>> findBumps(String userId)
```

**구현 세부사항:**
- Supabase RPC 함수 `find_nearby_users` 호출
- 기본 근접 임계값: 30미터
- 중복 방지 시간 창: 1시간
- 새로 생성된 Bump 목록 반환

### 데이터 모델

#### Bump Model (`lib/models/bump.dart`)
```dart
class Bump {
  final String id;          // UUID
  final String user1Id;     // 첫 번째 사용자 UUID
  final String user2Id;     // 두 번째 사용자 UUID
  final DateTime bumpedAt;  // Bump 발생 타임스탬프
}
```

---

## 데이터베이스 스키마

### Supabase 테이블

#### `locations` 테이블
```sql
CREATE TABLE locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  altitude DOUBLE PRECISION,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  location GEOGRAPHY(Point, 4326), -- PostGIS geometry column
  h3_index BIGINT                  -- H3 spatial index (추가 예정)
);

-- 공간 쿼리를 위한 인덱스
CREATE INDEX idx_locations_geography ON locations USING GIST(location);
CREATE INDEX idx_locations_h3_index ON locations (h3_index);
CREATE INDEX idx_locations_user_timestamp ON locations(user_id, timestamp DESC);
```

#### `bumps` 테이블
```sql
CREATE TABLE bumps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL,
  user2_id UUID NOT NULL,
  bumped_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

  -- 참고: 원래 컬럼명은 'timestamp'였으나 PostgreSQL 예약어 충돌로 'bumped_at'으로 변경
);

CREATE INDEX idx_bumps_users ON bumps(user1_id, user2_id);
CREATE INDEX idx_bumps_timestamp ON bumps(bumped_at);
```

### 데이터베이스 함수

#### `find_nearby_users()` - PostGIS 근접 탐지 (현재)

**위치**: `supabase/functions/find_nearby_users.sql`

**알고리즘**:
1. 현재 사용자의 최신 위치 조회
2. PostGIS `ST_DWithin`을 사용하여 지정된 거리 내 사용자 찾기
3. 시간 간격 내 기존 Bump 확인하여 중복 방지
4. 고유한 만남에 대한 새 Bump 레코드 삽입
5. 새로 생성된 Bump 반환

**주요 기능:**
- PostGIS GIST를 사용한 공간 인덱싱
- CTE(Common Table Expressions)를 사용한 원자적 연산
- 양방향 중복 방지 (user1↔user2)
- 구성 가능한 거리 및 시간 임계값

#### `find_nearby_users_h3()` - H3 기반 근접 탐지 (구현 예정)

Phase 1에서 H3 인덱스를 사용하는 새로운 함수로 대체 예정. 위 "서버 최적화 전략" 섹션 참조.

---

## 플랫폼 설정

### Android (`android/app/src/main/AndroidManifest.xml`)

**필수 권한:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

**설정:**
- Google Maps API Key: `meta-data`에 구성됨
- 로컬 개발을 위한 Clear text traffic 활성화
- 백그라운드 위치 추적을 위한 Foreground service 지원

### iOS (`ios/Runner/Info.plist`)

**위치 권한 설명** (한국어):
- `NSLocationWhenInUseUsageDescription`: 앱 사용 중 위치 사용
- `NSLocationAlwaysAndWhenInUseUsageDescription`: 백그라운드 위치 사용
- `NSLocationAlwaysUsageDescription`: 상시 위치 접근
- Google Maps API Key: plist에 구성됨

**개인정보 보호 준수:**
- 위치 접근에 대한 명시적인 사용자 대면 설명
- 권한에 24시간 데이터 보관 정책 언급
- Bump 탐지를 위한 백그라운드 위치 정당화

---

## 개발 워크플로우

### 로컬 개발 설정

1. **Flutter SDK 설치** (v3.10.0+)
   ```bash
   flutter doctor
   ```

2. **의존성 설치**
   ```bash
   flutter pub get
   npm install  # Supabase CLI용
   ```

3. **Supabase 설정** (로컬 개발용, 선택사항)
   ```bash
   npx supabase start
   ```

4. **앱 실행**
   ```bash
   flutter run
   # 특정 디바이스 지정:
   flutter run -d android
   flutter run -d ios
   ```

### 테스트 워크플로우

**현재 테스트 상태**: 위젯 테스트가 구식임 (여전히 카운터 증가 테스트 중)

**필요한 테스트 업데이트:**
- `test/widget_test.dart`를 실제 Bump 앱 기능 테스트로 업데이트
- LocationService 단위 테스트 추가
- BumpService 단위 테스트 추가
- Bump 탐지 플로우 통합 테스트 추가

**테스트 실행:**
```bash
flutter test
```

### Git 워크플로우

**브랜치 명명 규칙:**
- `main`: 프로덕션 준비 코드
- `feature/*`: 기능 개발 브랜치
- `claude/claude-md-*`: AI 보조 개발 브랜치
- `fix/*`: 버그 수정

**커밋 메시지 형식:**
```
<type>: <subject>

예시:
feat: Implement location tracking service with Supabase integration
fix: Rename timestamp to bumped_at to avoid PostgreSQL reserved word conflict
docs: Add comprehensive CLAUDE.md development guide
```

**타입**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 코드 리뷰 체크리스트

- [ ] 추적 전 위치 권한 적절히 요청됨
- [ ] 프로덕션 코드에 민감 데이터(API 키) 하드코딩 없음
- [ ] dispose 시 위치 추적 적절히 중지됨
- [ ] 네트워크 실패에 대한 오류 처리
- [ ] 전체적으로 null safety 유지
- [ ] 한국어 UI 문자열 적절히 처리됨 (현재 하드코딩)
- [ ] PostGIS 공간 쿼리가 적절한 인덱스 사용
- [ ] Bump 중복 제거 로직 테스트됨

---

## 코딩 규칙

### Dart/Flutter 규칙

1. **Null Safety**: 엄격한 null safety 활성화 (SDK ^3.10.0)
   ```dart
   Position? position = await _locationService.getCurrentLocation();
   if (position != null) {
     // position을 안전하게 사용
   }
   ```

2. **Async/Await**: 원시 Future보다 선호
   ```dart
   Future<void> _startTracking() async {
     try {
       await _locationService.startLocationTracking(userId);
     } catch (e) {
       // 오류 처리
     }
   }
   ```

3. **싱글톤 패턴**: 서비스에 사용
   ```dart
   class LocationService {
     static final LocationService _instance = LocationService._internal();
     factory LocationService() => _instance;
     LocationService._internal();
   }
   ```

4. **문서화**: 공개 API에 /// 사용
   ```dart
   /// 위치 추적 시작
   ///
   /// 5초 간격으로 위치를 가져오고 Supabase에 저장합니다.
   Future<void> startLocationTracking(String userId) async { }
   ```

5. **명명 규칙**:
   - Private 멤버: `_variableName`, `_methodName()`
   - 상수: `kConstantName` 또는 `CONSTANT_NAME`
   - 파일: `snake_case.dart`
   - 클래스: `PascalCase`
   - 변수/메서드: `camelCase`

### SQL 규칙

1. **예약어**: PostgreSQL 예약어 피하기
   - `timestamp` → `bumped_at` (PR #4에서 학습)

2. **공간 쿼리**: PostGIS 함수를 일관되게 사용
   ```sql
   ST_DWithin(location1, location2, distance_meters)
   ```

3. **인덱스**: 항상 공간 및 시간 컬럼 인덱싱
   ```sql
   CREATE INDEX idx_locations_geography ON locations USING GIST(location);
   CREATE INDEX idx_locations_h3_index ON locations (h3_index);
   ```

---

## 보안 고려사항

### 현재 보안 이슈 (해결 필요)

⚠️ **중요**: 현재 코드베이스에 다음 보안 이슈가 존재합니다:

1. **소스 코드 내 API 키**:
   - `lib/main.dart:11-13`에 Supabase URL 및 anon key
   - `android/app/src/main/AndroidManifest.xml:44`에 Google Maps API 키
   - `ios/Runner/Info.plist:22`에 Google Maps API 키

   **필요한 조치**: 환경 변수 또는 보안 저장소로 이동
   ```dart
   // TODO: flutter_dotenv 또는 유사한 것 사용
   await Supabase.initialize(
     url: const String.fromEnvironment('SUPABASE_URL'),
     anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
   );
   ```

2. **하드코딩된 테스트 사용자 ID**:
   - `lib/main.dart:85,137`에 `const userId = 'test-user-123'`

   **필요한 조치**: Supabase 인증 구현
   ```dart
   final userId = Supabase.instance.client.auth.currentUser?.id;
   ```

3. **Row Level Security (RLS)**:
   - Supabase 테이블에 아직 구현되지 않음

   **필요한 조치**: RLS 정책 추가
   ```sql
   ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
   ALTER TABLE bumps ENABLE ROW LEVEL SECURITY;

   CREATE POLICY "Users can only see their own locations"
     ON locations FOR SELECT
     USING (auth.uid() = user_id);
   ```

### 보안 모범 사례

1. **위치 데이터**:
   - 자동 24시간 데이터 삭제 구현 (현재 수동)
   - 정확한 위치를 다른 사용자에게 절대 노출하지 않음
   - 근접 탐지에만 공간 쿼리 사용

2. **API 보안**:
   - 프로덕션 전 인증 구현
   - 데이터 접근 제어를 위해 Supabase RLS 사용
   - 남용 방지를 위한 Bump 탐지 속도 제한

3. **개인정보 보호 준수**:
   - 24시간 데이터 보관을 명확히 전달
   - 옵트아웃 메커니즘 제공
   - 사용자가 요청 시 데이터 삭제 허용

---

## AI 어시스턴트 가이드라인

### 이 코드베이스 작업 시

1. **항상 보안 확인**:
   - API 키나 시크릿을 절대 커밋하지 말 것
   - 위치 접근 전 적절한 권한 확인 보장
   - 데이터 작업 전 사용자 인증 검증

2. **일관성 유지**:
   - 기존 명명 규칙 따르기
   - 확립된 패턴 사용 (서비스용 싱글톤 등)
   - 한국어 주석이 있는 곳에서는 유지 (팀 일관성)

3. **철저한 테스트**:
   - UI 수정 시 위젯 테스트 업데이트
   - Android와 iOS 모두에서 위치 권한 테스트
   - PostGIS 쿼리가 예상 결과 반환하는지 확인

4. **변경사항 문서화**:
   - 아키텍처 변경 시 이 CLAUDE.md 업데이트
   - 복잡한 로직에 인라인 주석 추가
   - 사용자 대면 변경사항은 README.md 업데이트

5. **개인정보 보호 고려**:
   - 위치 데이터는 민감함
   - 데이터 최소화 원칙 구현
   - GDPR/개인정보 보호 규정 준수 보장

6. **Git 관행**:
   - 새 작업에는 feature 브랜치 사용
   - 설명적인 커밋 메시지 작성
   - AI 보조 작업은 지정된 `claude/*` 브랜치에 푸시

### 데이터베이스 변경 시

1. **스키마 마이그레이션**: 아직 구현되지 않음
   - 현재는 Supabase 대시보드를 통해 직접 변경 적용
   - 모든 스키마 변경사항을 마이그레이션 SQL 파일에 문서화
   - 적절한 마이그레이션 시스템 구현 계획

2. **데이터베이스 함수 테스트**:
   ```sql
   -- find_nearby_users 함수 테스트
   SELECT * FROM find_nearby_users(
     'test-user-id'::UUID,
     30.0,  -- 30 meters
     1      -- 1 hour
   );
   ```

3. **파괴적 변경 전 백업**:
   - 스키마 변경 전 항상 프로덕션 데이터 백업
   - 로컬 Supabase 인스턴스에서 먼저 테스트

---

## 스케일링 임계값

**중요 스케일링 포인트:**

1. **1,000 → 10,000명**: H3 공간 파티셔닝 구현 필요
2. **10,000 → 50,000명**: 전용 데이터베이스 클러스터로 업그레이드 필요
3. **50,000 → 100,000명**: 분산 처리 구현 필요
4. **100,000명 이상**: 커스텀 인프라 또는 엔터프라이즈 플랜 고려

---

## 문제 해결

### 일반적인 문제

1. **위치 권한 거부됨**
   - AndroidManifest.xml 및 Info.plist 설정 확인
   - 디바이스 설정에서 사용자가 권한을 부여했는지 확인
   - iOS: 설정 → 개인정보 보호 → 위치 서비스
   - Android: 설정 → 앱 → Bump App → 권한

2. **Supabase 연결 오류**
   - 인터넷 연결 확인
   - Supabase URL 및 anon key 확인
   - Supabase 대시보드에서 프로젝트가 일시 중지되지 않았는지 확인
   - CORS 문제 확인 (웹 플랫폼)

3. **PostGIS 함수를 찾을 수 없음**
   - Supabase에서 PostGIS 확장이 활성화되어 있는지 확인
   - 실행: `CREATE EXTENSION IF NOT EXISTS postgis;`
   - 함수가 배포되었는지 확인: `SELECT * FROM pg_proc WHERE proname = 'find_nearby_users';`

4. **백그라운드 위치가 작동하지 않음**
   - Android 10+: `ACCESS_BACKGROUND_LOCATION` 권한 필요
   - iOS: 권한 대화상자에서 사용자가 "항상 허용"을 선택해야 함
   - Android용 Foreground service 구현 고려

---

## 성능 고려사항

1. **위치 업데이트**: 5초 간격은 공격적임
   - 사용자 활동에 따른 동적 간격 고려 (적응형 빈도)
   - 정지 상태일 때 업데이트를 줄이기 위해 지오펜싱 구현

2. **데이터베이스 쿼리**: PostGIS 공간 쿼리는 인덱싱됨
   - 사용자 기반 증가에 따라 쿼리 성능 모니터링
   - 빈번한 쿼리를 위한 캐싱 전략 고려 (Redis)

3. **배터리 사용**: 지속적인 위치 추적은 배터리 집약적
   - 배터리 영향을 사용자에게 알림
   - 업데이트 빈도를 줄일 수 있는 옵션 제공
   - 지속적인 업데이트 대신 중요한 위치 변경 사용

---

## 향후 개선사항

### 계획된 기능 (아직 구현되지 않음)

1. **사용자 인증** (Phase 1 우선순위)
   - 이메일/비밀번호 가입
   - OAuth 제공자 (Google, Apple)
   - 사용자 프로필

2. **실시간 Bump 알림** (Phase 1 우선순위)
   - Bump 발생 시 푸시 알림
   - 인앱 알림 시스템

3. **국제화 (i18n)** (Phase 2)
   - 현재 UI 문자열은 한국어로 하드코딩됨
   - flutter_localizations 구현 필요
   - 다국어 지원

4. **지도 뷰** (Phase 2)
   - Google Maps 통합은 구성되어 있지만 사용되지 않음
   - 사용자의 현재 위치를 지도에 표시
   - Bump 위치 시각화 (개인정보 보호 고려)

5. **소셜 기능** (Phase 2)
   - 사용자 프로필
   - Bump 후 친구 요청
   - 채팅 기능
   - Bump 히스토리

6. **분석** (Phase 3)
   - Bump 빈도 추적
   - 사용자 참여 지표
   - 위치 패턴 분석 (익명화)

---

## 연락처 및 리소스

- **Supabase Dashboard**: https://supabase.com/dashboard/project/uilmcneizmsqiercrlrt
- **Flutter Docs**: https://docs.flutter.dev/
- **PostGIS Documentation**: https://postgis.net/docs/
- **H3 Documentation**: https://h3geo.org/
- **Geolocator Plugin**: https://pub.dev/packages/geolocator

---

## 버전 히스토리

- **v1.0.0**: 핵심 Bump 탐지 기능이 포함된 초기 릴리스
  - 위치 추적 (5초 간격)
  - PostGIS 기반 근접 탐지 (30m 임계값)
  - 추적 제어 및 Bump 표시를 위한 기본 UI
  - Android 및 iOS 플랫폼 지원

- **v1.1.0**: H3 기반 최적화 및 인증 (계획)
  - H3 공간 파티셔닝 구현
  - Supabase 인증 통합
  - 푸시 알림 시스템
  - RLS 정책 적용

---

**최종 업데이트**: 2025-11-19
**유지 관리자**: AI Assistants (Claude) & Development Team
