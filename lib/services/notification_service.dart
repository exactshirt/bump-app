import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 로컬 알림 서비스
///
/// flutter_local_notifications를 사용하여 다음 기능을 제공합니다:
/// 1. Bump 발생 시 로컬 알림 표시
/// 2. 알림 권한 요청 및 관리
/// 3. 알림 채널 설정 (Android)
///
/// 참고: 이것은 로컬 알림입니다. 백그라운드에서 실행되지 않으며,
/// 앱이 실행 중일 때만 작동합니다. 실제 푸시 알림을 위해서는
/// Firebase Cloud Messaging (FCM)을 설정해야 합니다.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  /// Singleton 패턴: 앱 전체에서 하나의 NotificationService만 존재
  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 알림 서비스 초기화
  ///
  /// 앱 시작 시 한 번 호출되어야 합니다.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Android 설정
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 초기화 설정
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 플러그인 초기화
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 알림 권한 요청
    await _requestNotificationPermission();

    _isInitialized = true;
    print('알림 서비스 초기화 완료');
  }

  /// 알림 권한 요청
  Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      print('알림 권한 요청 중 오류: $e');
      return false;
    }
  }

  /// 알림 탭 시 콜백
  void _onNotificationTapped(NotificationResponse response) {
    print('알림 탭됨: ${response.payload}');
    // TODO: 알림 탭 시 Bump 상세 화면으로 이동
  }

  /// Bump 발생 알림 표시
  ///
  /// [bumpId] Bump ID
  /// [otherUserId] 상대방 사용자 ID
  Future<void> showBumpNotification({
    required String bumpId,
    required String otherUserId,
  }) async {
    if (!_isInitialized) {
      print('알림 서비스가 초기화되지 않았습니다.');
      return;
    }

    // Android 알림 세부사항
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'bump_channel', // 채널 ID
      'Bump 알림', // 채널 이름
      channelDescription: '새로운 Bump가 발생했을 때 알림을 받습니다',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
    );

    // iOS 알림 세부사항
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
    );

    // 플랫폼별 세부사항 통합
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 알림 표시
    await _notificationsPlugin.show(
      bumpId.hashCode, // 알림 ID (고유해야 함)
      '🤝 새로운 Bump!', // 제목
      '근처에서 누군가를 만났습니다!', // 내용
      notificationDetails,
      payload: bumpId, // 알림 탭 시 전달할 데이터
    );

    print('Bump 알림 표시됨: $bumpId');
  }

  /// 여러 Bump 알림 표시
  ///
  /// [count] 새로운 Bump 개수
  Future<void> showMultipleBumpsNotification(int count) async {
    if (!_isInitialized) {
      print('알림 서비스가 초기화되지 않았습니다.');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'bump_channel',
      'Bump 알림',
      channelDescription: '새로운 Bump가 발생했을 때 알림을 받습니다',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // 고정 ID (같은 알림을 업데이트)
      '🤝 새로운 Bump!',
      '$count개의 새로운 만남이 있습니다!',
      notificationDetails,
    );

    print('다중 Bump 알림 표시됨: $count개');
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('모든 알림 취소됨');
  }

  /// 특정 알림 취소
  ///
  /// [notificationId] 알림 ID
  Future<void> cancelNotification(int notificationId) async {
    await _notificationsPlugin.cancel(notificationId);
    print('알림 취소됨: $notificationId');
  }
}
