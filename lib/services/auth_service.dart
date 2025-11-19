import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:bump_app/services/social_service.dart';

/// Authentication Service
///
/// Handles user authentication including:
/// - Email/password signup and signin
/// - Google OAuth
/// - Apple Sign In
/// - Session management
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialService _socialService = SocialService();

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      // Create user profile automatically
      if (response.user != null) {
        await _socialService.upsertProfile(
          userId: response.user!.id,
          displayName: displayName,
        );
      }

      return response;
    } catch (e) {
      print('회원가입 오류: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } catch (e) {
      print('로그인 오류: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      // Web and mobile use different flows
      const webClientId = 'YOUR_WEB_CLIENT_ID'; // Replace with actual
      const iosClientId = 'YOUR_IOS_CLIENT_ID'; // Replace with actual

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Google 인증 토큰을 가져올 수 없습니다.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Create profile if new user
      if (response.user != null) {
        final profile = await _socialService.getProfile(response.user!.id);
        if (profile == null) {
          await _socialService.upsertProfile(
            userId: response.user!.id,
            displayName: googleUser.displayName ?? 'User',
            avatarUrl: googleUser.photoUrl,
          );
        }
      }

      return response;
    } catch (e) {
      print('Google 로그인 오류: $e');
      rethrow;
    }
  }

  /// Sign in with Apple
  Future<AuthResponse?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Apple 인증 토큰을 가져올 수 없습니다.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      // Create profile if new user
      if (response.user != null) {
        final profile = await _socialService.getProfile(response.user!.id);
        if (profile == null) {
          String displayName = 'User';
          if (credential.givenName != null || credential.familyName != null) {
            displayName =
                '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                    .trim();
          }

          await _socialService.upsertProfile(
            userId: response.user!.id,
            displayName: displayName,
          );
        }
      }

      return response;
    } catch (e) {
      print('Apple 로그인 오류: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      print('비밀번호 재설정 오류: $e');
      rethrow;
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (e) {
      print('비밀번호 업데이트 오류: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      // This requires a server-side implementation
      // as Supabase doesn't provide direct user deletion from client
      await _supabase.functions.invoke(
        'delete-user-account',
        body: {'user_id': userId},
      );
    } catch (e) {
      print('계정 삭제 오류: $e');
      rethrow;
    }
  }
}
