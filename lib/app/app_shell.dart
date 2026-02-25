import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';
import 'package:local_mate/features/home/pages/home_page.dart';
import 'package:local_mate/features/discover/pages/discover_page.dart';
import 'package:local_mate/features/map/pages/map_view_page.dart';
import 'package:local_mate/features/chat/pages/chat_main_page.dart';
import 'package:local_mate/features/mypage/pages/my_profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 바텀 네비바 아이템이 5개이므로, pages 리스트도 정확히 5개여야 합니다.
    final List<Widget> pages = [
      HomePage(
        onGoToTravel: () => _onTabSelected(1),
        onStartRequest: () => debugPrint("🚀 공고 작성"),
        onStartGuide: () => debugPrint("🚀 가이드 시작"),
      ),
      const MapViewPage(), // index 1: 지도(내근처)
      const DiscoverPage(), // index 2: 매칭(스와이프)
      const ChatMainPage(), // index 3: 채팅
      const MyProfilePage(), // index 4: 내정보
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
        // 🎯 2. 버튼 순서를 페이지와 동일하게 일치시킴
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
