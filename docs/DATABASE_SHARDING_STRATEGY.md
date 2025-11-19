# Database Sharding Strategy for Bump App

## Overview

When the Bump app reaches 100,000+ users, a single PostgreSQL database becomes a bottleneck. This document outlines a geographic-based sharding strategy that leverages the app's location-based nature to distribute data across multiple database instances.

## Why Sharding?

### Single Database Limitations (at scale)

**Performance Issues:**
- Write throughput ceiling: ~10,000 writes/sec per server
- At 100,000 users: 288,000 updates/5min = 960 updates/sec
- Headroom for growth is limited
- Index size grows, slowing queries

**Storage Limitations:**
- Single server max storage: typically 1-16 TB
- Location data growth: ~100GB per 1M users per month
- Bumps, messages, profiles add more

**Reliability Issues:**
- Single point of failure
- Difficult to perform maintenance without downtime
- Backups become slower as data grows

### Benefits of Sharding

**Performance:**
- Linear scaling: 2x shards = 2x capacity
- Reduced index size per shard = faster queries
- Parallel query execution

**Reliability:**
- Fault isolation: one shard failure doesn't affect others
- Rolling updates without full downtime
- Geographic redundancy

**Cost:**
- Use smaller, cheaper instances
- Scale only hot shards
- Optimize costs per region

## Sharding Strategy: Geographic Partitioning

### Why Geographic Sharding?

Bump is inherently location-based:
- Users primarily bump with nearby users
- Cross-region bumps are rare
- Location queries are naturally scoped to a region

### Shard Key: H3 Resolution 3 (Average area ~12,393 km²)

**Why H3 Resolution 3?**
- Covers city-scale regions
- Korea has ~80 H3 cells at this resolution
- Enables regional scaling while maintaining manageable shard count

**Examples:**
- Seoul metropolitan area: ~5-7 H3 cells
- Busan: ~2-3 H3 cells
- Rural areas: 1 cell per large region

### Shard Mapping

```
┌─────────────────────────────────────────────────────┐
│             Global Router / API Gateway             │
└──────────────────┬──────────────────────────────────┘
                   │
        ┌──────────┼──────────┬──────────────┐
        ▼          ▼          ▼              ▼
   ┌────────┐ ┌────────┐ ┌────────┐    ┌────────┐
   │ Shard  │ │ Shard  │ │ Shard  │    │ Shard  │
   │  KR-1  │ │  KR-2  │ │  US-1  │... │  JP-1  │
   │ (Seoul)│ │(Busan) │ │  (SF)  │    │(Tokyo) │
   └────────┘ └────────┘ └────────┘    └────────┘
```

## Shard Architecture

### Shard Composition

Each shard contains:

1. **Primary Tables:**
   - `locations` - Location updates for users in this shard
   - `bumps` - Bumps that occurred in this region
   - `profiles` - User profiles (replicated globally or by home shard)

2. **Local Tables:**
   - `chat_rooms` - Local chat rooms
   - `messages` - Messages between local users

3. **Reference Data (Replicated):**
   - Configuration
   - Feature flags
   - Shared lookup tables

### Shard Assignment Logic

```sql
-- Function to determine shard for a given H3 index
CREATE OR REPLACE FUNCTION get_shard_for_h3(h3_index BIGINT)
RETURNS VARCHAR AS $$
DECLARE
  h3_res3 BIGINT;
  shard_id VARCHAR;
BEGIN
  -- Convert to H3 resolution 3
  h3_res3 := h3_to_parent(h3_index, 3);

  -- Look up shard mapping
  SELECT shard INTO shard_id
  FROM shard_mapping
  WHERE h3_cell = h3_res3;

  -- Default to primary shard if not found
  RETURN COALESCE(shard_id, 'default');
END;
$$ LANGUAGE plpgsql;
```

### Shard Mapping Table (Global)

Stored in a central coordination database or Redis:

```sql
CREATE TABLE shard_mapping (
  h3_cell BIGINT PRIMARY KEY,
  shard_id VARCHAR(50) NOT NULL,
  shard_host VARCHAR(255) NOT NULL,
  shard_port INTEGER NOT NULL,
  region VARCHAR(50),
  capacity_status VARCHAR(20), -- active, full, read-only
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Example data
INSERT INTO shard_mapping VALUES
  (622203845394604031, 'KR-1', 'seoul-db-1.bump.com', 5432, 'Seoul', 'active'),
  (622203845394604032, 'KR-1', 'seoul-db-1.bump.com', 5432, 'Seoul', 'active'),
  (622203845394604033, 'KR-2', 'busan-db-1.bump.com', 5432, 'Busan', 'active'),
  (622203845394604034, 'US-1', 'sf-db-1.bump.com', 5432, 'San Francisco', 'active');
```

## Handling Cross-Shard Queries

### Problem: Bumps Across Shard Boundaries

What happens when users from different shards are near a shard boundary?

**Example:**
- User A is in Seoul (Shard KR-1)
- User B is in Incheon (Shard KR-2)
- They are 20 meters apart (near city boundary)

### Solution 1: Denormalized Cross-Shard Bumps (Recommended)

Write bump to both shards:

```python
def record_bump(user1, user2, location):
    shard1 = get_shard_for_user(user1)
    shard2 = get_shard_for_user(user2)

    bump_data = {
        'user1_id': user1,
        'user2_id': user2,
        'location': location,
        'timestamp': now()
    }

    # Write to both shards
    shard1.insert('bumps', bump_data)

    if shard1 != shard2:
        # Cross-shard bump - write to second shard too
        shard2.insert('bumps', bump_data)
        # Mark as cross-shard for reconciliation
        shard1.insert('cross_shard_bumps', {
            'bump_id': bump_data['id'],
            'other_shard': shard2
        })
```

**Pros:**
- Each user sees their bumps in their home shard
- No cross-shard queries needed at read time

**Cons:**
- Slight data duplication
- Requires distributed transaction or eventual consistency

### Solution 2: Home Shard Strategy

Assign each user a "home shard" based on their primary location:

```python
# Assign home shard on user signup
def assign_home_shard(user_id, signup_location):
    h3_index = get_h3_index(signup_location, resolution=3)
    home_shard = get_shard_for_h3(h3_index)

    # Store in global user registry
    user_registry.set(user_id, {
        'home_shard': home_shard,
        'signup_h3': h3_index
    })

    return home_shard
```

All data for that user (locations, bumps, profiles) goes to their home shard, even if they travel.

**Pros:**
- Simple query routing
- No cross-shard joins
- User data is colocated

**Cons:**
- Imbalanced shards if users move
- Bumps between shards still need handling

### Solution 3: H3 Cell Overlap Buffer

Store users in multiple shards if they're near a boundary:

```python
def get_shards_for_location(lat, lon):
    h3_index = lat_lon_to_h3(lat, lon, resolution=12)

    # Get k-ring (neighboring cells)
    neighbor_cells = h3.k_ring(h3_index, 1)

    # Map to shards
    shards = set()
    for cell in neighbor_cells:
        parent_h3 = h3.h3_to_parent(cell, 3)
        shard = get_shard_for_h3(parent_h3)
        shards.add(shard)

    return list(shards)
```

**Pros:**
- No missed bumps at boundaries
- Queries can be shard-local

**Cons:**
- More storage (duplicate location data)
- More complex consistency

## Implementation

### Router Service (API Gateway)

```python
# router/shard_router.py

import redis
import psycopg2
from h3 import h3

class ShardRouter:
    def __init__(self):
        self.redis = redis.Redis(host='redis', port=6379)
        self.shard_cache = {}
        self._load_shard_mapping()

    def _load_shard_mapping(self):
        """Load shard mapping from Redis"""
        mapping = self.redis.hgetall('shard_mapping')
        for h3_cell, shard_info in mapping.items():
            self.shard_cache[int(h3_cell)] = json.loads(shard_info)

    def get_shard_for_location(self, lat, lon):
        """Get shard ID for a location"""
        h3_index = h3.geo_to_h3(lat, lon, 12)
        h3_res3 = h3.h3_to_parent(h3_index, 3)

        if h3_res3 in self.shard_cache:
            return self.shard_cache[h3_res3]

        # Fallback to default shard
        return self.shard_cache.get('default')

    def get_connection(self, shard_id):
        """Get database connection for a shard"""
        shard_info = self.shard_cache.get(shard_id)
        return psycopg2.connect(
            host=shard_info['host'],
            port=shard_info['port'],
            database=shard_info['database'],
            user=shard_info['user'],
            password=shard_info['password']
        )

    def route_query(self, query_type, params):
        """Route a query to the appropriate shard(s)"""
        if query_type == 'location_update':
            lat, lon = params['latitude'], params['longitude']
            shard = self.get_shard_for_location(lat, lon)
            conn = self.get_connection(shard['shard_id'])

            # Execute insert
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO locations (user_id, latitude, longitude, h3_index) "
                "VALUES (%s, %s, %s, %s)",
                (params['user_id'], lat, lon, params['h3_index'])
            )
            conn.commit()

        elif query_type == 'get_user_bumps':
            user_id = params['user_id']
            home_shard = self.get_user_home_shard(user_id)
            conn = self.get_connection(home_shard)

            cursor = conn.cursor()
            cursor.execute(
                "SELECT * FROM bumps WHERE user1_id = %s OR user2_id = %s",
                (user_id, user_id)
            )
            return cursor.fetchall()

    def get_user_home_shard(self, user_id):
        """Get user's home shard from cache or database"""
        cached = self.redis.hget('user_shards', user_id)
        if cached:
            return cached.decode()

        # Fetch from global registry
        # ... implementation
        return 'default'
```

### Distributed Transactions (2-Phase Commit)

For critical operations that must span shards:

```python
from datetime import datetime

class DistributedTransaction:
    def __init__(self, router):
        self.router = router
        self.participants = []

    def begin(self):
        self.transaction_id = uuid.uuid4()
        self.participants = []

    def add_operation(self, shard_id, operation, params):
        self.participants.append({
            'shard_id': shard_id,
            'operation': operation,
            'params': params,
            'status': 'pending'
        })

    def commit(self):
        """Two-phase commit protocol"""
        # Phase 1: Prepare
        for p in self.participants:
            conn = self.router.get_connection(p['shard_id'])
            cursor = conn.cursor()

            # Execute operation but don't commit
            cursor.execute(p['operation'], p['params'])

            # Check if prepare succeeds
            try:
                cursor.execute("PREPARE TRANSACTION %s", (self.transaction_id,))
                p['status'] = 'prepared'
            except Exception as e:
                p['status'] = 'failed'
                raise DistributedTransactionError(f"Prepare failed: {e}")

        # Phase 2: Commit
        for p in self.participants:
            conn = self.router.get_connection(p['shard_id'])
            cursor = conn.cursor()
            cursor.execute("COMMIT PREPARED %s", (self.transaction_id,))
            p['status'] = 'committed'

        return True

    def rollback(self):
        """Rollback all participants"""
        for p in self.participants:
            if p['status'] in ['prepared', 'failed']:
                conn = self.router.get_connection(p['shard_id'])
                cursor = conn.cursor()
                cursor.execute("ROLLBACK PREPARED %s", (self.transaction_id,))
```

## Migration Strategy

### Phase 1: Setup Sharding Infrastructure (Month 1)

1. **Week 1-2: Deploy Router**
   - Build shard router service
   - Deploy alongside existing database
   - Route all queries through router (single shard initially)

2. **Week 3-4: Create Second Shard**
   - Provision second database instance
   - Configure replication from primary
   - Test failover and routing

### Phase 2: Data Migration (Month 2)

1. **Identify Hot Regions**
   - Analyze user distribution
   - Identify high-traffic H3 cells
   - Plan shard assignments

2. **Migrate Data**
   ```sql
   -- Export data for Shard KR-2 (Busan region)
   COPY (
     SELECT * FROM locations
     WHERE h3_to_parent(h3_index, 3) IN (
       SELECT h3_cell FROM shard_mapping WHERE shard_id = 'KR-2'
     )
   ) TO '/tmp/kr2_locations.csv' CSV;

   -- Import to new shard
   \copy locations FROM '/tmp/kr2_locations.csv' CSV
   ```

3. **Verify Data Integrity**
   - Compare row counts
   - Verify no data loss
   - Test queries on new shard

### Phase 3: Switch Traffic (Month 3)

1. **Gradual Cutover**
   - Route 10% of Busan traffic to KR-2
   - Monitor performance and errors
   - Gradually increase to 100%

2. **Decommission Old Data**
   - After 30 days, delete migrated data from old shard
   - Keep backups for 90 days

## Monitoring & Operations

### Key Metrics Per Shard

1. **Load Distribution**
   - Writes per shard per second
   - Reads per shard per second
   - Storage used per shard

2. **Cross-Shard Operations**
   - % of cross-shard bumps
   - Cross-shard query latency
   - Distributed transaction success rate

3. **Shard Health**
   - Replication lag
   - Connection pool usage
   - Query performance (p50, p95, p99)

### Alerts

- Shard is >80% storage capacity
- Cross-shard queries >10% of total
- Replication lag >10 seconds
- Any shard unavailable

## Cost Analysis

### Current (Single Database)

- 1 × db.r6g.2xlarge (8 vCPU, 64 GB RAM): $600/month
- 1 TB storage: $115/month
- **Total:** ~$715/month

### Sharded (4 Shards)

- 4 × db.r6g.xlarge (4 vCPU, 32 GB RAM): $300/month each = $1,200/month
- 4 × 500 GB storage: $57/month each = $228/month
- Router service: $50/month
- **Total:** ~$1,478/month

**Cost increase:** ~$763/month (+107%)

**But:**
- Can handle 4x traffic
- Better fault isolation
- Easier to scale individual regions
- **Cost per user drops** as you grow

At 400,000 users:
- Single DB would need db.r6g.8xlarge: $2,400/month
- Sharded: Still $1,478/month + maybe 2 more shards = $2,200/month
- **Savings at scale**

## Alternative: Citus (Postgres Sharding Extension)

For simpler management, consider **Citus**:

**Pros:**
- Automatic shard management
- Transparent query routing
- PostgreSQL-native
- Managed service available (Citus Cloud)

**Cons:**
- Additional costs ($$$)
- Learning curve
- Some query limitations

## Next Steps

1. **Month 1:** Deploy router and shard mapping table
2. **Month 2:** Create second shard (test environment)
3. **Month 3:** Migrate 10% of data to second shard
4. **Month 4:** Full production migration
5. **Month 5+:** Add shards as needed based on growth
