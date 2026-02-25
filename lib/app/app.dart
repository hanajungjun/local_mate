import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:local_mate/features/auth/login_page.dart';
import 'package:local_mate/app/app_shell.dart';
import 'package:local_mate/app/route_observer.dart';

class TravelMemoirApp extends StatefulWidget {
  final bool showOnboarding;

  const TravelMemoirApp({super.key, required this.showOnboarding});

  @override
  State<TravelMemoirApp> createState() => _TravelMemoirAppState();
}

class _TravelMemoirAppState extends State<TravelMemoirApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 이미 main에서 초기화했으므로 딜레이 후 바로 진입
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
      // 초기화 전이면 로딩화면, 완료되면 로그인 페이지로 이동
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const LoginPage(),
      routes: {'/app_shell': (context) => const AppShell()},
    );
  }
}
