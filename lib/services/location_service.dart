import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';

/// 위치 추적 서비스
/// 
/// 이 클래스는 다음 기능을 담당합니다:
/// 1. 사용자의 현재 위치를 주기적으로(5초 간격) 가져오기
/// 2. 가져온 위치 데이터를 Supabase의 `locations` 테이블에 저장
/// 3. 24시간 이상 된 위치 데이터 자동 삭제
class LocationService {
  static final LocationService _instance = LocationService._internal();
  
  /// Singleton 패턴: 앱 전체에서 하나의 LocationService만 존재
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();

  // 위치 추적 타이머
  Timer? _locationTimer;

  // 위치 추적 활성화 여부
  bool _isTracking = false;

  // 활동 인식 스트림
  StreamSubscription<ActivityEvent>? _activitySubscription;

  // 현재 업데이트 주기 (초)
  int _currentUpdateInterval = 5;

  // Activity Recognition 인스턴스
  final ActivityRecognition _activityRecognition = ActivityRecognition.instance;

  /// 위치 추적 활성화 여부 확인
  bool get isTracking => _isTracking;

  /// 현재 업데이트 주기 확인
  int get currentUpdateInterval => _currentUpdateInterval;
  
  /// 위치 권한 확인 및 요청
  /// 
  /// 반환값:
  /// - true: 위치 권한이 허용됨
  /// - false: 위치 권한이 거부됨
  Future<bool> requestLocationPermission() async {
    try {
      // 위치 권한 상태 확인
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // 권한이 거부된 경우, 사용자에게 권한 요청
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        // 권한이 영구적으로 거부된 경우, 설정 앱으로 이동하도록 유도
        print('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 활성화해주세요.');
        await Geolocator.openLocationSettings();
        return false;
      }
      
      // 백그라운드 위치 권한 확인 (Android 10 이상, iOS 11 이상)
      if (permission == LocationPermission.whileInUse) {
        print('백그라운드 위치 권한이 필요합니다. 설정에서 "항상 허용"으로 변경해주세요.');
      }
      
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      print('위치 권한 요청 중 오류 발생: $e');
      return false;
    }
  }
  
  /// 사용자 활동에 따라 업데이트 주기 결정
  ///
  /// - 높은 빈도 (5초): 걷기, 운전, 자전거 등 이동 중
  /// - 중간 빈도 (30초): 정지 상태
  /// - 낮은 빈도 (300초 = 5분): 유휴 상태
  int _getUpdateIntervalForActivity(ActivityType activity) {
    switch (activity) {
      case ActivityType.WALKING:
      case ActivityType.RUNNING:
      case ActivityType.IN_VEHICLE:
      case ActivityType.ON_BICYCLE:
        return 5; // 높은 빈도: 이동 중
      case ActivityType.STILL:
        return 30; // 중간 빈도: 정지 상태
      case ActivityType.UNKNOWN:
      default:
        return 300; // 낮은 빈도: 알 수 없음/유휴
    }
  }

  /// 활동 인식 시작
  Future<void> _startActivityRecognition(String userId) async {
    try {
      // 활동 인식 스트림 구독
      final stream = _activityRecognition.startStream(runForegroundService: true);
      _activitySubscription = stream.listen((ActivityEvent event) {
        print('활동 감지: ${event.type} (신뢰도: ${event.confidence}%)');

        // 신뢰도가 75% 이상인 경우만 사용
        if (event.confidence >= 75) {
          int newInterval = _getUpdateIntervalForActivity(event.type);

          // 업데이트 주기가 변경된 경우 타이머 재시작
          if (newInterval != _currentUpdateInterval) {
            print('업데이트 주기 변경: ${_currentUpdateInterval}초 -> $newInterval초');
            _currentUpdateInterval = newInterval;
            _restartLocationTimer(userId);
          }
        }
      });
    } catch (e) {
      print('활동 인식 시작 중 오류: $e');
      // 활동 인식 실패 시 기본 5초 주기 사용
      _currentUpdateInterval = 5;
    }
  }

  /// 위치 타이머 재시작
  void _restartLocationTimer(String userId) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      Duration(seconds: _currentUpdateInterval),
      (timer) async {
        await _saveCurrentLocation(userId);
      },
    );
  }

  /// 위치 추적 시작
  ///
  /// 적응형 빈도로 위치를 가져오고 Supabase에 저장합니다.
  /// 사용자 활동에 따라 5초~5분 주기로 자동 조정됩니다.
  Future<void> startLocationTracking(String userId) async {
    if (_isTracking) {
      print('위치 추적이 이미 진행 중입니다.');
      return;
    }

    // 권한 확인
    bool hasPermission = await requestLocationPermission();
    if (!hasPermission) {
      print('위치 권한이 없어 추적을 시작할 수 없습니다.');
      return;
    }

    _isTracking = true;
    print('위치 추적 시작 (적응형 빈도)');

    // 첫 번째 위치 즉시 저장
    await _saveCurrentLocation(userId);

    // 활동 인식 시작
    await _startActivityRecognition(userId);

    // 초기 타이머 시작 (기본 5초 주기)
    _locationTimer = Timer.periodic(
      Duration(seconds: _currentUpdateInterval),
      (timer) async {
        await _saveCurrentLocation(userId);
      },
    );
  }
  
  /// 위치 추적 중지
  void stopLocationTracking() {
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }

    // 활동 인식 스트림 취소
    if (_activitySubscription != null) {
      _activitySubscription!.cancel();
      _activitySubscription = null;
    }

    _isTracking = false;
    _currentUpdateInterval = 5; // 기본값으로 리셋
    print('위치 추적 중지');
  }
  
  /// 현재 위치를 가져와 Supabase에 저장
  Future<void> _saveCurrentLocation(String userId) async {
    try {
      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      
      // Supabase 클라이언트 가져오기
      final supabase = Supabase.instance.client;
      
      // 위치 데이터를 `locations` 테이블에 저장
      await supabase.from('locations').insert({
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      print('위치 저장 완료: (${position.latitude}, ${position.longitude})');
    } catch (e) {
      print('위치 저장 중 오류 발생: $e');
    }
  }
  
  /// 24시간 이상 된 위치 데이터 삭제
  /// 
  /// 이 함수는 정기적으로 호출되어야 합니다. (예: 앱 시작 시, 또는 매 시간마다)
  Future<void> deleteOldLocationData(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      // 24시간 이전의 데이터 삭제
      final cutoffTime = DateTime.now().subtract(Duration(hours: 24));
      
      await supabase
          .from('locations')
          .delete()
          .eq('user_id', userId)
          .lt('timestamp', cutoffTime.toIso8601String());
      
      print('24시간 이상 된 위치 데이터 삭제 완료');
    } catch (e) {
      print('위치 데이터 삭제 중 오류 발생: $e');
    }
  }
  
  /// 현재 위치 한 번만 가져오기 (추적 없이)
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('현재 위치 조회 중 오류 발생: $e');
      return null;
    }
  }
}
