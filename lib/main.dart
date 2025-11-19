import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/screens/auth_screen.dart';
import 'package:bump_app/screens/home_screen.dart';
import 'package:bump_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://uilmcneizmsqiercrlrt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbG1jbmVpem1zcWllcmNybHJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzNjM0NjIsImV4cCI6MjA3ODkzOTQ2Mn0.3SdFUJEDlKgB1pbjEdNSLv6Dc1QBeaqa9pP6X5GWLGY',
  );

  // 알림 서비스 초기화
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bump App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 인증 상태에 따라 화면을 전환하는 위젯
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 인증 상태를 확인하여 적절한 화면 표시
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 중
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 현재 사용자 확인
        final user = _supabase.auth.currentUser;

        if (user == null) {
          // 로그인되지 않음 -> 인증 화면 표시
          return const AuthScreen();
        } else {
          // 로그인됨 -> 홈 화면 표시
          return const HomeScreen();
        }
      },
    );
  }
}
