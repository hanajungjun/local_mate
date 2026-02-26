import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/home/pages/home_page.dart';
import 'package:localmate/features/discover/pages/discover_page.dart';
import 'package:localmate/features/map/pages/map_view_page.dart';
import 'package:localmate/features/chat/pages/chat_main_page.dart';
import 'package:localmate/features/mypage/my_profile_page.dart';

import 'package:localmate/services/login_service.dart';
import 'package:localmate/core/widgets/popup/app_dialogs.dart';
import 'package:localmate/features/mypage/profile/profile_edit_page.dart';
import 'package:localmate/features/matching/pages/request_create_page.dart';
import 'package:localmate/features/matching/pages/guide_matching_list_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final _loginService = LoginService(); // ✅ 서비스 인스턴스

  @override
  void initState() {
    super.initState();

    // ✅ 🎯 핵심: 메인 화면이 그려진 직후 신규 유저인지 확인하여 팝업을 띄웁니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewUserAndShowDialog();
    });
  }

  // ✅ 신규 유저 체크 및 다이얼로그 로직
  Future<void> _checkNewUserAndShowDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. 서비스에 물어보기: "이 형님, 신규 유저야?"
    final isNew = await _loginService.isNewUser(user.id);

    if (isNew && mounted) {
      // 2. 형님이 만든 멋진 컨펌 다이얼로그 호출
      final bool? shouldEdit = await AppDialogs.showConfirm(
        context: context,
        title: 'welcome_title', // "환영합니다!"
        message: 'profile_setup_prompt', // "매칭을 위해 프로필을 완성할까요?"
        confirmLabel: 'go_setup', // "네, 지금 할게요"
      );

      // 3. '네'라고 하면 프로필 수정 화면으로 슝!
      if (shouldEdit == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileEditPage(isFirstLogin: true),
          ),
        );
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(
        onGoToTravel: () => _onTabSelected(1),
        onStartRequest: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RequestCreatePage()),
          );
        },
        onStartGuide: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GuideMatchingListPage(),
            ),
          );
        },
      ),

      const MapViewPage(),
      const DiscoverPage(),
      const ChatMainPage(),
      const MyProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.travelingBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: '매칭'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }
}
