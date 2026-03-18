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

final GlobalKey<AppShellState> appShellKey = GlobalKey<AppShellState>();

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  int _chatInitialTab = 0;
  bool _isTraveler = true; // ✅ 모드 상태 추가

  final _loginService = LoginService();
  final GlobalKey<DiscoverPageState> _discoverKey =
      GlobalKey<DiscoverPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewUserAndShowDialog();
    });
  }

  void goToTab(int index, {int chatTab = 0}) {
    setState(() {
      _currentIndex = index;
      _chatInitialTab = chatTab;
    });
  }

  Future<void> _checkNewUserAndShowDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final isNew = await _loginService.isNewUser(user.id);

    if (isNew && mounted) {
      final bool? shouldEdit = await AppDialogs.showConfirm(
        context: context,
        title: 'welcome_title',
        message: 'profile_setup_prompt',
        confirmLabel: 'go_setup',
      );

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
    // 💡 기존의 pages 리스트 정의는 그대로 두거나,
    // 아래 Stack 내부에서 직접 호출하는 것이 메모리 관리에 더 명확합니다.

    return Scaffold(
      extendBody: true,
      // ⬇️ IndexedStack 대신 Stack으로 변경
      body: Stack(
        children: [
          // 0: 홈 (상태 유지)
          Offstage(
            offstage: _currentIndex != 0,
            child: HomePage(
              onGoToTravel: () => _onTabSelected(2),
              onModeChanged: (isTraveler) {
                debugPrint("🔔 모드 변경: ${isTraveler ? '여행자' : '가이드'}");
                setState(() => _isTraveler = isTraveler);
                _discoverKey.currentState?.refreshData();
              },
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
          ),

          // 1: 지도 (✅ 탭 클릭 시마다 새로 빌드하여 initState 호출 유도)
          if (_currentIndex == 1) const MapViewPage(),

          // 2: 찾기 (상태 유지)
          if (_currentIndex == 2) DiscoverPage(key: _discoverKey),

          // 3: 채팅 (상태 유지)
          Offstage(
            offstage: _currentIndex != 3,
            child: ChatMainPage(initialTabIndex: _chatInitialTab),
          ),

          // 4: 내정보 (상태 유지)
          Offstage(offstage: _currentIndex != 4, child: const MyProfilePage()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.travelingBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: '찾기'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }
}
