# Message Queue Architecture for Bump App

## Overview

As the Bump app scales beyond 100,000 active users, synchronous processing of location updates and bump detection becomes a bottleneck. This document outlines the message queue architecture to enable asynchronous batch processing, improving system resilience and performance.

## Problem Statement

### Current Limitations

**Synchronous Processing:**
- Location updates block until database write completes
- Bump detection runs synchronously, delaying response to client
- Server resources are tied up waiting for I/O operations
- No retry mechanism for failed operations
- Limited ability to handle traffic spikes

**Scaling Challenges:**
- 100,000 users × 288 updates/day = 28.8M location updates/day
- Peak hours can see 10x normal traffic
- Database can become overwhelmed during spikes
- No backpressure mechanism to handle load

## Solution: Message Queue Architecture

### Architecture Overview

```
┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────┐
│ Supabase Edge   │
│   Function      │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐      ┌──────────────┐
│  Message Queue  │─────▶│   Workers    │
│   (RabbitMQ)    │      │  (Multiple)  │
└─────────────────┘      └──────┬───────┘
                                │
                                ▼
                         ┌──────────────┐
                         │  PostgreSQL  │
                         │   + Redis    │
                         └──────────────┘
```

### Components

1. **API Layer (Supabase Edge Functions)**
   - Receives location updates from clients
   - Validates and normalizes data
   - Publishes messages to queue
   - Returns immediate acknowledgment to client

2. **Message Queue (RabbitMQ or AWS SQS)**
   - Buffers incoming location updates
   - Provides durability and persistence
   - Enables load balancing across workers
   - Supports retry and dead letter queues

3. **Worker Processes**
   - Consume messages from queue
   - Process location updates in batches
   - Run bump detection algorithms
   - Update database and cache

4. **Storage Layer**
   - Redis: Hot cache for recent data
   - PostgreSQL: Persistent storage

## Message Queue Options

### Option 1: RabbitMQ (Recommended for Self-Hosted)

**Pros:**
- Open source and mature
- Feature-rich (routing, priority queues, etc.)
- Good monitoring tools (Management UI)
- Supports multiple messaging patterns
- Can run on-premise or cloud

**Cons:**
- Requires infrastructure management
- More complex setup than managed services

**Setup:**
```bash
# Docker Compose for RabbitMQ
version: '3.8'
services:
  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "5672:5672"    # AMQP port
      - "15672:15672"  # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: bump_user
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  rabbitmq_data:
```

**Cost (Cloud Provider):**
- CloudAMQP: $19/month for 1M messages
- AWS RabbitMQ (managed): ~$50/month

### Option 2: AWS SQS (Recommended for AWS Infrastructure)

**Pros:**
- Fully managed, no infrastructure
- Auto-scaling built-in
- Pay-per-use pricing
- Integrates with Lambda functions

**Cons:**
- Vendor lock-in
- Limited message size (256 KB)
- Eventual consistency

**Cost:**
- Free tier: 1M requests/month
- Beyond free tier: $0.40 per 1M requests
- At 30M requests/month: ~$12/month

### Option 3: Google Cloud Pub/Sub

**Pros:**
- Fully managed
- Global distribution
- At-least-once delivery
- Good for multi-region deployments

**Cost:**
- $0.40 per 1M messages
- At 30M messages/month: ~$12/month

## Message Schema

### Location Update Message

```json
{
  "message_type": "location_update",
  "message_id": "uuid",
  "timestamp": "2025-11-19T10:30:00Z",
  "user_id": "uuid",
  "location": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 10.5,
    "altitude": 15.0,
    "h3_index": 622203845394604031
  },
  "metadata": {
    "client_version": "1.2.0",
    "platform": "ios"
  }
}
```

### Bump Detection Job Message

```json
{
  "message_type": "bump_detection",
  "message_id": "uuid",
  "timestamp": "2025-11-19T10:35:00Z",
  "trigger_type": "periodic", // or "on_demand"
  "h3_cells": [622203845394604031, 622203845394604032],
  "time_window": {
    "start": "2025-11-19T10:30:00Z",
    "end": "2025-11-19T10:35:00Z"
  }
}
```

## Worker Implementation

### Python Worker (using Celery)

```python
# workers/location_worker.py

from celery import Celery
import redis
import psycopg2
from h3 import h3

# Initialize Celery
celery_app = Celery(
    'bump_workers',
    broker='amqp://bump_user:password@rabbitmq:5672//',
    backend='redis://redis:6379/0'
)

# Redis connection
redis_client = redis.Redis(host='redis', port=6379, db=0)

# PostgreSQL connection
pg_conn = psycopg2.connect(
    host="postgres",
    database="bump_db",
    user="postgres",
    password="password"
)

@celery_app.task(name='process_location_update', max_retries=3)
def process_location_update(message):
    """
    Process a single location update message
    """
    try:
        user_id = message['user_id']
        location = message['location']
        timestamp = message['timestamp']

        # 1. Update Redis cache (hot data)
        redis_client.hset(
            f"location:{user_id}",
            mapping={
                'lat': location['latitude'],
                'lon': location['longitude'],
                'h3_index': location['h3_index'],
                'timestamp': timestamp
            }
        )
        redis_client.expire(f"location:{user_id}", 600)  # 10 min TTL

        # 2. Add to H3 cell index
        redis_client.sadd(f"h3:{location['h3_index']}", user_id)
        redis_client.expire(f"h3:{location['h3_index']}", 600)

        # 3. Async write to PostgreSQL (batch this for efficiency)
        cursor = pg_conn.cursor()
        cursor.execute(
            """
            INSERT INTO locations (user_id, latitude, longitude, h3_index, timestamp)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (user_id, location['latitude'], location['longitude'],
             location['h3_index'], timestamp)
        )
        pg_conn.commit()

        return {'status': 'success', 'user_id': user_id}

    except Exception as e:
        # Log error and retry
        print(f"Error processing location update: {e}")
        raise process_location_update.retry(exc=e, countdown=60)


@celery_app.task(name='process_bump_detection_batch')
def process_bump_detection_batch(message):
    """
    Process bump detection for a batch of H3 cells
    """
    try:
        h3_cells = message['h3_cells']
        time_window = message['time_window']
        bumps_detected = []

        for h3_cell in h3_cells:
            # Get all users in this H3 cell from Redis
            user_ids = redis_client.smembers(f"h3:{h3_cell}")

            # Get neighboring cells (k-ring)
            neighbors = h3.k_ring(h3_cell, 1)

            # Check for bumps within this cell and neighbors
            for user_id in user_ids:
                nearby_bumps = detect_bumps_for_user(
                    user_id, neighbors, time_window
                )
                bumps_detected.extend(nearby_bumps)

        # Batch insert bumps to database
        if bumps_detected:
            insert_bumps_batch(bumps_detected)

        return {
            'status': 'success',
            'bumps_detected': len(bumps_detected)
        }

    except Exception as e:
        print(f"Error in bump detection: {e}")
        raise process_bump_detection_batch.retry(exc=e, countdown=120)


def detect_bumps_for_user(user_id, h3_cells, time_window):
    """
    Detect bumps for a single user within given H3 cells
    """
    bumps = []
    user_loc = redis_client.hgetall(f"location:{user_id}")

    if not user_loc:
        return bumps

    user_lat = float(user_loc[b'lat'])
    user_lon = float(user_loc[b'lon'])

    # Check each neighboring cell
    for cell in h3_cells:
        nearby_users = redis_client.smembers(f"h3:{cell}")

        for nearby_user_id in nearby_users:
            if nearby_user_id == user_id:
                continue

            # Check if already bumped recently
            if redis_client.sismember(f"recent_bumps:{user_id}", nearby_user_id):
                continue

            # Get nearby user location
            nearby_loc = redis_client.hgetall(f"location:{nearby_user_id}")
            if not nearby_loc:
                continue

            nearby_lat = float(nearby_loc[b'lat'])
            nearby_lon = float(nearby_loc[b'lon'])

            # Calculate distance
            distance = calculate_distance(
                user_lat, user_lon, nearby_lat, nearby_lon
            )

            # If within 30 meters, record bump
            if distance <= 30:
                bumps.append({
                    'user1_id': user_id,
                    'user2_id': nearby_user_id,
                    'distance': distance,
                    'timestamp': time_window['end']
                })

                # Mark as recent bump (1 hour TTL)
                redis_client.sadd(f"recent_bumps:{user_id}", nearby_user_id)
                redis_client.expire(f"recent_bumps:{user_id}", 3600)

    return bumps


def insert_bumps_batch(bumps):
    """
    Batch insert bumps to PostgreSQL
    """
    cursor = pg_conn.cursor()
    values = [
        (b['user1_id'], b['user2_id'], b['timestamp'])
        for b in bumps
    ]

    cursor.executemany(
        """
        INSERT INTO bumps (user1_id, user2_id, bumped_at)
        VALUES (%s, %s, %s)
        ON CONFLICT DO NOTHING
        """,
        values
    )
    pg_conn.commit()


def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate distance between two coordinates using Haversine formula
    """
    from math import radians, sin, cos, sqrt, atan2

    R = 6371e3  # Earth radius in meters

    φ1 = radians(lat1)
    φ2 = radians(lat2)
    Δφ = radians(lat2 - lat1)
    Δλ = radians(lon2 - lon1)

    a = sin(Δφ/2)**2 + cos(φ1) * cos(φ2) * sin(Δλ/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))

    return R * c
```

### Worker Deployment

```dockerfile
# Dockerfile for Worker
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy worker code
COPY workers/ .

# Run Celery worker
CMD ["celery", "-A", "location_worker", "worker", \
     "--loglevel=info", "--concurrency=4"]
```

```yaml
# requirements.txt
celery==5.3.4
redis==5.0.1
psycopg2-binary==2.9.9
h3==3.7.6
```

### Kubernetes Deployment

```yaml
# k8s/celery-worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bump-location-worker
spec:
  replicas: 5  # Scale based on load
  selector:
    matchLabels:
      app: bump-worker
  template:
    metadata:
      labels:
        app: bump-worker
    spec:
      containers:
      - name: worker
        image: bump-app/location-worker:latest
        env:
        - name: RABBITMQ_HOST
          value: "rabbitmq-service"
        - name: REDIS_HOST
          value: "redis-service"
        - name: POSTGRES_HOST
          value: "postgres-service"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bump-worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bump-location-worker
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Monitoring & Observability

### Key Metrics

1. **Queue Metrics**
   - Queue depth (messages waiting)
   - Message processing rate (msgs/sec)
   - Message latency (time in queue)
   - Dead letter queue size

2. **Worker Metrics**
   - Worker utilization (%)
   - Task success rate
   - Task failure rate
   - Average task duration

3. **System Metrics**
   - Redis cache hit rate
   - Database write throughput
   - End-to-end latency (client → database)

### Monitoring Tools

**Prometheus + Grafana:**
```yaml
# Expose Celery metrics to Prometheus
from celery.signals import task_success, task_failure
from prometheus_client import Counter, Histogram

task_success_counter = Counter(
    'celery_task_success_total',
    'Total successful tasks',
    ['task_name']
)

task_duration = Histogram(
    'celery_task_duration_seconds',
    'Task execution time',
    ['task_name']
)

@task_success.connect
def task_success_handler(sender=None, **kwargs):
    task_success_counter.labels(task_name=sender.name).inc()
```

**RabbitMQ Management Dashboard:**
- Built-in UI at http://localhost:15672
- Shows queue depth, throughput, connections

## Deployment Strategy

### Phase 1: Hybrid Mode (Week 1-2)
- Deploy message queue alongside existing sync system
- Route 10% of traffic through queue
- Monitor performance and errors
- Keep sync system as fallback

### Phase 2: Gradual Migration (Week 3-4)
- Increase to 50% traffic through queue
- Optimize worker count based on load
- Fine-tune batch sizes and intervals

### Phase 3: Full Migration (Week 5+)
- Route 100% traffic through queue
- Deprecate sync endpoints
- Scale workers to handle peak load

## Cost Analysis

### 100,000 Active Users

**Message Volume:**
- Location updates: 28.8M/day = 864M/month
- Bump detection jobs: 288K/day = 8.6M/month
- Total: ~873M messages/month

**AWS SQS Cost:**
- $0.40 per 1M requests
- 873M × $0.40 = ~$350/month

**Worker Infrastructure (AWS EC2):**
- 5 × t3.medium instances = $150/month
- Or Lambda: ~$200/month for event-driven

**Total Additional Cost:** ~$500-550/month

**Benefits:**
- 99.9% uptime (vs. 95% with sync)
- Handle 10x traffic spikes
- Reduced database load = save $200/month
- **Net cost:** ~$300/month

## Disaster Recovery

### Failure Scenarios

1. **Queue Failure**
   - Fallback: Direct database writes (temporary)
   - Alert: PagerDuty notification
   - Recovery: Auto-restart queue service

2. **Worker Failure**
   - Messages remain in queue
   - Auto-scaling brings up new workers
   - Messages are reprocessed

3. **Database Failure**
   - Workers pause consumption
   - Messages accumulate in queue
   - Resume when database recovers

### Data Durability

- RabbitMQ persistent queues (writes to disk)
- SQS: 99.9999999% durability
- Redis AOF persistence enabled
- PostgreSQL WAL replication

## Next Steps

1. **Week 1:** Set up RabbitMQ/SQS in staging
2. **Week 2:** Implement Python workers
3. **Week 3:** Deploy to staging, load test
4. **Week 4:** Gradual production rollout
5. **Week 5:** Monitor, optimize, scale
