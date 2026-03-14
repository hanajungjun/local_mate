import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/chat_service.dart';
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
  final ChatService _chatService = ChatService();
  final supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _messageStream;

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessageStream(widget.roomId);
    _updatePresence(true);
  }

  @override
  void dispose() {
    _updatePresence(false);
    _handleTyping("");
    _controller.dispose();
    super.dispose();
  }

  Future<void> _updatePresence(bool isActive) async {
    final myId = supabase.auth.currentUser!.id;
    try {
      await supabase.rpc(
        'update_room_presence',
        params: {
          'room_id': widget.roomId,
          'user_id': myId,
          'is_active': isActive,
        },
      );
    } catch (e) {
      debugPrint("❌ Presence 업데이트 실패: $e");
    }
  }

  void _handleTyping(String text) async {
    final myId = supabase.auth.currentUser!.id;
    try {
      await supabase.rpc(
        'update_typing_presence',
        params: {
          'room_id': widget.roomId,
          'user_id': myId,
          'is_typing': text.isNotEmpty,
        },
      );
    } catch (e) {
      debugPrint("❌ Typing 업데이트 실패: $e");
    }
  }

  void _onSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _handleTyping("");

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
          widget.targetUser['nickname'] ?? '메이트',
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
          _buildInfoBar(),
          _buildTypingIndicator(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe =
                        msg['sender_id'] == supabase.auth.currentUser!.id;

                    // ✅ 여기서 함수 호출만 합니다!
                    return _buildMessageBubble(
                      isMe: isMe,
                      text: msg['content'] ?? '',
                      type: msg['message_type'], // DB 컬럼명 확인 필수
                      imageUrl: msg['image_url'], // DB 컬럼명 확인 필수
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ✅ 통합된 메시지 버블 (텍스트/이미지 모두 대응)
  Widget _buildMessageBubble({
    required bool isMe,
    required String text,
    String? type,
    String? imageUrl,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: type == 'image'
            ? const EdgeInsets.all(4) // 이미지는 패딩 최소화
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: type == 'image' && imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 50),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('id', widget.roomId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final roomData = snapshot.data!.first;
          final typingUsers = List<String>.from(roomData['typing_users'] ?? []);
          final targetId = widget.targetUser['id'];

          if (typingUsers.contains(targetId)) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${widget.targetUser['nickname']}님이 입력 중입니다...",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
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
                onChanged: _handleTyping,
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
