import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/services/location_service.dart';
import 'package:bump_app/services/bump_service.dart';
import 'package:bump_app/models/bump.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://uilmcneizmsqiercrlrt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbG1jbmVpem1zcWllcmNybHJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzNjM0NjIsImV4cCI6MjA3ODkzOTQ2Mn0.3SdFUJEDlKgB1pbjEdNSLv6Dc1QBeaqa9pP6X5GWLGY',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bump App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ko', ''), // Korean
      ],
      home: const BumpHomePage(),
    );
  }
}

class BumpHomePage extends StatefulWidget {
  const BumpHomePage({super.key});

  @override
  State<BumpHomePage> createState() => _BumpHomePageState();
}

class _BumpHomePageState extends State<BumpHomePage> {
  final BumpService _bumpService = BumpService();
  List<Bump> _bumps = [];
  final LocationService _locationService = LocationService();
  String? _statusMessage;
  bool _isLocationTracking = false;
  int _currentUpdateInterval = 5;
  Timer? _uiUpdateTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }
  
  /// 위치 추적 초기화
  ///
  /// 앱 시작 시 권한을 확인하고, 필요하면 사용자에게 권한을 요청합니다.
  Future<void> _initializeLocationTracking() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // 위치 권한 요청
      bool hasPermission = await _locationService.requestLocationPermission();

      if (hasPermission) {
        setState(() {
          _statusMessage = l10n.statusPermissionGranted;
        });
      } else {
        setState(() {
          _statusMessage = l10n.statusPermissionRequired;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = l10n.statusPermissionError(e.toString());
      });
    }
  }
  
  /// 위치 추적 시작
  Future<void> _startTracking() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // 임시 사용자 ID (실제로는 로그인한 사용자의 ID를 사용해야 합니다)
      const userId = 'test-user-123';

      await _locationService.startLocationTracking(userId);

      setState(() {
        _isLocationTracking = true;
        _currentUpdateInterval = _locationService.currentUpdateInterval;
        _statusMessage = l10n.statusTracking(_currentUpdateInterval);
      });

      // UI 업데이트 타이머 시작 (2초마다 현재 업데이트 주기 확인)
      _uiUpdateTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentUpdateInterval = _locationService.currentUpdateInterval;
            _statusMessage = l10n.statusTracking(_currentUpdateInterval);
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = l10n.statusTrackingError(e.toString());
      });
    }
  }
  
  /// 위치 추적 중지
  void _stopTracking() {
    final l10n = AppLocalizations.of(context)!;

    _locationService.stopLocationTracking();

    // UI 업데이트 타이머 취소
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    setState(() {
      _isLocationTracking = false;
      _statusMessage = l10n.statusStopped;
    });
  }
  
  /// 현재 위치 한 번만 조회
  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _statusMessage = l10n.statusCurrentLocation(
            position.latitude.toStringAsFixed(6),
            position.longitude.toStringAsFixed(6),
          );
        });
      } else {
        setState(() {
          _statusMessage = l10n.statusLocationUnavailable;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = l10n.statusLocationError(e.toString());
      });
    }
  }

  /// Bump 찾기
  Future<void> _findBumps() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // 임시 사용자 ID (실제로는 로그인한 사용자의 ID를 사용해야 합니다)
      const userId = 'test-user-123';

      final newBumps = await _bumpService.findBumps(userId);

      setState(() {
        _bumps.addAll(newBumps);
        _statusMessage = l10n.statusBumpsFound(newBumps.length);
      });
    } catch (e) {
      setState(() {
        _statusMessage = l10n.statusBumpsError(e.toString());
      });
    }
  }

  @override
  void dispose() {
    // 앱 종료 시 위치 추적 중지
    _locationService.stopLocationTracking();

    // UI 업데이트 타이머 취소
    _uiUpdateTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.appTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상태 메시지
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _statusMessage ?? l10n.statusStart,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),

            // 위치 추적 상태
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _isLocationTracking
                      ? l10n.trackingActive
                      : l10n.trackingInactive,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isLocationTracking ? null : _startTracking,
                  child: Text(l10n.startLocationTracking),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLocationTracking ? _stopTracking : null,
                  child: Text(l10n.stopLocationTracking),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: Text(l10n.getCurrentLocation),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _findBumps,
              child: Text(l10n.findBumps),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _bumps.length,
                itemBuilder: (context, index) {
                  final bump = _bumps[index];
                  return ListTile(
                    leading: const Icon(Icons.person_pin_circle),
                    title: Text(l10n.bumpWith(bump.user2Id)),
                    subtitle: Text(bump.bumpedAt.toLocal().toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
