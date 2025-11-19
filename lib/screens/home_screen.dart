import 'package:flutter/material.dart';
import 'package:bump_app/services/location_service.dart';
import 'package:bump_app/services/bump_service.dart';
import 'package:bump_app/services/auth_service.dart';
import 'package:bump_app/models/bump.dart';
import 'package:geolocator/geolocator.dart';

/// Bump 앱 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BumpService _bumpService = BumpService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();

  List<Bump> _bumps = [];
  String _statusMessage = '위치 추적을 시작하세요';
  bool _isLocationTracking = false;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  /// 위치 추적 초기화
  ///
  /// 앱 시작 시 권한을 확인하고, 필요하면 사용자에게 권한을 요청합니다.
  Future<void> _initializeLocationTracking() async {
    try {
      // 위치 권한 요청
      bool hasPermission = await _locationService.requestLocationPermission();

      if (hasPermission) {
        setState(() {
          _statusMessage = '위치 권한이 허용되었습니다. 추적을 시작할 준비가 되었습니다.';
        });
      } else {
        setState(() {
          _statusMessage = '위치 권한이 필요합니다.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '권한 확인 중 오류: $e';
      });
    }
  }

  /// 위치 추적 시작
  Future<void> _startTracking() async {
    try {
      // 인증된 사용자 ID 가져오기
      final userId = _authService.currentUserId;
      if (userId == null) {
        setState(() {
          _statusMessage = '로그인이 필요합니다.';
        });
        return;
      }

      await _locationService.startLocationTracking(userId);

      setState(() {
        _isLocationTracking = true;
        _statusMessage = '위치 추적 중... (5초 간격으로 저장됨)';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '추적 시작 중 오류: $e';
      });
    }
  }

  /// 위치 추적 중지
  void _stopTracking() {
    _locationService.stopLocationTracking();

    setState(() {
      _isLocationTracking = false;
      _statusMessage = '위치 추적이 중지되었습니다.';
    });
  }

  /// 현재 위치 한 번만 조회
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();

      if (position != null) {
        setState(() {
          _statusMessage =
              '현재 위치: ${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}';
        });
      } else {
        setState(() {
          _statusMessage = '위치를 가져올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '위치 조회 중 오류: $e';
      });
    }
  }

  /// Bump 찾기
  Future<void> _findBumps() async {
    try {
      // 인증된 사용자 ID 가져오기
      final userId = _authService.currentUserId;
      if (userId == null) {
        setState(() {
          _statusMessage = '로그인이 필요합니다.';
        });
        return;
      }

      final newBumps = await _bumpService.findBumps(userId);

      setState(() {
        _bumps.addAll(newBumps);
        _statusMessage = '${newBumps.length}개의 새로운 Bump를 찾았습니다!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Bump 찾기 중 오류: $e';
      });
    }
  }

  /// 로그아웃
  Future<void> _handleLogout() async {
    // 위치 추적 중지
    if (_isLocationTracking) {
      _stopTracking();
    }

    // 로그아웃
    await _authService.signOut();
    // authStateChanges가 자동으로 감지하여 로그인 화면으로 이동
  }

  @override
  void dispose() {
    // 앱 종료 시 위치 추적 중지
    _locationService.stopLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Bump - 위치 기반 만남'),
        actions: [
          // 사용자 이메일 표시
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상태 메시지
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _statusMessage,
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
                  _isLocationTracking ? '🔴 추적 중' : '⚪ 추적 중지',
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
                  child: const Text('추적 시작'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLocationTracking ? _stopTracking : null,
                  child: const Text('추적 중지'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('현재 위치 조회'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _findBumps,
              child: const Text('Bump 찾기'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _bumps.length,
                itemBuilder: (context, index) {
                  final bump = _bumps[index];
                  return ListTile(
                    leading: const Icon(Icons.person_pin_circle),
                    title: Text('Bump with ${bump.user2Id}'),
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
