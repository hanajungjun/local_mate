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
  late Stream<List<Map<String, dynamic>>> _roomStream;
  bool _isPartnerLeft = false;

  // ✅ 상대방이 가이드면 내가 여행자, 상대방이 여행자면 내가 가이드
  bool get _isTraveler => widget.targetUser['is_guide'] == true;

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessageStream(widget.roomId);

    _roomStream = supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', widget.roomId)
        .handleError((error) {
          debugPrint("📡 Realtime Stream Error: $error");
          // ✅ 타임아웃 시 3초 후 재연결
          if (mounted) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _roomStream = supabase
                      .from('chat_rooms')
                      .stream(primaryKey: ['id'])
                      .eq('id', widget.roomId)
                      .handleError((e) => debugPrint("📡 재연결 실패: $e"));
                });
              }
            });
          }
        });

    _updatePresence(true);
  }

  @override
  void dispose() {
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

  String _formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  // ────────────────────────────────────────
  // 🙋‍♂️ 가이드: 날짜/시간 선택 → chat_rooms 업데이트
  // ────────────────────────────────────────
  Future<void> _guideSelectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "투어 날짜를 선택하세요",
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "시작 시간을 선택하세요",
    );
    if (pickedTime == null || !mounted) return;

    final dateStr = pickedDate.toString().split(' ')[0]; // yyyy-MM-dd
    final timeStr = _formatTime24(pickedTime); // HH:mm

    await supabase
        .from('chat_rooms')
        .update({
          'meeting_date': dateStr,
          'meeting_time': timeStr,
          'schedule_status': 'request_confirm',
        })
        .eq('id', widget.roomId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📅 $dateStr $timeStr 투어 확정을 요청했습니다.")),
      );
    }
  }

  // ────────────────────────────────────────
  // 🙋‍♀️ 여행자: 최종 확정 → guide_schedules + user_schedules INSERT
  // ────────────────────────────────────────
  Future<void> _travelerConfirm(Map<String, dynamic> roomData) async {
    final myId = supabase.auth.currentUser!.id;
    final guideId = widget.targetUser['id'] as String?;
    final mDate = roomData['meeting_date'] as String?;
    final mTime = roomData['meeting_time'] as String?;

    if (guideId == null || mDate == null || mTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("❌ 일정 정보가 부족합니다.")));
      }
      return;
    }

    final tripDateStr = "$mDate $mTime:00+00";

    // ✅ 여행자 본인 닉네임 가져오기
    final myProfile = await supabase
        .from('users')
        .select('nickname')
        .eq('id', myId)
        .maybeSingle();
    final travelerName = myProfile?['nickname'] as String? ?? '여행자';
    final guideName = widget.targetUser['nickname'] as String? ?? '가이드';

    // request_id 있으면 travel_requests 제목 사용
    String guideTitle = '$travelerName와의 투어'; // 가이드 스케줄용
    String userTitle = '$guideName와의 투어'; // 여행자 스케줄용
    final requestId = roomData['request_id'] as String?;
    if (requestId != null) {
      final req = await supabase
          .from('travel_requests')
          .select('title')
          .eq('id', requestId)
          .maybeSingle();
      final reqTitle = req?['title'] as String?;
      if (reqTitle != null) {
        guideTitle = reqTitle;
        userTitle = reqTitle;
      }
    }

    try {
      // ① chat_rooms → confirmed
      await supabase
          .from('chat_rooms')
          .update({'schedule_status': 'confirmed'})
          .eq('id', widget.roomId);

      // ② travel_requests → confirmed (request_id 있을 때만)
      if (requestId != null) {
        await supabase
            .from('travel_requests')
            .update({'status': 'confirmed'})
            .eq('id', requestId);
      }

      // ③ guide_schedules → INSERT (여행자 이름으로)
      await supabase.from('guide_schedules').insert({
        'guide_id': guideId,
        'title': guideTitle,
        'trip_date': tripDateStr,
        'location': widget.targetUser['location_name'],
        'max_people': 1,
        'current_people': 1,
        'status': 'booked',
      });

      // ④ user_schedules → INSERT (가이드 이름으로)
      await supabase.from('user_schedules').insert({
        'user_id': myId,
        'guide_id': guideId,
        'title': userTitle,
        'partner_name': guideName,
        'trip_date': tripDateStr,
        'status': 'confirmed',
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🎉 투어가 최종 확정되었습니다!")));
      }
    } catch (e) {
      debugPrint("❌ 확정 처리 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 확정 중 오류: $e")));
      }
    }
  }

  void _onSend() async {
    if (_isPartnerLeft) return;
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _roomStream,
        builder: (context, roomSnapshot) {
          List<String> typingUsers = [];
          Map<String, dynamic> roomData = {};

          if (roomSnapshot.hasData && roomSnapshot.data!.isNotEmpty) {
            roomData = roomSnapshot.data!.first;

            // 퇴장 감지
            final activeUsers = List<String>.from(
              roomData['active_users'] ?? [],
            );
            final targetId = widget.targetUser['id'] as String?;
            final partnerLeft =
                targetId != null && !activeUsers.contains(targetId);

            if (partnerLeft != _isPartnerLeft) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isPartnerLeft = partnerLeft);
              });
            }

            typingUsers = List<String>.from(roomData['typing_users'] ?? []);
          }

          return Column(
            children: [
              _buildInfoBar(roomData),
              _buildTypingIndicator(typingUsers),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messageStream,
                  builder: (context, msgSnapshot) {
                    if (!msgSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = msgSnapshot.data!;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildMessageBubble(
                          isMe:
                              msg['sender_id'] == supabase.auth.currentUser!.id,
                          text: msg['content'] ?? '',
                          type: msg['message_type'],
                          imageUrl: msg['image_url'],
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBar(Map<String, dynamic> roomData) {
    final scheduleStatus = roomData['schedule_status'] as String? ?? 'none';
    final String? mDate = roomData['meeting_date'];
    final String? mTime = roomData['meeting_time'];

    String message;
    String? btnText;
    Color barColor;
    Color iconColor;

    switch (scheduleStatus) {
      case 'request_confirm':
        if (_isTraveler) {
          message = "📅 $mDate $mTime 투어 요청!";
          btnText = "최종 확정";
        } else {
          message = "승인을 기다리는 중입니다...";
          btnText = "수정하기";
        }
        barColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        break;

      case 'confirmed':
        message = "✅ 확정 완료! ($mDate $mTime) 🎉";
        barColor = Colors.green.shade50;
        iconColor = Colors.green;
        break;

      default: // none
        message = _isTraveler ? "가이드의 일정 제안을 기다리는 중입니다." : "투어 일정을 제안해 보세요.";
        btnText = _isTraveler ? null : "일정 제안";
        barColor = Colors.blue.shade50;
        iconColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: barColor,
      child: Row(
        children: [
          Icon(Icons.event, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          if (btnText != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () {
                if (!_isTraveler) {
                  // 가이드: 날짜 선택 (none → request_confirm, 수정하기도 동일)
                  _guideSelectDateTime();
                } else if (_isTraveler && scheduleStatus == 'request_confirm') {
                  // 여행자: 최종 확정
                  _travelerConfirm(roomData);
                }
              },
              child: Text(btnText),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(List<String> typingUsers) {
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
    return const SizedBox.shrink();
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
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: type == 'image' && imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
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
