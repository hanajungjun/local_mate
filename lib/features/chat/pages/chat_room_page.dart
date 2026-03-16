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

  bool _isPartnerLeft = false; // ✅ 상대방 나갔는지 여부

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessageStream(widget.roomId);
    _updatePresence(true);
    _checkPartnerStatus(); // ✅ 진입 시 상태 확인
  }

  @override
  void dispose() {
    _updatePresence(false);
    _handleTyping("");
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(String offerId) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    // 💡 선택된 날짜와 시간을 가공 (예: "2026-03-20 14:00")
    final String finalDateTime =
        "${pickedDate.toString().split(' ')[0]} ${pickedTime.format(context)}";

    // DB 업데이트
    await supabase
        .from('offers')
        .update({
          'status': 'request_confirm',
          'confirmed_at': finalDateTime, // DB에 컬럼 추가 필요!
        })
        .eq('id', offerId);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("📅 $finalDateTime 투어 확정을 요청했습니다.")));
  }

  // ✅ 상대방이 나갔는지 확인
  Future<void> _checkPartnerStatus() async {
    try {
      final left = await _chatService.isPartnerLeft(widget.roomId);
      if (mounted) setState(() => _isPartnerLeft = left);
    } catch (e) {
      debugPrint("❌ 상대방 상태 확인 실패: $e");
    }
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

  // 🔘 상단 바 버튼 클릭 시 실행될 실제 로직
  void _handleTourAction(
    String status,
    bool isTraveler,
    String? offerId,
  ) async {
    if (offerId == null) return;

    if (!isTraveler) {
      // 🙋‍♂️ 가이드: 날짜와 시간을 선택합니다.
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: "투어 날짜를 선택하세요",
      );

      if (pickedDate == null) return;

      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        helpText: "시작 시간을 선택하세요",
      );

      if (pickedTime == null) return;

      final dateStr = pickedDate.toString().split(' ')[0]; // yyyy-mm-dd
      final timeStr = pickedTime.format(context); // hh:mm AM/PM

      await supabase
          .from('offers')
          .update({
            'status': 'request_confirm',
            'meeting_date': dateStr,
            'meeting_time': timeStr,
          })
          .eq('id', offerId);
    } else {
      // 🙋‍♀️ 여행자: 최종 확정 도장 찍기
      await supabase
          .from('offers')
          .update({'status': 'confirmed'})
          .eq('id', offerId);
      final requestId = widget.targetUser['request_id'];
      if (requestId != null) {
        await supabase
            .from('travel_requests')
            .update({'status': 'confirmed'})
            .eq('id', requestId);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("🎉 투어가 최종 확정되었습니다!")));
    }
  }

  void _onSend() async {
    if (_isPartnerLeft) return; // ✅ 상대방 나간 경우 전송 차단
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
                    return _buildMessageBubble(
                      isMe: isMe,
                      text: msg['content'] ?? '',
                      type: msg['message_type'],
                      imageUrl: msg['image_url'],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(), // ✅ 상대방 나간 경우 내부에서 분기
        ],
      ),
    );
  }

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
            ? const EdgeInsets.all(4)
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('offers')
          .stream(primaryKey: ['id'])
          .eq('request_id', widget.targetUser['request_id'] ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildInfoContainer("메이트와 대화 중입니다.", Colors.blue.shade50);
        }

        final offer = snapshot.data!.firstWhere(
          (o) => o['guide_id'] == widget.targetUser['id'],
          orElse: () => {},
        );

        if (offer.isEmpty) {
          return _buildInfoContainer("메이트와 대화 중입니다.", Colors.blue.shade50);
        }

        final status = offer['status'] ?? 'matched';
        final bool isTraveler = widget.targetUser['guide_bio'] == null;

        // 💡 날짜/시간 데이터 가져오기 (DB 컬럼명: meeting_date, meeting_time 예정)
        final String? mDate = offer['meeting_date'];
        final String? mTime = offer['meeting_time'];

        String message = "메이트와 일정을 합의해 주세요.";
        String? btnText;
        Color barColor = Colors.blue.shade50;

        if (status == 'request_confirm') {
          message = isTraveler ? "📅 $mDate $mTime 투어 요청!" : "승인을 기다리는 중입니다...";
          btnText = isTraveler ? "최종 확정" : "수정하기"; // 가이드는 수정 가능
          barColor = Colors.orange.shade50;
        } else if (status == 'confirmed') {
          message = "확정 완료! ($mDate $mTime) 🎉";
          barColor = Colors.green.shade50;
        } else {
          if (!isTraveler) btnText = "확정 요청";
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: barColor,
          child: Row(
            children: [
              Icon(
                status == 'confirmed' ? Icons.check_circle : Icons.event,
                size: 18,
                color: status == 'confirmed' ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: status == 'confirmed'
                        ? Colors.green.shade900
                        : Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (btnText != null && !_isPartnerLeft)
                ElevatedButton(
                  onPressed: () => _handleTourAction(
                    status,
                    isTraveler,
                    offer['id']?.toString(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnText == "최종 확정"
                        ? Colors.orange
                        : AppColors.travelingBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(60, 32),
                    elevation: 0,
                  ),
                  child: Text(
                    btnText,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 💡 중복 코드를 줄이기 위한 위젯 헬퍼
  Widget _buildInfoContainer(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: color,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.blue)),
        ],
      ),
    );
  }

  // ✅ 상대방 나간 경우 입력창 대신 안내 배너 표시
  Widget _buildInputArea() {
    if (_isPartnerLeft) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, color: Colors.grey.shade400, size: 18),
              const SizedBox(width: 8),
              Text(
                "상대방이 채팅방을 나갔습니다.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // 기존 입력창
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
