import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bump_app/providers/auth_provider.dart';
import 'package:bump_app/services/location_service.dart';
import 'package:bump_app/services/bump_service.dart';
import 'package:bump_app/models/bump.dart';
import 'package:bump_app/utils/error_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BumpService _bumpService = BumpService();
  List<Bump> _bumps = [];
  final LocationService _locationService = LocationService();
  String? _statusMessage;
  bool _isLocationTracking = false;
  int _currentUpdateInterval = 5;
  Timer? _uiUpdateTimer;

  // Loading states
  bool _isLoadingBumps = false;
  bool _isStartingTracking = false;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  /// 위치 추적 초기화
  Future<void> _initializeLocationTracking() async {
    final l10n = AppLocalizations.of(context)!;

    try {
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
      if (mounted) {
        setState(() {
          _statusMessage = l10n.statusPermissionError(e.toString());
        });
        ErrorHandler.handle(context, e);
      }
    }
  }

  /// 위치 추적 시작
  Future<void> _startTracking() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      ErrorHandler.handle(context, Exception('로그인이 필요합니다.'));
      return;
    }

    setState(() => _isStartingTracking = true);

    try {
      await _locationService.startLocationTracking(userId);

      setState(() {
        _isLocationTracking = true;
        _currentUpdateInterval = _locationService.currentUpdateInterval;
        _statusMessage = l10n.statusTracking(_currentUpdateInterval);
      });

      // UI 업데이트 타이머 시작
      _uiUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentUpdateInterval = _locationService.currentUpdateInterval;
            _statusMessage = l10n.statusTracking(_currentUpdateInterval);
          });
        }
      });

      if (mounted) {
        ErrorHandler.showSuccess(context, '위치 추적을 시작했습니다.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = l10n.statusTrackingError(e.toString());
        });
        ErrorHandler.handle(context, e, onRetry: _startTracking);
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingTracking = false);
      }
    }
  }

  /// 위치 추적 중지
  void _stopTracking() {
    final l10n = AppLocalizations.of(context)!;

    _locationService.stopLocationTracking();
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;

    setState(() {
      _isLocationTracking = false;
      _statusMessage = l10n.statusStopped;
    });

    ErrorHandler.showInfo(context, '위치 추적을 중지했습니다.');
  }

  /// 현재 위치 조회
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
      if (mounted) {
        setState(() {
          _statusMessage = l10n.statusLocationError(e.toString());
        });
        ErrorHandler.handle(context, e, onRetry: _getCurrentLocation);
      }
    }
  }

  /// Bump 찾기
  Future<void> _findBumps() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.read(currentUserIdProvider);

    if (userId == null) {
      ErrorHandler.handle(context, Exception('로그인이 필요합니다.'));
      return;
    }

    setState(() => _isLoadingBumps = true);

    try {
      final newBumps = await _bumpService.findBumps(userId);

      setState(() {
        _bumps.addAll(newBumps);
        _statusMessage = l10n.statusBumpsFound(newBumps.length);
      });

      if (newBumps.isEmpty) {
        ErrorHandler.showInfo(context, '근처에서 Bump를 찾지 못했습니다.');
      } else {
        ErrorHandler.showSuccess(context, '${newBumps.length}개의 Bump를 찾았습니다!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = l10n.statusBumpsError(e.toString());
        });
        ErrorHandler.handle(context, e, onRetry: _findBumps);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBumps = false);
      }
    }
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await ErrorHandler.showConfirmDialog(
                context,
                title: '로그아웃',
                message: '로그아웃 하시겠습니까?',
              );

              if (confirm && mounted) {
                await ref.read(authProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
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
                      onPressed: (_isLocationTracking || _isStartingTracking)
                          ? null
                          : _startTracking,
                      child: _isStartingTracking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.startLocationTracking),
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
                  onPressed: _isLoadingBumps ? null : _findBumps,
                  child: _isLoadingBumps
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.findBumps),
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

          // Global loading overlay (if needed)
          if (_isStartingTracking || _isLoadingBumps)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
