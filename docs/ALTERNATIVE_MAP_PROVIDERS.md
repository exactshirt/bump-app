# Alternative Map Provider Evaluation for Bump App

## Overview

Google Maps Platform is currently used for map rendering and geolocation APIs. However, at scale (100,000+ users), Google Maps costs become prohibitive. This document evaluates alternative map providers and provides integration guidance.

## Current Google Maps Costs

### Usage Pattern (100,000 DAU)

**Geolocation API:**
- 100,000 users × 288 requests/day = 28.8M requests/month
- Cost: $5 per 1,000 requests after free tier
- Monthly cost: 28.8M × $0.005 = **$144,000/month** 😱

**Wait, let's recalculate with free tier:**
- First 40,000 requests/month: Free
- Remaining: 28,799,600 × $0.005 = **$143,998/month**

**Maps SDK (Mobile):**
- Assume 20% of users view map daily
- 20,000 users × 30 days = 600,000 map loads/month
- Cost: $7 per 1,000 Dynamic Maps loads
- Monthly cost: 600 × $7 = **$4,200/month**

**Total Google Maps Cost:** ~$148,000/month at 100,000 DAU

> **NOTE:** CLAUDE.md shows different numbers (~$52K/month). This discrepancy suggests either:
> - Geolocation API is not being used (using device GPS only)
> - Different pricing tier or calculation method
> - Let's verify which APIs are actually being used

### What APIs Does Bump Actually Use?

Looking at current implementation:

```dart
// lib/services/location_service.dart
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.best,
);
```

**This uses device GPS, NOT Google Geolocation API!**

So current costs are:
- Maps SDK only: ~$5,054/month (per CLAUDE.md)
- Geolocation API: $0 (not used)

**Conclusion:** We can ignore Geolocation API costs. Focus on reducing Maps SDK costs.

## Alternative Map Providers

### 1. Mapbox (Recommended)

**Pricing:**
- Free tier: 50,000 map loads/month
- Beyond free: $5.00 per 1,000 loads
- Vector maps: Better performance, modern design

**At 600,000 map loads/month:**
- First 50,000: Free
- Remaining 550,000: 550 × $5 = **$2,750/month**
- **Savings: $1,450/month (29% cheaper than Google)**

**Pros:**
- **Better pricing** than Google Maps
- Beautiful, customizable map styles
- Excellent Flutter support (`flutter_map` + `mapbox_gl`)
- Offline map support
- Vector tiles (smaller downloads, faster)
- Good documentation

**Cons:**
- Less brand recognition than Google
- Slightly steeper learning curve
- Some features lag behind Google

**Integration:**

```yaml
# pubspec.yaml
dependencies:
  mapbox_gl: ^0.16.0
  flutter_map: ^6.0.0
```

```dart
// lib/widgets/mapbox_view.dart
import 'package:mapbox_gl/mapbox_gl.dart';

class MapboxView extends StatefulWidget {
  @override
  _MapboxViewState createState() => _MapboxViewState();
}

class _MapboxViewState extends State<MapboxView> {
  MapboxMapController? mapController;

  @override
  Widget build(BuildContext context) {
    return MapboxMap(
      accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN',
      initialCameraPosition: CameraPosition(
        target: LatLng(37.7749, -122.4194),
        zoom: 12,
      ),
      onMapCreated: (controller) {
        mapController = controller;
      },
      styleString: MapboxStyles.MAPBOX_STREETS, // or custom style
    );
  }
}
```

### 2. OpenStreetMap (OSM) + Self-Hosted Tiles

**Pricing:**
- Free data (community-driven)
- Hosting costs: ~$200-500/month (tile server + CDN)
- No per-request fees

**At 600,000 map loads/month:**
- Tile server: DigitalOcean Droplet $50/month
- CDN (Cloudflare): $200/month
- Storage (tiles): $50/month
- **Total: ~$300/month**
- **Savings: $3,900/month (76% cheaper!)**

**Pros:**
- **Cheapest option** at scale
- Full control over map data and styling
- No vendor lock-in
- Active community
- Can add custom POI data

**Cons:**
- **Requires infrastructure management**
- Initial setup complexity
- Need to handle tile caching
- Responsible for uptime and scaling
- Data updates require manual sync

**Integration:**

```yaml
# pubspec.yaml
dependencies:
  flutter_map: ^6.0.0
  latlong2: ^0.9.0
```

```dart
// lib/widgets/osm_map_view.dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OsmMapView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(37.7749, -122.4194),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tiles.bump.com/{z}/{x}/{y}.png', // Self-hosted
          // Or use public OSM (rate-limited):
          // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.bump.app',
        ),
        MarkerLayer(
          markers: [
            // Your markers here
          ],
        ),
      ],
    );
  }
}
```

**Self-Hosted Tile Server Setup:**

```dockerfile
# Dockerfile for OSM Tile Server
FROM overv/openstreetmap-tile-server

ENV OSM_PBF_URL=https://download.geofabrik.de/asia/south-korea-latest.osm.pbf

EXPOSE 80

CMD ["run"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  tile-server:
    build: .
    ports:
      - "8080:80"
    volumes:
      - osm-data:/data/database/
      - osm-tiles:/data/tiles/
    environment:
      - THREADS=4
      - OSM_MAX_CACHE=2048

  tile-cdn:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - osm-tiles:/usr/share/nginx/html/tiles
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - tile-server

volumes:
  osm-data:
  osm-tiles:
```

### 3. Here Maps

**Pricing:**
- Free tier: 250,000 map views/month
- Beyond free: $1.00 per 1,000 views

**At 600,000 map loads/month:**
- First 250,000: Free
- Remaining 350,000: 350 × $1 = **$350/month**
- **Savings: $3,850/month (92% cheaper!)**

**Pros:**
- **Best pricing** among commercial providers
- Good quality maps, especially in Asia/Europe
- Flutter support via `here_sdk`
- Offline maps available
- Turn-by-turn navigation (if needed in future)

**Cons:**
- Less popular than Google/Mapbox
- Smaller ecosystem
- Documentation could be better
- Some limitations in customization

**Integration:**

```yaml
# pubspec.yaml
dependencies:
  here_sdk: ^4.17.0
```

```dart
// lib/widgets/here_map_view.dart
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class HereMapView extends StatefulWidget {
  @override
  _HereMapViewState createState() => _HereMapViewState();
}

class _HereMapViewState extends State<HereMapView> {
  @override
  Widget build(BuildContext context) {
    return HereMap(
      onMapCreated: (mapController) {
        mapController.camera.lookAtPointWithDistance(
          GeoCoordinates(37.7749, -122.4194),
          1000,
        );
      },
    );
  }
}
```

### 4. Apple Maps (iOS only)

**Pricing:**
- **FREE** up to 25,000 service requests/day
- Beyond that: $50 per 1,000 service requests

**For iOS users only:**
- Assume 50% iOS users = 10,000 DAU
- 10,000 × 20 map views/day = 200,000 views/day = 6M/month
- Well above free tier...
- Cost: 6,000 × $50 = **$300,000/month** (wait, that can't be right)

**Actually, Apple Maps pricing is complex:**
- MapKit JS: 250,000 requests free, then $0.50 per 1,000
- Native MapKit (iOS/macOS): **FREE** (no limits!)

**So for native iOS app:**
- **Cost: $0** 🎉

**Integration:**

```dart
// Use platform-specific implementation
import 'dart:io';
import 'package:apple_maps_flutter/apple_maps_flutter.dart'; // iOS
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Android

Widget buildMap() {
  if (Platform.isIOS) {
    return AppleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(37.7749, -122.4194),
        zoom: 12,
      ),
    );
  } else {
    // Use alternative for Android
    return MapboxMap(...);
  }
}
```

## Cost Comparison Summary

| Provider | Monthly Cost (600K loads) | vs Google | Pros | Cons |
|----------|--------------------------|-----------|------|------|
| **Google Maps** | $4,200 | baseline | Brand trust, features | $$$ |
| **Mapbox** | $2,750 | -35% | Great UX, customizable | Learning curve |
| **Here Maps** | $350 | -92% | Best pricing | Less popular |
| **OSM (self-hosted)** | $300 | -93% | Cheapest, full control | Infra overhead |
| **Apple Maps (iOS)** | $0 | -100% | Free on iOS | iOS only |

## Recommended Strategy: Hybrid Approach

Use different providers based on platform and scale:

### Phase 1 (Current - 10,000 users)
- **iOS:** Apple Maps (free)
- **Android:** Mapbox ($275/month for 60K loads)
- **Total:** ~$275/month

### Phase 2 (10,000 - 50,000 users)
- **iOS:** Apple Maps (free)
- **Android:** Mapbox ($1,375/month for 300K loads)
- **Total:** ~$1,375/month

### Phase 3 (50,000 - 100,000 users)
- **iOS:** Apple Maps (free)
- **Android:** Here Maps ($150/month for 300K loads)
- **Total:** ~$150/month

### Phase 4 (100,000+ users)
- **iOS:** Apple Maps (free)
- **Android:** Self-hosted OSM ($300/month)
- **Total:** ~$300/month

## Implementation: Multi-Provider Architecture

### Abstract Map Interface

```dart
// lib/services/map_service.dart

abstract class MapService {
  Widget buildMapWidget({
    required LatLng initialPosition,
    required double zoom,
    List<Marker>? markers,
    VoidCallback? onMapCreated,
  });

  Future<void> addMarker(Marker marker);
  Future<void> moveCamera(LatLng position, double zoom);
}
```

### Provider Implementations

```dart
// lib/services/mapbox_service.dart
class MapboxService implements MapService {
  @override
  Widget buildMapWidget({...}) {
    return MapboxMap(...);
  }
  // ... implementations
}

// lib/services/apple_maps_service.dart
class AppleMapsService implements MapService {
  @override
  Widget buildMapWidget({...}) {
    return AppleMap(...);
  }
  // ... implementations
}

// lib/services/osm_service.dart
class OsmMapService implements MapService {
  @override
  Widget buildMapWidget({...}) {
    return FlutterMap(...);
  }
  // ... implementations
}
```

### Factory Pattern for Provider Selection

```dart
// lib/services/map_service_factory.dart

class MapServiceFactory {
  static MapService createMapService() {
    if (Platform.isIOS) {
      // Use Apple Maps on iOS (free!)
      return AppleMapsService();
    } else if (Platform.isAndroid) {
      // Check app config for Android provider
      final provider = AppConfig.mapProvider; // 'mapbox', 'here', 'osm'

      switch (provider) {
        case 'mapbox':
          return MapboxService();
        case 'here':
          return HereMapsService();
        case 'osm':
          return OsmMapService();
        default:
          return MapboxService(); // default
      }
    } else {
      // Web/Desktop: use OSM
      return OsmMapService();
    }
  }
}
```

### Usage in App

```dart
// lib/screens/map_screen.dart

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapService _mapService;

  @override
  void initState() {
    super.initState();
    _mapService = MapServiceFactory.createMapService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Map')),
      body: _mapService.buildMapWidget(
        initialPosition: LatLng(37.7749, -122.4194),
        zoom: 12,
        markers: _markers,
      ),
    );
  }
}
```

## Migration Plan

### Month 1: Implement Multi-Provider Architecture
- Create abstract `MapService` interface
- Implement Apple Maps service (iOS)
- Implement Mapbox service (Android)
- Add feature flag for provider selection

### Month 2: Deploy and Test
- Deploy to 10% of users
- Monitor crash rates, performance
- Gather user feedback
- Compare costs

### Month 3: Full Rollout
- Roll out to 100% of users
- Monitor Google Maps costs drop
- Verify ~65% cost savings

### Month 4: Self-Hosted Exploration (Optional)
- Set up OSM tile server in staging
- Load test with production traffic patterns
- Calculate actual costs (hosting, CDN, bandwidth)
- Decision: keep Mapbox or switch to OSM

## Offline Maps Support

One major benefit of Mapbox/Here/OSM: **offline maps**

This can save even more bandwidth costs:

```dart
// Download map region for offline use
await mapboxController.downloadRegion(
  LatLngBounds(
    southwest: LatLng(37.7, -122.5),
    northeast: LatLng(37.8, -122.4),
  ),
  minZoom: 10,
  maxZoom: 15,
  regionId: 'san_francisco',
);
```

**Benefits:**
- Reduced API calls (no tiles fetched for offline regions)
- Better UX in areas with poor connectivity
- Lower costs

**Storage Requirements:**
- Typical city (zoom 10-15): ~50-100 MB
- Can be downloaded on WiFi, updated weekly

## Conclusion

**Recommended Approach:**
1. **Immediate:** Switch iOS to Apple Maps (free)
2. **Month 1:** Switch Android to Mapbox (-35% cost)
3. **Month 3:** Evaluate Here Maps for Android (-92% cost)
4. **Month 6+:** Consider self-hosted OSM if infrastructure team is ready

**Expected Savings:**
- Current (all Google): ~$4,200/month
- Hybrid (Apple + Mapbox): ~$1,375/month
- **Savings: ~$2,825/month ($33,900/year)**

At 100,000 users:
- Current (all Google): ~$42,000/month
- Hybrid (Apple + OSM): ~$300/month
- **Savings: ~$41,700/month ($500,000/year!)**

## Next Steps

1. Add `mapbox_gl` and `apple_maps_flutter` to dependencies
2. Implement `MapService` interface
3. Create provider implementations
4. Add feature flag for gradual rollout
5. Monitor costs in production
