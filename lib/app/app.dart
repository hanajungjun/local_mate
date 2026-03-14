import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:localmate/features/auth/login_page.dart';
import 'package:localmate/app/app_shell.dart';
import 'package:localmate/app/route_observer.dart';

class LocalMateApp extends StatefulWidget {
  final bool showOnboarding;

  const LocalMateApp({Key? key, required this.showOnboarding})
    : super(key: null);
  @override
  State<LocalMateApp> createState() => _LocalMateAppState();
}

class _LocalMateAppState extends State<LocalMateApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 앱 초기화 로직 (필요시 세션 체크 등 수행 가능)
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 현재 로그인 세션 확인
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Local Mate',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            elevation: WidgetStateProperty.all(0),
            splashFactory: NoSplash.splashFactory,
          ),
        ),
      ),
      // ✅ home 수정: 초기화 전엔 로딩, 초기화 후엔 로그인 세션 여부에 따라 분기
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (session != null
                ? AppShell(key: appShellKey) // 로그인 되어있으면 키 꽂아서 바로 진입
                : const LoginPage()),

      // ✅ routes 수정: 네비게이터로 이동할 때도 키가 꽂히도록 설정
      routes: {
        '/app_shell': (context) => AppShell(key: appShellKey),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}
