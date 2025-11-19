import 'package:supabase_flutter/supabase_flutter.dart';

/// 인증 서비스
///
/// Supabase 인증을 관리하는 서비스입니다.
/// 이메일/비밀번호 기반 인증을 제공합니다.
class AuthService {
  static final AuthService _instance = AuthService._internal();

  /// Singleton 패턴: 앱 전체에서 하나의 AuthService만 존재
  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// 현재 로그인한 사용자 가져오기
  User? get currentUser => _supabase.auth.currentUser;

  /// 현재 사용자 ID 가져오기
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// 로그인 여부 확인
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  /// 인증 상태 변경 스트림
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// 이메일/비밀번호로 회원가입
  ///
  /// [email] 사용자 이메일
  /// [password] 비밀번호 (최소 6자)
  /// 반환값: 성공 시 AuthResponse, 실패 시 null
  Future<AuthResponse?> signUp({
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
        return response;
      } else {
        print('회원가입 실패: 사용자가 생성되지 않았습니다.');
        return null;
      }
    } catch (e) {
      print('회원가입 중 오류 발생: $e');
      return null;
    }
  }

  /// 이메일/비밀번호로 로그인
  ///
  /// [email] 사용자 이메일
  /// [password] 비밀번호
  /// 반환값: 성공 시 AuthResponse, 실패 시 null
  Future<AuthResponse?> signIn({
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
        return response;
      } else {
        print('로그인 실패');
        return null;
      }
    } catch (e) {
      print('로그인 중 오류 발생: $e');
      return null;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      print('로그아웃 성공');
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
    }
  }

  /// 비밀번호 재설정 이메일 전송
  ///
  /// [email] 사용자 이메일
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      print('비밀번호 재설정 이메일 전송 완료');
    } catch (e) {
      print('비밀번호 재설정 이메일 전송 중 오류 발생: $e');
    }
  }
}
