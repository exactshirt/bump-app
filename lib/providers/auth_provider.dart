import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/services/auth_service.dart';

/// Authentication State
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  factory AuthState.initial() => const AuthState();

  factory AuthState.loading() => const AuthState(isLoading: true);

  factory AuthState.authenticated(User user) => AuthState(user: user);

  factory AuthState.unauthenticated() => const AuthState(user: null);

  factory AuthState.error(String error) => AuthState(error: error);
}

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial()) {
    _init();
  }

  void _init() {
    // Check initial auth state
    final user = _authService.currentUser;
    if (user != null) {
      state = AuthState.authenticated(user);
    }

    // Listen to auth changes
    _authService.authStateChanges.listen((authState) {
      if (authState.session != null) {
        state = AuthState.authenticated(authState.session!.user);
      } else {
        state = AuthState.unauthenticated();
      }
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState.loading();

    try {
      final response = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
      } else {
        state = AuthState.error('회원가입에 실패했습니다.');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading();

    try {
      final response = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthState.authenticated(response.user!);
      } else {
        state = AuthState.error('로그인에 실패했습니다.');
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState.loading();

    try {
      final response = await _authService.signInWithGoogle();

      if (response?.user != null) {
        state = AuthState.authenticated(response!.user!);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = AuthState.loading();

    try {
      final response = await _authService.signInWithApple();

      if (response?.user != null) {
        state = AuthState.authenticated(response!.user!);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();

    try {
      await _authService.signOut();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}

/// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Current User ID Provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.id;
});
