import 'package:supabase_flutter/supabase_flutter.dart';

/// 사용자 인증 서비스
///
/// Supabase Auth를 사용하여 다음 기능을 제공합니다:
/// 1. 이메일/비밀번호 회원가입
/// 2. 이메일/비밀번호 로그인
/// 3. 로그아웃
/// 4. 현재 사용자 정보 조회
/// 5. 인증 상태 변경 감지
class AuthService {
  static final AuthService _instance = AuthService._internal();

  /// Singleton 패턴: 앱 전체에서 하나의 AuthService만 존재
  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// 현재 로그인한 사용자 정보
  User? get currentUser => _supabase.auth.currentUser;

  /// 현재 사용자 ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 로그인 상태 확인
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  /// 인증 상태 변경 스트림
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// 이메일/비밀번호로 회원가입
  ///
  /// [email] 사용자 이메일
  /// [password] 비밀번호 (최소 6자)
  ///
  /// 반환값: 성공 시 사용자 정보, 실패 시 null
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('회원가입 성공: ${response.user!.email}');
        return response.user;
      } else {
        print('회원가입 실패: 사용자 정보가 없습니다.');
        return null;
      }
    } on AuthException catch (e) {
      print('회원가입 오류: ${e.message}');
      rethrow;
    } catch (e) {
      print('회원가입 중 예상치 못한 오류: $e');
      rethrow;
    }
  }

  /// 이메일/비밀번호로 로그인
  ///
  /// [email] 사용자 이메일
  /// [password] 비밀번호
  ///
  /// 반환값: 성공 시 사용자 정보, 실패 시 null
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('로그인 성공: ${response.user!.email}');
        return response.user;
      } else {
        print('로그인 실패: 사용자 정보가 없습니다.');
        return null;
      }
    } on AuthException catch (e) {
      print('로그인 오류: ${e.message}');
      rethrow;
    } catch (e) {
      print('로그인 중 예상치 못한 오류: $e');
      rethrow;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 중 오류: $e');
      rethrow;
    }
  }

  /// 비밀번호 재설정 이메일 전송
  ///
  /// [email] 비밀번호를 재설정할 이메일 주소
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      print('비밀번호 재설정 이메일 전송 완료');
    } catch (e) {
      print('비밀번호 재설정 이메일 전송 중 오류: $e');
      rethrow;
    }
  }

  /// 사용자 프로필 업데이트
  ///
  /// [data] 업데이트할 사용자 메타데이터
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: data),
      );
      print('사용자 프로필 업데이트 완료');
    } catch (e) {
      print('사용자 프로필 업데이트 중 오류: $e');
      rethrow;
    }
  }
}
