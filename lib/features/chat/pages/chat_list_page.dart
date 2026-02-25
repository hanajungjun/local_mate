import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';
import 'chat_room_page.dart'; // 곧 만들 파일

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "채팅",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView.separated(
        itemCount: 3,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          return _buildChatTile(
            context,
            name: index == 0 ? "망원동 김선생" : (index == 1 ? "제주 지니" : "행궁동 장인"),
            lastMsg: index == 0
                ? "네, 내일 2시에 망원역 2번 출구에서 뵐게요!"
                : "제안서를 확인해 주세요.",
            time: "오후 2:30",
            isUnread: index == 0,
          );
        },
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context, {
    required String name,
    required String lastMsg,
    required String time,
    required bool isUnread,
  }) {
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomPage(userName: name)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, color: Colors.grey),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          lastMsg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isUnread ? Colors.black87 : Colors.grey,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      trailing: isUnread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
