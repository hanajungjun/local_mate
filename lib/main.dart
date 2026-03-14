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
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:localmate/features/chat/pages/chat_room_page.dart';
import 'package:localmate/features/matching/pages/received_offers_page.dart';
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
    await _initFCM();

    // --- 🔔 여기서부터 추가: 알림 클릭 리스너 ---

    // 1. 앱이 완전히 꺼져있을 때 푸시 눌러서 들어온 경우 처리
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }

    // 2. 앱이 백그라운드에 떠 있을 때 푸시 눌러서 들어온 경우 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // ------------------------------------------

    if (mounted) {
      setState(() => _isReady = true);
      FlutterNativeSplash.remove();
    }
  }

  // ✅ 알림 타입에 따른 이동 로직 (교통정리 함수)
  void _handleNotificationClick(RemoteMessage message) {
    final String? type = message.data['type'];
    final String? roomId = message.data['roomId'];
    debugPrint("📩 알림 클릭됨! 타입: $type, 방ID: $roomId");

    if (type == 'match') {
      // 🎉 매칭 성공 시 채팅 목록으로
      appShellKey.currentState?.goToTab(3, chatTab: 0);
    } else if (type == 'like') {
      // ❤️ 좋아요 시 좋아요 리스트로
      appShellKey.currentState?.goToTab(3, chatTab: 1);
    } else if (type == 'chat' && roomId != null) {
      // 💬 [핵심 추가] 메시지 알림 클릭 시 해당 채팅방으로 직접 이동
      _navigateToSpecificChat(roomId);
    } else if (type == 'offer') {
      appShellKey.currentState?.goToTab(0);

      final context = appShellKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceivedOffersPage(
              requestId: message.data['requestId'] ?? '', // 🆔 공고 ID
              requestTitle:
                  message.data['requestTitle'] ?? '공고 상세', // 🏷️ 공고 제목
            ),
          ),
        );
      }
    }
  }

  // ✅ 특정 채팅방으로 바로 꽂아주는 함수 (안정성 강화)
  Future<void> _navigateToSpecificChat(String roomId) async {
    final supabase = Supabase.instance.client;

    try {
      // 1. 탭 이동부터 수행
      appShellKey.currentState?.goToTab(3, chatTab: 0);

      // 2. 데이터 가져오기 (비동기)
      final roomData = await supabase
          .from('my_chat_rooms')
          .select('other_participant_id')
          .eq('id', roomId)
          .single();

      final targetId = roomData['other_participant_id'];

      final targetUser = await supabase
          .from('users')
          .select('id, nickname, profile_image')
          .eq('id', targetId)
          .single();

      // 💡 [중요] 탭 이동 애니메이션이 끝날 때까지 아주 잠깐만 기다려줍니다 (에러 방지용)
      await Future.delayed(const Duration(milliseconds: 300));

      final context = appShellKey.currentContext;
      if (context != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatRoomPage(roomId: roomId, targetUser: targetUser),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ 채팅방 이동 중 에러 발생: $e");
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
    return LocalMateApp(showOnboarding: widget.showOnboarding);
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
