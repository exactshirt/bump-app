# Redis Caching Layer Setup Guide

## Overview

This document outlines the Redis caching strategy for the Bump app to reduce database load by 70-90% and improve query response times.

## Architecture

```
Flutter App → Supabase Edge Functions → Redis Cache → PostgreSQL Database
```

### Cache Strategy

1. **Location Data Caching**
   - Cache recent location updates (last 5-10 minutes) in Redis
   - Key pattern: `location:{user_id}` → `{lat, lon, timestamp, h3_index}`
   - TTL: 10 minutes
   - Purpose: Fast retrieval for bump detection without database queries

2. **Bump Detection Results Caching**
   - Cache bump detection results to avoid repeated spatial queries
   - Key pattern: `bumps:{user_id}` → Set of user IDs within range
   - TTL: 5 minutes
   - Purpose: Reduce PostGIS query load

3. **Active Users Index**
   - Maintain a sorted set of active users by last update timestamp
   - Key pattern: `active_users` → Sorted Set (user_id, timestamp)
   - TTL: Individual user entries expire after 10 minutes
   - Purpose: Quick lookup of currently active users

## Redis Data Structures

### 1. User Location Hash
```redis
HSET location:{user_id} lat {latitude}
HSET location:{user_id} lon {longitude}
HSET location:{user_id} h3_index {h3_index}
HSET location:{user_id} timestamp {unix_timestamp}
EXPIRE location:{user_id} 600  # 10 minutes
```

### 2. Active Users Sorted Set
```redis
ZADD active_users {unix_timestamp} {user_id}
ZREMRANGEBYSCORE active_users 0 {current_time - 600}  # Remove stale entries
```

### 3. H3 Cell Index
```redis
# Store users by H3 cell for fast proximity lookup
SADD h3:{h3_index} {user_id}
EXPIRE h3:{h3_index} 600
```

### 4. Recent Bumps Cache
```redis
# Cache bump relationships to prevent duplicate detection
SADD recent_bumps:{user1_id} {user2_id}
EXPIRE recent_bumps:{user1_id} 3600  # 1 hour
```

## Supabase Edge Function Implementation

### Function: `update_location_with_cache`

```typescript
// supabase/functions/update_location_with_cache/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { connect } from "https://deno.land/x/redis@v0.29.0/mod.ts"

const redis = await connect({
  hostname: Deno.env.get('REDIS_HOSTNAME')!,
  port: parseInt(Deno.env.get('REDIS_PORT')!),
  password: Deno.env.get('REDIS_PASSWORD'),
})

serve(async (req) => {
  const { user_id, latitude, longitude, h3_index } = await req.json()
  const timestamp = Date.now()

  try {
    // 1. Write to Redis cache
    await redis.hset(`location:${user_id}`, {
      lat: latitude.toString(),
      lon: longitude.toString(),
      h3_index: h3_index.toString(),
      timestamp: timestamp.toString()
    })
    await redis.expire(`location:${user_id}`, 600)

    // 2. Update active users index
    await redis.zadd('active_users', timestamp, user_id)

    // 3. Add to H3 cell index
    await redis.sadd(`h3:${h3_index}`, user_id)
    await redis.expire(`h3:${h3_index}`, 600)

    // 4. Async write to database (fire-and-forget)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Don't await - let it complete in background
    supabase.from('locations').insert({
      user_id,
      latitude,
      longitude,
      h3_index,
      timestamp: new Date(timestamp).toISOString()
    })

    return new Response(
      JSON.stringify({ success: true, cached: true }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})
```

### Function: `find_nearby_users_cached`

```typescript
// supabase/functions/find_nearby_users_cached/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { connect } from "https://deno.land/x/redis@v0.29.0/mod.ts"
import { h3 } from "https://esm.sh/h3-js@4.1.0"

const redis = await connect({
  hostname: Deno.env.get('REDIS_HOSTNAME')!,
  port: parseInt(Deno.env.get('REDIS_PORT')!),
  password: Deno.env.get('REDIS_PASSWORD'),
})

serve(async (req) => {
  const { user_id } = await req.json()

  try {
    // 1. Get user's current location from Redis
    const userLocation = await redis.hgetall(`location:${user_id}`)
    if (!userLocation || !userLocation.h3_index) {
      return new Response(
        JSON.stringify({ error: 'User location not found in cache' }),
        { status: 404 }
      )
    }

    const currentH3 = parseInt(userLocation.h3_index)
    const lat = parseFloat(userLocation.lat)
    const lon = parseFloat(userLocation.lon)

    // 2. Get k-ring of H3 cells (current + neighbors)
    const kRing = h3.gridDisk(currentH3, 1)  // 1-ring radius

    // 3. Get all users in these H3 cells from Redis
    const nearbyUserIds = new Set()
    for (const h3Index of kRing) {
      const users = await redis.smembers(`h3:${h3Index}`)
      users.forEach(uid => {
        if (uid !== user_id) nearbyUserIds.add(uid)
      })
    }

    // 4. Filter by actual distance and check for recent bumps
    const bumps = []
    for (const nearbyUserId of nearbyUserIds) {
      // Check if already bumped recently
      const alreadyBumped = await redis.sismember(
        `recent_bumps:${user_id}`,
        nearbyUserId
      )
      if (alreadyBumped) continue

      // Get nearby user's location
      const nearbyLocation = await redis.hgetall(`location:${nearbyUserId}`)
      if (!nearbyLocation) continue

      const nearbyLat = parseFloat(nearbyLocation.lat)
      const nearbyLon = parseFloat(nearbyLocation.lon)

      // Calculate distance (simplified haversine)
      const distance = calculateDistance(lat, lon, nearbyLat, nearbyLon)

      if (distance <= 30) {  // 30 meters threshold
        // Record bump in cache
        await redis.sadd(`recent_bumps:${user_id}`, nearbyUserId)
        await redis.sadd(`recent_bumps:${nearbyUserId}`, user_id)
        await redis.expire(`recent_bumps:${user_id}`, 3600)
        await redis.expire(`recent_bumps:${nearbyUserId}`, 3600)

        // Store in database
        const supabase = createClient(
          Deno.env.get('SUPABASE_URL')!,
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        const { data: bump } = await supabase.from('bumps').insert({
          user1_id: user_id,
          user2_id: nearbyUserId,
          bumped_at: new Date().toISOString()
        }).select().single()

        bumps.push(bump)
      }
    }

    return new Response(
      JSON.stringify({ bumps, cache_hit: true }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371e3 // Earth radius in meters
  const φ1 = lat1 * Math.PI / 180
  const φ2 = lat2 * Math.PI / 180
  const Δφ = (lat2 - lat1) * Math.PI / 180
  const Δλ = (lon2 - lon1) * Math.PI / 180

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ / 2) * Math.sin(Δλ / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  return R * c
}
```

## Redis Hosting Options

### Option 1: Upstash (Recommended for Supabase Integration)
- **URL**: https://upstash.com
- **Pricing**: Free tier includes 10,000 commands/day
- **Integration**: Works seamlessly with Deno Edge Functions
- **Setup**:
  1. Create Upstash account
  2. Create Redis database
  3. Copy endpoint URL and password
  4. Add to Supabase secrets: `REDIS_HOSTNAME`, `REDIS_PORT`, `REDIS_PASSWORD`

### Option 2: Redis Cloud
- **URL**: https://redis.com/cloud
- **Pricing**: Free tier includes 30MB
- **Features**: More storage, better monitoring

### Option 3: Self-hosted
- Deploy Redis on DigitalOcean, AWS, or similar
- Use managed Redis service for production reliability

## Flutter App Changes

Update `LocationService` to call Supabase Edge Function instead of direct database write:

```dart
// lib/services/location_service.dart

Future<void> _saveCurrentLocation(String userId) async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    // Calculate H3 index (requires h3_flutter package)
    final h3Index = h3.geoToH3(position.latitude, position.longitude, 12);

    // Call Supabase Edge Function with cache
    final supabase = Supabase.instance.client;
    await supabase.functions.invoke(
      'update_location_with_cache',
      body: {
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'h3_index': h3Index,
      },
    );

    print('Location saved to cache: (${position.latitude}, ${position.longitude})');
  } catch (e) {
    print('Location save error: $e');
  }
}
```

## Monitoring & Metrics

### Key Metrics to Track

1. **Cache Hit Rate**
   - Target: > 80%
   - Measure: `cache_hits / (cache_hits + cache_misses)`

2. **Redis Memory Usage**
   - Monitor with `INFO memory` command
   - Set alerts at 80% capacity

3. **Query Response Time**
   - Before caching: ~200-500ms (database query)
   - After caching: ~10-50ms (Redis lookup)
   - Target improvement: 5-10x faster

4. **Database Load Reduction**
   - Measure writes/sec before and after
   - Target: 70-90% reduction in read queries

## Cost Analysis

### 10,000 Active Users

**Without Redis:**
- Database reads: ~86.4M/day
- Cost: High database compute tier required

**With Redis:**
- Database reads: ~8.6M/day (90% reduction)
- Redis operations: ~95M/day
- Total cost: ~$50/month (Upstash Pro) + Lower DB tier
- **Savings**: ~$100-150/month in database costs

## Rollout Strategy

### Phase 1: Testing (Week 1-2)
- Deploy to staging environment
- Test with 100 beta users
- Monitor cache hit rates and error rates

### Phase 2: Gradual Rollout (Week 3-4)
- Enable for 10% of users
- Monitor performance and costs
- Adjust TTL values based on usage patterns

### Phase 3: Full Deployment (Week 5)
- Roll out to all users
- Keep database fallback for cache misses
- Monitor and optimize

## Fallback Strategy

Always maintain database as source of truth:

1. **Cache Miss**: Fall back to database query
2. **Redis Down**: All queries go to database
3. **Stale Data**: Background job syncs Redis with DB every 5 minutes

## Next Steps

1. Set up Upstash Redis account
2. Deploy Edge Functions to Supabase
3. Update Flutter app to use Edge Functions
4. Monitor and optimize TTL values
5. Scale Redis tier as user base grows
