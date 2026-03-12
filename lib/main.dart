import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ 다시 부활!
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'env.dart';
import 'app/app.dart';
import 'app/app_shell.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// 🔔 FCM 및 권한 관리 (동일)
Future<void> _initFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  if (Platform.isIOS) {
    String? apnsToken = await messaging.getAPNSToken();
    int retry = 0;
    while (apnsToken == null && retry < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      apnsToken = await messaging.getAPNSToken();
      retry++;
    }
  }

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // ✅ 이 한 줄이 핵심입니다!
    // 'all_users'라는 토픽을 구독합니다.
    await messaging.subscribeToTopic('all_users');
    debugPrint('📢 all_users 토픽 구독 완료');
    await messaging.subscribeToTopic('marketing');

    String? token = await messaging.getToken();
    debugPrint("🔥 FCM 토큰: $token");

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && token != null) {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', user.id);
    }
  }
}

Future<void> main() async {
  // ✅ 1. Flutter 엔진 초기화 및 Splash 유지
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ 2. 다국어 초기화가 완료될 때까지 확실히 기다림
  await EasyLocalization.ensureInitialized();

  // ✅ 3. 나머지 서비스 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  await initializeDateFormatting('ko_KR', null);
  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(
    // ✅ 4. EasyLocalization으로 감싸기 (경로 및 언어 설정 확인 필수)
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: _LocalMateAppWrapper(showOnboarding: !onboardingDone),
    ),
  );
}

class _LocalMateAppWrapper extends StatefulWidget {
  final bool showOnboarding;
  const _LocalMateAppWrapper({required this.showOnboarding});

  @override
  State<_LocalMateAppWrapper> createState() => _LocalMateAppWrapperState();
}

class _LocalMateAppWrapperState extends State<_LocalMateAppWrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    // ✅ 5. 앱 구동 준비 (FCM 실행 포함)
    _prepareApp();
  }

  Future<void> _prepareApp() async {
    await _initFCM(); // 푸시 권한 및 토큰 로직

    // 앱이 화면을 그릴 준비가 되었음을 알림
    if (mounted) {
      setState(() => _isReady = true);
      // ✅ 6. 준비 완료 후 Splash 제거
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 준비 전에는 아무것도 안 그리거나 아주 단순한 로딩만 (에러 방지)
    if (!_isReady) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // ✅ 여기서 LocalMateApp이 실행되어야 tr() 등 다국어 함수가 context를 찾아갑니다.
    return LocalMateApp(
      key: appShellKey,
      showOnboarding: widget.showOnboarding,
    );
  }
}

class _DynamicLoadingScreen extends StatefulWidget {
  final String? imageUrl;
  const _DynamicLoadingScreen({this.imageUrl});

  @override
  State<_DynamicLoadingScreen> createState() => _DynamicLoadingScreenState();
}

class _DynamicLoadingScreenState extends State<_DynamicLoadingScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            if (widget.imageUrl != null)
              Image.network(
                widget.imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: CircularProgressIndicator()),
              )
            else
              const Center(
                child: Text(
                  "Local Mate",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 50),
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineFullScreen extends StatelessWidget {
  const _OfflineFullScreen();
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Material(
        color: Colors.black.withAlpha(204),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off_rounded, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                '인터넷 연결이 필요합니다.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
