import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:localmate/features/auth/login_page.dart';
import 'package:localmate/app/app_shell.dart';
import 'package:localmate/app/route_observer.dart';

class LocalMateApp extends StatefulWidget {
  final bool showOnboarding;

  // ✅ 1. 생성자에서 key를 받을 수 있도록 super.key를 유지합니다.
  const LocalMateApp({super.key, required this.showOnboarding});

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
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
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
      // ✅ 2. home 부분 수정
      // 로그인 여부에 따라 바로 AppShell로 보낸다면 여기서도 key를 넘겨야 합니다.
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const LoginPage(),

      // ✅ 3. routes 부분 수정 (가장 중요!)
      // 'appShellKey'를 직접 사용하거나, LocalMateApp이 받은 widget.key를 전달합니다.
      routes: {'/app_shell': (context) => AppShell(key: appShellKey)},
    );
  }
}
