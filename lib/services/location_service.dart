import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  /// 위치 추적 활성화 여부 확인
  bool get isTracking => _isTracking;
  
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
  
  /// 위치 추적 시작
  /// 
  /// 5초 간격으로 위치를 가져오고 Supabase에 저장합니다.
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
    print('위치 추적 시작');
    
    // 첫 번째 위치 즉시 저장
    await _saveCurrentLocation(userId);
    
    // 5초 간격으로 위치 저장
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _saveCurrentLocation(userId);
    });
  }
  
  /// 위치 추적 중지
  void stopLocationTracking() {
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }
    _isTracking = false;
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
