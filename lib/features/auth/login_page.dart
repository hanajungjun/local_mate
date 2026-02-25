import 'dart:async';
import 'dart:io';
// import 'package:local_mate/env.dart'; // ⚠️ 주석
import 'package:flutter/material.dart';
// import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // ⚠️ 주석
// import 'package:google_sign_in/google_sign_in.dart'; // ⚠️ 주석
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // ⚠️ 주석
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:local_mate/app/app_shell.dart';
import 'package:local_mate/core/constants/app_colors.dart';
import 'package:local_mate/shared/styles/text_styles.dart';
import 'package:local_mate/core/widgets/popup/app_toast.dart';
import 'package:local_mate/core/widgets/popup/app_dialogs.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSub;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isReviewMode = false;

  @override
  void initState() {
    super.initState();
    _checkReviewMode();

    // 🎯 기존 인증 리스너 유지 (실제 연동 시 작동)
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) return;

      // 유저 정보 업데이트 로직 유지
      _handleAuthSuccess(user);
    });
  }

  Future<void> _handleAuthSuccess(User user) async {
    await supabase.from('users').upsert({
      'auth_uid': user.id,
      'provider': user.appMetadata['provider'] ?? 'email',
      'email': user.email,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'auth_uid');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  Future<void> _checkReviewMode() async {
    try {
      final data = await supabase
          .from('app_config')
          .select('is_review_mode')
          .single();
      if (mounted)
        setState(() => _isReviewMode = data['is_review_mode'] ?? false);
    } catch (e) {
      debugPrint("⚠️ 심사 모드 로드 실패: $e");
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- 소셜 로그인 함수들 (에러 방지용 주석 처리 및 토스트 메시지) ---

  Future<void> _loginWithKakao() async {
    AppToast.show(context, "카카오 SDK 설정이 필요합니다.");
    /* try {
      final token = await UserApi.instance.loginWithKakaoAccount();
      await supabase.auth.signInWithIdToken(provider: OAuthProvider.kakao, idToken: token.idToken!);
    } catch (e) { debugPrint('Kakao Login Error: $e'); } */
  }

  Future<void> _loginWithGoogle() async {
    AppToast.show(context, "구글 SDK 설정이 필요합니다.");
  }

  Future<void> _loginWithApple() async {
    AppToast.show(context, "애플 SDK 설정이 필요합니다.");
  }

  // 🚀 테스트용 하이패스: 로그인 없이 바로 홈으로!
  void _skipToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.blueGrey),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 27),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        if (_isReviewMode) _buildIdPwSection(),

                        _socialButton(
                          iconAsset: 'assets/icons/kakao.png',
                          color: AppColors.buttonBg,
                          text: 'login_kakao'.tr(),
                          onTap: _loginWithKakao,
                        ),
                        const SizedBox(height: 10),
                        _socialButton(
                          iconAsset: 'assets/icons/google.png',
                          color: AppColors.buttonBg,
                          text: 'login_google'.tr(),
                          onTap: _loginWithGoogle,
                        ),

                        if (Platform.isIOS) ...[
                          const SizedBox(height: 10),
                          _socialButton(
                            iconAsset: 'assets/icons/apple.png',
                            text: 'login_apple'.tr(),
                            onTap: _loginWithApple,
                            color: AppColors.buttonBg,
                          ),
                        ],

                        const SizedBox(height: 10),

                        // 🎯 [핵심 추가] 테스트용 하이패스 버튼
                        _socialButton(
                          color: Colors.black.withOpacity(0.7),
                          text: "테스트 모드로 시작하기",
                          onTap: _skipToHome,
                          textColor: Colors.white,
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 43),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 120),
          Text('landing_title'.tr(), style: AppTextStyles.landingTitle),
          const SizedBox(height: 5),
          Text('landing_subtitle'.tr(), style: AppTextStyles.landingSubtitle),
        ],
      ),
    );
  }

  Widget _buildIdPwSection() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          decoration: _inputDeco('아이디를 입력하세요'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: _inputDeco('비밀번호를 입력하세요'),
        ),
        const SizedBox(height: 10),
        _socialButton(
          color: AppColors.travelingBlue,
          text: 'login_sign_in'.tr(),
          onTap: _isLoading ? () {} : () {}, // 임시
          textColor: AppColors.textColor02,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            "────────  OR  ────────",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.inputText.withOpacity(0.2),
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _socialButton({
    String? iconAsset,
    required Color color,
    required String text,
    required VoidCallback onTap,
    Color textColor = AppColors.textColor01,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (iconAsset != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(iconAsset, width: 20, height: 20),
              ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
