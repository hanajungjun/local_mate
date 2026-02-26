import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/chat_service.dart'; // 💡 서비스 추가
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> targetUser;

  const ChatRoomPage({
    super.key,
    required this.roomId,
    required this.targetUser,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService(); //
  final supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _messageStream;

  @override
  void initState() {
    super.initState();
    // 💡 실시간 메시지 스트림 연결
    _messageStream = _chatService.getMessageStream(widget.roomId);
  }

  void _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    // 💡 서비스로 메시지 전송
    await _chatService.sendMessage(
      widget.roomId,
      supabase.auth.currentUser!.id,
      text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.targetUser['nickname'] ?? '메이트', //
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 💡 상단 정보 바 (가이드 관련 정보)
          _buildInfoBar(),

          // 💡 실시간 채팅 리스트
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe =
                        msg['sender_id'] == supabase.auth.currentUser!.id;
                    return _buildMessageBubble(
                      isMe: isMe,
                      text: msg['content'],
                    );
                  },
                );
              },
            ),
          ),

          // 입력창
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "메이트와 대화 중입니다.",
              style: TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "일정확인",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required bool isMe, required String text}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: isMe ? AppColors.travelingBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _onSend(),
                decoration: InputDecoration(
                  hintText: "메시지를 입력하세요...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _onSend,
              child: CircleAvatar(
                backgroundColor: AppColors.travelingBlue,
                radius: 22,
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
