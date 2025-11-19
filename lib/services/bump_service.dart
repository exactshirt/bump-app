import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/models/bump.dart';
import 'package:bump_app/services/notification_service.dart';

class BumpService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

  /// 현재 사용자와 가까운 거리에 있는 다른 사용자를 찾아 Bump를 생성합니다.
  ///
  /// Supabase의 RPC(Remote Procedure Call)를 사용하여 데이터베이스 함수를 호출합니다.
  /// 이 함수는 PostGIS의 ST_DWithin을 사용하여 30m 이내의 사용자를 찾고,
  /// 중복을 방지하며 bumps 테이블에 새로운 기록을 생성합니다.
  ///
  /// [userId] 현재 사용자의 ID
  /// 반환값: 새로 생성된 Bump 목록
  Future<List<Bump>> findBumps(String userId) async {
    try {
      // Supabase에 정의된 `find_nearby_users` 함수를 호출합니다.
      // 이 함수는 내부적으로 다음 작업을 수행합니다:
      // 1. 현재 사용자의 최신 위치를 가져옵니다.
      // 2. ST_DWithin을 사용하여 30m 이내에 있는 다른 사용자를 찾습니다.
      // 3. bumps 테이블을 확인하여 최근 1시간 내에 동일한 사용자와의 Bump가 있었는지 확인합니다.
      // 4. 새로운 Bump가 발생하면 bumps 테이블에 기록을 추가하고, 해당 Bump 정보를 반환합니다.
      final response = await _supabase.rpc(
        'find_nearby_users',
        params: {
          'current_user_id': userId,
          'distance_meters': 30,
          'time_interval_hours': 1,
        },
      );

      if (response.error != null) {
        print('Bump 찾기 중 오류 발생: ${response.error!.message}');
        return [];
      }

      // 함수 호출 결과(새로운 Bump 목록)를 List<Bump>으로 변환합니다.
      final List<dynamic> data = response.data;
      final bumps = data.map((json) => Bump.fromJson(json)).toList();

      // 새로운 Bump가 발견되면 알림 표시
      if (bumps.isNotEmpty) {
        if (bumps.length == 1) {
          // 단일 Bump 알림
          await _notificationService.showBumpNotification(
            bumpId: bumps[0].id,
            otherUserId: bumps[0].user2Id,
          );
        } else {
          // 다중 Bump 알림
          await _notificationService.showMultipleBumpsNotification(bumps.length);
        }
      }

      return bumps;

    } catch (e) {
      print('Bump 서비스 오류: $e');
      return [];
    }
  }
}
