# CLAUDE.md - Bump App Development Guide

## Project Overview

**Bump App** is a Flutter-based mobile application that enables location-based social encounters. The app tracks users' locations in real-time and detects when two users are within close proximity (30 meters), creating a "Bump" event that represents a physical encounter.

**Primary Purpose**: Facilitate spontaneous real-world connections by detecting when users are physically near each other.

**Project Type**: Cross-platform mobile app (iOS, Android, Web, macOS, Linux, Windows)

**Repository**: exactshirt/bump-app
**Primary Branch**: `main`
**Development Branch Pattern**: `claude/claude-md-*` for AI-assisted development

## Technology Stack

### Frontend
- **Flutter SDK**: ^3.10.0
- **Dart**: ^3.10.0
- **State Management**: Built-in Flutter StatefulWidget
- **UI**: Material Design 3

### Backend & Services
- **Supabase**: Backend-as-a-Service
  - PostgreSQL database with PostGIS extension
  - Real-time subscriptions
  - Authentication (configured but not yet implemented)
  - RESTful API (auto-generated)
- **Production URL**: `https://uilmcneizmsqiercrlrt.supabase.co`

### Key Dependencies
```yaml
dependencies:
  supabase_flutter: ^2.10.3      # Supabase client
  google_maps_flutter: ^2.14.0   # Map integration
  geolocator: ^14.0.2            # Location services
  permission_handler: ^12.0.1    # Runtime permissions
  cupertino_icons: ^1.0.8        # iOS-style icons

dev_dependencies:
  flutter_test: sdk              # Testing framework
  flutter_lints: ^6.0.0          # Linting rules
  supabase: ^2.58.5              # Supabase CLI tools
```

## Architecture

### Project Structure

```
bump-app/
├── lib/
│   ├── main.dart              # App entry point, Supabase initialization
│   ├── models/
│   │   └── bump.dart          # Bump data model
│   └── services/
│       ├── location_service.dart  # Location tracking & persistence
│       └── bump_service.dart      # Bump detection logic
├── test/
│   └── widget_test.dart       # Widget tests (needs updating)
├── supabase/
│   ├── config.toml            # Local Supabase configuration
│   └── functions/
│       └── find_nearby_users.sql  # PostGIS proximity detection
├── android/                   # Android-specific configuration
├── ios/                       # iOS-specific configuration
├── web/                       # Web platform support
├── macos/                     # macOS desktop support
├── linux/                     # Linux desktop support
├── windows/                   # Windows desktop support
└── pubspec.yaml               # Flutter dependencies
```

### Service Layer Architecture

#### 1. LocationService (`lib/services/location_service.dart`)

**Singleton Pattern**: Ensures single instance across the app.

**Responsibilities**:
- Request and manage location permissions
- Track user location at 5-second intervals
- Persist location data to Supabase `locations` table
- Manage location tracking lifecycle (start/stop)
- Provide one-time location queries
- Clean up old location data (24-hour retention)

**Key Methods**:
```dart
Future<bool> requestLocationPermission()
Future<void> startLocationTracking(String userId)
void stopLocationTracking()
Future<Position?> getCurrentLocation()
Future<void> deleteOldLocationData(String userId)
```

**Implementation Details**:
- Uses `Timer.periodic` with 5-second intervals
- Stores: latitude, longitude, accuracy, altitude, timestamp
- Requires `userId` for data association
- Auto-cleanup after 24 hours (manual trigger)

#### 2. BumpService (`lib/services/bump_service.dart`)

**Responsibilities**:
- Detect nearby users using PostGIS spatial queries
- Create Bump records for proximity encounters
- Prevent duplicate Bumps within time windows

**Key Methods**:
```dart
Future<List<Bump>> findBumps(String userId)
```

**Implementation Details**:
- Calls Supabase RPC function `find_nearby_users`
- Default proximity threshold: 30 meters
- Duplicate prevention window: 1 hour
- Returns list of newly created Bumps

### Data Models

#### Bump Model (`lib/models/bump.dart`)
```dart
class Bump {
  final String id;          // UUID
  final String user1Id;     // First user UUID
  final String user2Id;     // Second user UUID
  final DateTime bumpedAt;  // Timestamp of bump
}
```

## Database Schema

### Supabase Tables

#### `locations` Table
```sql
CREATE TABLE locations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accuracy DOUBLE PRECISION,
  altitude DOUBLE PRECISION,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  location GEOGRAPHY(Point, 4326) -- PostGIS geometry column
);

-- Index for spatial queries
CREATE INDEX idx_locations_geography ON locations USING GIST(location);
CREATE INDEX idx_locations_user_timestamp ON locations(user_id, timestamp DESC);
```

#### `bumps` Table
```sql
CREATE TABLE bumps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL,
  user2_id UUID NOT NULL,
  bumped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Note: Original column name was 'timestamp' but renamed to 'bumped_at'
  -- to avoid PostgreSQL reserved word conflict
);

CREATE INDEX idx_bumps_users ON bumps(user1_id, user2_id);
CREATE INDEX idx_bumps_timestamp ON bumps(bumped_at);
```

### Database Functions

#### `find_nearby_users()` - PostGIS Proximity Detection

**Location**: `supabase/functions/find_nearby_users.sql`

**Function Signature**:
```sql
CREATE OR REPLACE FUNCTION find_nearby_users(
    current_user_id UUID,
    distance_meters FLOAT,
    time_interval_hours INT
)
RETURNS TABLE (
    bump_id UUID,
    user1_id UUID,
    user2_id UUID,
    bumped_at TIMESTAMPTZ
)
```

**Algorithm**:
1. Retrieve current user's latest location
2. Use PostGIS `ST_DWithin` to find users within specified distance
3. Check for existing Bumps within time interval to prevent duplicates
4. Insert new Bump records for unique encounters
5. Return newly created Bumps

**Key Features**:
- Spatial indexing with PostGIS GIST
- Atomic operations with CTE (Common Table Expressions)
- Bidirectional duplicate prevention (user1↔user2)
- Configurable distance and time thresholds

## Platform Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

**Permissions Required**:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

**Configuration**:
- Google Maps API Key: Configured in `meta-data`
- Clear text traffic enabled for local development
- Foreground service support for background location tracking

### iOS (`ios/Runner/Info.plist`)

**Location Permission Descriptions** (Korean):
- `NSLocationWhenInUseUsageDescription`: In-app location usage
- `NSLocationAlwaysAndWhenInUseUsageDescription`: Background location usage
- `NSLocationAlwaysUsageDescription`: Always-on location access
- Google Maps API Key: Configured in plist

**Privacy Compliance**:
- Explicit user-facing explanations for location access
- 24-hour data retention policy mentioned in permissions
- Background location justified for Bump detection

## Development Workflows

### Local Development Setup

1. **Install Flutter SDK** (v3.10.0+)
   ```bash
   flutter doctor
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   npm install  # For Supabase CLI
   ```

3. **Configure Supabase** (Optional for local dev)
   ```bash
   npx supabase start
   ```

4. **Run the App**
   ```bash
   flutter run
   # Or for specific device:
   flutter run -d android
   flutter run -d ios
   ```

### Testing Workflow

**Current Test Status**: Widget tests are outdated (still testing counter increment)

**Required Test Updates**:
- Update `test/widget_test.dart` to test actual Bump app functionality
- Add unit tests for LocationService
- Add unit tests for BumpService
- Add integration tests for Bump detection flow

**Running Tests**:
```bash
flutter test
```

### Git Workflow

**Branch Naming Conventions**:
- `main`: Production-ready code
- `feature/*`: Feature development branches
- `claude/claude-md-*`: AI-assisted development branches
- `fix/*`: Bug fixes

**Commit Message Format**:
```
<type>: <subject>

Examples:
feat: Implement location tracking service with Supabase integration
fix: Rename timestamp to bumped_at to avoid PostgreSQL reserved word conflict
docs: Add comprehensive CLAUDE.md development guide
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### Code Review Checklist

- [ ] Location permissions properly requested before tracking
- [ ] No sensitive data (API keys) hardcoded in production code
- [ ] Location tracking properly stopped on dispose
- [ ] Error handling for network failures
- [ ] Null safety maintained throughout
- [ ] Korean UI strings properly handled (currently hardcoded)
- [ ] PostGIS spatial queries use proper indexes
- [ ] Bump deduplication logic tested

## Coding Conventions

### Dart/Flutter Conventions

1. **Null Safety**: Strict null safety enabled (SDK ^3.10.0)
   ```dart
   Position? position = await _locationService.getCurrentLocation();
   if (position != null) {
     // Use position safely
   }
   ```

2. **Async/Await**: Preferred over raw Futures
   ```dart
   Future<void> _startTracking() async {
     try {
       await _locationService.startLocationTracking(userId);
     } catch (e) {
       // Handle error
     }
   }
   ```

3. **Singleton Pattern**: Use for services
   ```dart
   class LocationService {
     static final LocationService _instance = LocationService._internal();
     factory LocationService() => _instance;
     LocationService._internal();
   }
   ```

4. **Documentation**: Use /// for public APIs
   ```dart
   /// 위치 추적 시작
   ///
   /// 5초 간격으로 위치를 가져오고 Supabase에 저장합니다.
   Future<void> startLocationTracking(String userId) async { }
   ```

5. **State Management**: Use StatefulWidget for now
   - Consider Provider/Riverpod for complex state in future

6. **Naming Conventions**:
   - Private members: `_variableName`, `_methodName()`
   - Constants: `kConstantName` or `CONSTANT_NAME`
   - Files: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Methods: `camelCase`

### SQL Conventions

1. **Reserved Words**: Avoid PostgreSQL reserved words
   - `timestamp` → `bumped_at` (learned from PR #4)

2. **Spatial Queries**: Use PostGIS functions consistently
   ```sql
   ST_DWithin(location1, location2, distance_meters)
   ```

3. **Indexes**: Always index spatial and temporal columns
   ```sql
   CREATE INDEX idx_locations_geography ON locations USING GIST(location);
   ```

## Security Considerations

### Current Security Issues (TO BE ADDRESSED)

⚠️ **CRITICAL**: The following security issues exist in the current codebase:

1. **API Keys in Source Code**:
   - Supabase URL and anon key in `lib/main.dart:11-13`
   - Google Maps API key in `android/app/src/main/AndroidManifest.xml:44`
   - Google Maps API key in `ios/Runner/Info.plist:22`

   **Required Action**: Move to environment variables or secure storage
   ```dart
   // TODO: Use flutter_dotenv or similar
   await Supabase.initialize(
     url: const String.fromEnvironment('SUPABASE_URL'),
     anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
   );
   ```

2. **Hardcoded Test User ID**:
   - `const userId = 'test-user-123'` in `lib/main.dart:85,137`

   **Required Action**: Implement Supabase authentication
   ```dart
   final userId = Supabase.instance.client.auth.currentUser?.id;
   ```

3. **Row Level Security (RLS)**:
   - Not yet implemented in Supabase tables

   **Required Action**: Add RLS policies
   ```sql
   ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
   ALTER TABLE bumps ENABLE ROW LEVEL SECURITY;

   CREATE POLICY "Users can only see their own locations"
     ON locations FOR SELECT
     USING (auth.uid() = user_id);
   ```

### Security Best Practices

1. **Location Data**:
   - Implement automatic 24-hour data deletion (currently manual)
   - Never expose exact locations to other users
   - Use spatial queries only for proximity detection

2. **API Security**:
   - Implement authentication before production
   - Use Supabase RLS for data access control
   - Rate limit Bump detection to prevent abuse

3. **Privacy Compliance**:
   - Clearly communicate 24-hour data retention
   - Provide opt-out mechanisms
   - Allow users to delete their data on demand

## Feature Implementation Guide

### Adding a New Feature

When implementing new features, follow this pattern:

1. **Model Layer**: Create data model in `lib/models/`
2. **Service Layer**: Implement business logic in `lib/services/`
3. **Database Layer**: Add tables/functions in `supabase/`
4. **UI Layer**: Create widgets in `lib/` or organized subdirectories
5. **Testing**: Add tests in `test/`

### Example: Adding User Authentication

```dart
// 1. Create service
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<User?> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
  }
}

// 2. Update LocationService to use authenticated user
Future<void> startLocationTracking() async {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) throw Exception('User not authenticated');
  // ... rest of implementation
}

// 3. Add UI for sign-in flow
```

## Common Patterns

### Location Permission Pattern
```dart
bool hasPermission = await _locationService.requestLocationPermission();
if (!hasPermission) {
  // Show error message
  return;
}
// Proceed with location-dependent operation
```

### Supabase Query Pattern
```dart
try {
  final response = await _supabase
    .from('table_name')
    .select()
    .eq('column', value);

  if (response.error != null) {
    print('Error: ${response.error!.message}');
    return [];
  }

  return response.data;
} catch (e) {
  print('Exception: $e');
  return [];
}
```

### State Update Pattern
```dart
setState(() {
  _statusMessage = 'New status';
  _isLoading = false;
});
```

## Troubleshooting

### Common Issues

1. **Location Permission Denied**
   - Check AndroidManifest.xml and Info.plist configurations
   - Ensure user has granted permissions in device settings
   - On iOS: Settings → Privacy → Location Services
   - On Android: Settings → Apps → Bump App → Permissions

2. **Supabase Connection Errors**
   - Verify internet connectivity
   - Check Supabase URL and anon key
   - Verify project is not paused in Supabase dashboard
   - Check for CORS issues (web platform)

3. **PostGIS Function Not Found**
   - Ensure PostGIS extension is enabled in Supabase
   - Run: `CREATE EXTENSION IF NOT EXISTS postgis;`
   - Verify function is deployed: `SELECT * FROM pg_proc WHERE proname = 'find_nearby_users';`

4. **Background Location Not Working**
   - Android 10+: Requires `ACCESS_BACKGROUND_LOCATION` permission
   - iOS: User must select "Always Allow" in permission dialog
   - Consider implementing foreground service for Android

### Debug Mode

Enable verbose logging:
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable debug logging
  debugPrint('Starting Bump App in debug mode');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,  // Add this for Supabase debugging
  );

  runApp(const MyApp());
}
```

## Performance Considerations

1. **Location Updates**: 5-second interval is aggressive
   - Consider dynamic intervals based on user activity
   - Implement geofencing to reduce updates when stationary

2. **Database Queries**: PostGIS spatial queries are indexed
   - Monitor query performance as user base grows
   - Consider caching strategies for frequent queries

3. **Battery Usage**: Continuous location tracking is battery-intensive
   - Inform users about battery impact
   - Provide option to reduce update frequency
   - Use significant location changes instead of continuous updates

## Future Enhancements

### Planned Features (Not Yet Implemented)

1. **User Authentication**
   - Email/password sign-up
   - OAuth providers (Google, Apple)
   - User profiles

2. **Real-time Bump Notifications**
   - Push notifications when Bump occurs
   - In-app notification system

3. **Internationalization (i18n)**
   - Currently UI strings are hardcoded in Korean
   - Need to implement flutter_localizations
   - Support multiple languages

4. **Map View**
   - Google Maps integration is configured but not used
   - Show user's current location on map
   - Visualize Bump locations (privacy-respecting)

5. **Social Features**
   - User profiles
   - Friend requests after Bump
   - Chat functionality
   - Bump history

6. **Analytics**
   - Track Bump frequency
   - User engagement metrics
   - Location pattern analysis (anonymized)

## AI Assistant Guidelines

### When Working on This Codebase

1. **Always Check Security**:
   - Never commit API keys or secrets
   - Ensure proper permission checks before location access
   - Validate user authentication before data operations

2. **Maintain Consistency**:
   - Follow existing naming conventions
   - Use established patterns (Singleton for services, etc.)
   - Keep Korean comments where they exist (for consistency with team)

3. **Test Thoroughly**:
   - Update widget tests when modifying UI
   - Test location permissions on both Android and iOS
   - Verify PostGIS queries return expected results

4. **Document Changes**:
   - Update this CLAUDE.md when making architectural changes
   - Add inline comments for complex logic
   - Update README.md for user-facing changes

5. **Consider Privacy**:
   - Location data is sensitive
   - Implement data minimization principles
   - Ensure compliance with GDPR/privacy regulations

6. **Git Practices**:
   - Use feature branches for new work
   - Write descriptive commit messages
   - Push to designated `claude/*` branches for AI-assisted work

### Making Database Changes

1. **Schema Migrations**: Not yet implemented
   - For now, apply changes directly via Supabase dashboard
   - Document all schema changes in migration SQL files
   - Plan to implement proper migration system

2. **Testing Database Functions**:
   ```sql
   -- Test find_nearby_users function
   SELECT * FROM find_nearby_users(
     'test-user-id'::UUID,
     30.0,  -- 30 meters
     1      -- 1 hour
   );
   ```

3. **Backup Before Destructive Changes**:
   - Always backup production data before schema changes
   - Test on local Supabase instance first

## Contact & Resources

- **Supabase Dashboard**: https://supabase.com/dashboard/project/uilmcneizmsqiercrlrt
- **Flutter Docs**: https://docs.flutter.dev/
- **PostGIS Documentation**: https://postgis.net/docs/
- **Geolocator Plugin**: https://pub.dev/packages/geolocator

## Version History

- **v1.0.0**: Initial release with core Bump detection functionality
  - Location tracking (5-second intervals)
  - PostGIS-based proximity detection (30m threshold)
  - Basic UI for tracking control and Bump display
  - Android and iOS platform support

---

**Last Updated**: 2025-11-19
**Maintained By**: AI Assistants (Claude) & Development Team
