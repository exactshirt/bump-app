import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error Handler
///
/// Centralized error handling and user feedback system
class ErrorHandler {
  /// Handle error and show user-friendly message
  static void handle(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    final message = customMessage ?? _getErrorMessage(error);

    // Log error (in production, send to Sentry/Firebase Crashlytics)
    _logError(error);

    // Show snackbar to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return _getAuthErrorMessage(error);
    } else if (error is PostgrestException) {
      return _getPostgrestErrorMessage(error);
    } else if (error is SocketException) {
      return '인터넷 연결을 확인해주세요.';
    } else if (error is TimeoutException) {
      return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
    } else if (error is FormatException) {
      return '데이터 형식이 올바르지 않습니다.';
    } else if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }

    return '알 수 없는 오류가 발생했습니다.';
  }

  /// Get auth-specific error message
  static String _getAuthErrorMessage(AuthException error) {
    switch (error.statusCode) {
      case '400':
        if (error.message.contains('Invalid login credentials')) {
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        } else if (error.message.contains('User already registered')) {
          return '이미 등록된 이메일입니다.';
        }
        return '잘못된 요청입니다.';

      case '422':
        if (error.message.contains('Email')) {
          return '유효한 이메일 주소를 입력해주세요.';
        } else if (error.message.contains('Password')) {
          return '비밀번호는 최소 6자 이상이어야 합니다.';
        }
        return '입력 정보를 확인해주세요.';

      case '429':
        return '너무 많은 요청을 보냈습니다. 잠시 후 다시 시도해주세요.';

      default:
        return error.message;
    }
  }

  /// Get database-specific error message
  static String _getPostgrestErrorMessage(PostgrestException error) {
    if (error.code == '23505') {
      // Unique constraint violation
      return '이미 존재하는 데이터입니다.';
    } else if (error.code == '23503') {
      // Foreign key violation
      return '참조하는 데이터가 존재하지 않습니다.';
    } else if (error.code?.startsWith('42') ?? false) {
      // Syntax errors
      return '데이터베이스 쿼리 오류가 발생했습니다.';
    } else if (error.code == 'PGRST116') {
      // JWT expired
      return '세션이 만료되었습니다. 다시 로그인해주세요.';
    }

    return error.message;
  }

  /// Log error (replace with actual logging service in production)
  static void _logError(dynamic error, [StackTrace? stackTrace]) {
    // In development
    debugPrint('❌ Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    // In production, send to error tracking service:
    // Sentry.captureException(error, stackTrace: stackTrace);
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Show success message
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show info message
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
