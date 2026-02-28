import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // 에러 방지 주석
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart'; // 에러 방지 주석
// import 'package:firebase_core/firebase_core.dart'; // 에러 방지 주석
// import 'package:firebase_messaging/firebase_messaging.dart'; // 에러 방지 주석
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
// import 'package:purchases_flutter/purchases_flutter.dart'; // 에러 방지 주석
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:localmate/app/route_observer.dart'; // 에러 방지 주석
// import 'services/network_service.dart'; // 에러 방지 주석
// import 'firebase_options.dart'; // 에러 방지 주석
// import 'services/prompt_cache.dart'; // 에러 방지 주석
import 'package:localmate/app/app_shell.dart';
import 'env.dart';
import 'app/app.dart';
// import 'package:localmate/services/country_service.dart'; // 에러 방지 주석

/**
 * 🚀 Local Mate 앱 진입점
 * 외부 서비스 연동 전 UI 확인을 위해 에러 유발 요소 주석 처리 완료
 */

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Firebase 미설정 시 에러 방지 주석
// }
// 🔔 알림 권한 시스템 팝업 요청 함수
Future<void> _initNotificationPermission() async {
  // 알림 권한 상태 체크
  var status = await Permission.notification.status;

  if (status.isDenied) {
    // 💡 거절된 상태라면 유저에게 팝업을 띄워 요청합니다.
    await Permission.notification.request();
  }

  if (await Permission.notification.isGranted) {
    debugPrint('🔔 알림 권한 승인됨');
  } else {
    debugPrint('🔕 알림 권한 거절됨');
  }
}

Future<void> _initMediaStorePermission() async {
  if (Platform.isAndroid) {
    List<Permission> permissions = [
      Permission.photos,
      Permission.videos,
      Permission.storage,
    ];
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    bool isGranted =
        statuses[Permission.photos]?.isGranted == true ||
        statuses[Permission.storage]?.isGranted == true;
    if (isGranted) {
      debugPrint('📸 갤러리 접근 권한 확보 성공');
    } else {
      debugPrint('❌ 권한 거절됨');
    }
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await EasyLocalization.ensureInitialized();
  EasyLocalization.logger.enableLevels = [];

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // --- 외부 서비스 초기화 (UI 확인을 위해 일시 주석) ---
  // await MobileAds.instance.initialize();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // CountryService.prefetch();
  // ----------------------------------------------

  // Supabase 초기화 (AppEnv 설정 필요)
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("⚠️ Supabase 초기화 실패 (URL/Key 확인 필요): $e");
  }

  await initializeDateFormatting('ko_KR', null);

  KakaoSdk.init(
    nativeAppKey: AppEnv.kakaoNativeAppKey,
    javaScriptAppKey: AppEnv.kakaoJavaScriptKey,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ko'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko'),
      useOnlyLangCode: true,
      child: _LocalMateAppWrapper(
        showOnboarding: !onboardingDone,
        adminLoadingImageUrl: null,
      ),
    ),
  );
}

class _LocalMateAppWrapper extends StatefulWidget {
  final bool showOnboarding;
  final String? adminLoadingImageUrl;

  const _LocalMateAppWrapper({
    required this.showOnboarding,
    this.adminLoadingImageUrl,
  });

  @override
  State<_LocalMateAppWrapper> createState() => _LocalMateAppWrapperState();
}

class _LocalMateAppWrapperState extends State<_LocalMateAppWrapper> {
  bool _isLoadingComplete = false;

  @override
  void initState() {
    super.initState();
    _initNotificationPermission(); // 알림 권한
    _initMediaStorePermission(); // 갤러리 권한 (사진/영상)
    Permission.location.request();

    // 로딩 화면을 1초간 보여준 후 메인으로 진입
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoadingComplete = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoadingComplete) {
      return _DynamicLoadingScreen(imageUrl: widget.adminLoadingImageUrl);
    }

    // ✅ 기존 ValueKey를 지우고 우리가 만든 appShellKey를 꽂아줍니다.
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
