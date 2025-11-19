import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bump_app/services/location_service.dart';
import 'package:bump_app/services/bump_service.dart';
import 'package:bump_app/services/auth_service.dart';
import 'package:bump_app/models/bump.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase 초기화
  await Supabase.initialize(
    url: 'https://uilmcneizmsqiercrlrt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpbG1jbmVpem1zcWllcmNybHJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzNjM0NjIsImV4cCI6MjA3ODkzOTQ2Mn0.3SdFUJEDlKgB1pbjEdNSLv6Dc1QBeaqa9pP6X5GWLGY',
  );
  
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
      home: const BumpHomePage(title: 'Bump - 위치 기반 만남'),
    );
  }
}

class BumpHomePage extends StatefulWidget {
  const BumpHomePage({super.key, required this.title});

  final String title;

  @override
  State<BumpHomePage> createState() => _BumpHomePageState();
}

class _BumpHomePageState extends State<BumpHomePage> {
  final BumpService _bumpService = BumpService();
  final AuthService _authService = AuthService();
  List<Bump> _bumps = [];
  final LocationService _locationService = LocationService();
  String _statusMessage = '위치 추적을 시작하세요';
  bool _isLocationTracking = false;

  // 로그인 폼 컨트롤러
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }
  
  /// 위치 추적 초기화
  /// 
  /// 앱 시작 시 권한을 확인하고, 필요하면 사용자에게 권한을 요청합니다.
  Future<void> _initializeLocationTracking() async {
    try {
      // 위치 권한 요청
      bool hasPermission = await _locationService.requestLocationPermission();
      
      if (hasPermission) {
        setState(() {
          _statusMessage = '위치 권한이 허용되었습니다. 추적을 시작할 준비가 되었습니다.';
        });
      } else {
        setState(() {
          _statusMessage = '위치 권한이 필요합니다.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '권한 확인 중 오류: $e';
      });
    }
  }
  
  /// 위치 추적 시작
  Future<void> _startTracking() async {
    try {
      // 로그인한 사용자의 ID를 사용
      final userId = _authService.currentUserId;
      if (userId == null) {
        setState(() {
          _statusMessage = '로그인이 필요합니다.';
        });
        return;
      }

      await _locationService.startLocationTracking(userId);

      setState(() {
        _isLocationTracking = true;
        _statusMessage = '위치 추적 중... (5초 간격으로 저장됨)';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '추적 시작 중 오류: $e';
      });
    }
  }
  
  /// 위치 추적 중지
  void _stopTracking() {
    _locationService.stopLocationTracking();
    
    setState(() {
      _isLocationTracking = false;
      _statusMessage = '위치 추적이 중지되었습니다.';
    });
  }
  
  /// 현재 위치 한 번만 조회
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _statusMessage = 
            '현재 위치: ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}';
        });
      } else {
        setState(() {
          _statusMessage = '위치를 가져올 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '위치 조회 중 오류: $e';
      });
    }
  }
  
  /// Bump 찾기
  Future<void> _findBumps() async {
    try {
      // 로그인한 사용자의 ID를 사용
      final userId = _authService.currentUserId;
      if (userId == null) {
        setState(() {
          _statusMessage = '로그인이 필요합니다.';
        });
        return;
      }

      final newBumps = await _bumpService.findBumps(userId);

      setState(() {
        _bumps.addAll(newBumps);
        _statusMessage = '${newBumps.length}개의 새로운 Bump를 찾았습니다!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Bump 찾기 중 오류: $e';
      });
    }
  }

  /// 로그인
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = '이메일과 비밀번호를 입력하세요.';
      });
      return;
    }

    final response = await _authService.signIn(
      email: email,
      password: password,
    );

    if (response != null) {
      setState(() {
        _statusMessage = '로그인 성공: ${response.user!.email}';
      });
    } else {
      setState(() {
        _statusMessage = '로그인 실패';
      });
    }
  }

  /// 회원가입
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = '이메일과 비밀번호를 입력하세요.';
      });
      return;
    }

    final response = await _authService.signUp(
      email: email,
      password: password,
    );

    if (response != null) {
      setState(() {
        _statusMessage = '회원가입 성공! 이메일을 확인하세요.';
      });
    } else {
      setState(() {
        _statusMessage = '회원가입 실패';
      });
    }
  }

  /// 로그아웃
  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {
      _statusMessage = '로그아웃되었습니다.';
      _isLocationTracking = false;
    });
    _locationService.stopLocationTracking();
  }

  @override
  void dispose() {
    // 앱 종료 시 위치 추적 중지
    _locationService.stopLocationTracking();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: _authService.isLoggedIn
          ? _buildMainContent()
          : _buildLoginScreen(),
    );
  }

  /// 로그인 화면 빌드
  Widget _buildLoginScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bump App',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _signIn,
                  child: const Text('로그인'),
                ),
                ElevatedButton(
                  onPressed: _signUp,
                  child: const Text('회원가입'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 메인 컨텐츠 화면 빌드
  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 사용자 정보 및 로그아웃
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '로그인: ${_authService.currentUser?.email ?? "알 수 없음"}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton(
                  onPressed: _signOut,
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),

          // 상태 메시지
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),

          // 위치 추적 상태
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _isLocationTracking ? '🔴 추적 중' : '⚪ 추적 중지',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLocationTracking ? null : _startTracking,
                child: const Text('추적 시작'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isLocationTracking ? _stopTracking : null,
                child: const Text('추적 중지'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _getCurrentLocation,
            child: const Text('현재 위치 조회'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _findBumps,
            child: const Text('Bump 찾기'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _bumps.length,
              itemBuilder: (context, index) {
                final bump = _bumps[index];
                return ListTile(
                  leading: const Icon(Icons.person_pin_circle),
                  title: Text('Bump with ${bump.user2Id}'),
                  subtitle: Text(bump.bumpedAt.toLocal().toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
