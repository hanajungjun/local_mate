import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';
import 'chat_list_page.dart';
import 'like_list_page.dart';

class ChatMainPage extends StatelessWidget {
  const ChatMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 탭 개수
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "채팅",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          bottom: TabBar(
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
        body: const TabBarView(
          children: [
            ChatListPage(), // 형님이 만든 기존 페이지
            LikeListPage(), // 새로 만들 페이지
          ],
        ),
      ),
    );
  }
}
