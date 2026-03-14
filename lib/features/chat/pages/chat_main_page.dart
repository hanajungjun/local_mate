import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'chat_list_page.dart';
import 'like_list_page.dart';

class ChatMainPage extends StatefulWidget {
  // ✅ 외부(AppShell)에서 '좋아요' 탭으로 바로 보내고 싶을 때 1을 넘겨줍니다.
  final int initialTabIndex;

  const ChatMainPage({
    super.key,
    this.initialTabIndex = 0, // 기본값은 '채팅' 탭
  });

  @override
  State<ChatMainPage> createState() => _ChatMainPageState();
}

class _ChatMainPageState extends State<ChatMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // ✅ 탭 컨트롤러 초기화 (length: 2)
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex, // ✅ 전달받은 인덱스로 시작!
    );
  }

  @override
  void didUpdateWidget(covariant ChatMainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ 앱이 켜진 상태에서 푸시를 받아 initialTabIndex가 바뀌면 탭을 강제로 전환합니다.
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("채팅", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController, // ✅ 직접 만든 컨트롤러 연결
          labelColor: AppColors.travelingBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.travelingBlue,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: "채팅"),
            Tab(text: "좋아요"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // ✅ 직접 만든 컨트롤러 연결
        children: const [ChatListPage(), LikeListPage()],
      ),
    );
  }
}
