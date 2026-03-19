import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

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
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  // ✅ 상대방이 가이드면 내가 여행자, 상대방이 여행자면 내가 가이드
  bool get _isTraveler => widget.targetUser['is_guide'] == true;

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessageStream(widget.roomId);

    _roomStream = supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', widget.roomId);
    debugPrint("🔍 roomId: ${widget.roomId}");
    // ✅ 방 진입 시: 1) Presence 업데이트 (나 들어왔다!)
    _updatePresence(true);
    // ✅ 2) [핵심 추가] RPC 호출: 상대방 메시지 전부 읽음 처리
    _markAsRead();
  }

  @override
  void dispose() {
    _handleTyping("");
    // ✅ 방 나갈 때: active_users에서 나를 제거
    _updatePresence(false);
    _controller.dispose();
    super.dispose();
  }

  // 📸 이미지 선택 및 전송 처리 함수
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('사진 촬영'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (photo != null) _sendImage(photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                Navigator.pop(context);

                // ✅ 영상은 선택 못 하게 이미지 타입만 필터링 (requestType 추가)
                final List<AssetEntity>? assets = await AssetPicker.pickAssets(
                  context,
                  pickerConfig: const AssetPickerConfig(
                    maxAssets: 1,
                    requestType: RequestType.image, // 👈 여기서 이미지만 나오게 설정!
                  ),
                );

                if (assets != null && assets.isNotEmpty) {
                  // ✅ 혹시 모르니 타입 한 번 더 체크 (방어 코드)
                  if (assets.first.type == AssetType.video) {
                    _showVideoAlert();
                    return;
                  }

                  final file = await assets.first.file;
                  if (file != null) _sendImage(file);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 영상 전송 불가 안내 알림창
  void _showVideoAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("알림"),
        content: const Text("동영상 전송 기능은 현재 준비 중입니다.\n사진만 전송해 주세요!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendImage(dynamic file) async {
    setState(() => _isUploading = true); // 로딩 시작
    try {
      await _chatService.sendImageMessage(
        widget.roomId,
        supabase.auth.currentUser!.id,
        file,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false); // 로딩 끝
    }
  }

  // ✅ [추가] 읽음 처리 RPC 함수 호출
  Future<void> _markAsRead() async {
    final myId = supabase.auth.currentUser!.id;
    try {
      await supabase.rpc(
        'mark_messages_as_read', // 준님이 만드신 RPC 함수명
        params: {'p_room_id': widget.roomId, 'p_user_id': myId},
      );
    } catch (e) {
      debugPrint("❌ 읽음 처리 RPC 실패: $e");
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

  String _formatTime24(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  // ────────────────────────────────────────
  // 🙋‍♂️ 가이드: 일정 제안 팝업
  // ────────────────────────────────────────
  Future<void> _guideSelectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: "투어 날짜 선택",
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "시작 시간 선택",
    );
    if (pickedTime == null || !mounted) return;

    final dateStr = pickedDate.toString().split(' ')[0];
    final timeStr = _formatTime24(pickedTime);

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
  // 🙋‍♀️ 여행자: 투어 최종 확정
  // ────────────────────────────────────────
  Future<void> _travelerConfirm(Map<String, dynamic> roomData) async {
    final myId = supabase.auth.currentUser!.id;
    final guideId = widget.targetUser['id'] as String?;
    final mDate = roomData['meeting_date'] as String?;
    final mTime = roomData['meeting_time'] as String?;

    if (guideId == null || mDate == null || mTime == null) return;

    final tripDateStr = "$mDate $mTime:00+00";

    try {
      await supabase
          .from('chat_rooms')
          .update({'schedule_status': 'confirmed'})
          .eq('id', widget.roomId);

      final requestId = roomData['request_id'] as String?;
      if (requestId != null) {
        await supabase
            .from('travel_requests')
            .update({'status': 'confirmed'})
            .eq('id', requestId);
      }

      // 가이드 스케줄 추가
      await supabase.from('guide_schedules').insert({
        'guide_id': guideId,
        'title': roomData['last_message'] ?? '투어 확정',
        'trip_date': tripDateStr,
        'location': widget.targetUser['location_name'] ?? '대구',
        'status': 'booked',
      });

      // 유저 스케줄 추가
      await supabase.from('user_schedules').insert({
        'user_id': myId,
        'guide_id': guideId,
        'title': roomData['last_message'] ?? '투어 확정',
        'partner_name': widget.targetUser['nickname'] ?? '가이드',
        'trip_date': tripDateStr,
        'status': 'confirmed',
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("🎉 투어가 최종 확정되었습니다!")));
      }
    } catch (e) {
      debugPrint("❌ 확정 에러: $e");
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
          List<String> activeUsers = []; // ✅ 선언 위치 확인

          if (roomSnapshot.hasData && roomSnapshot.data!.isNotEmpty) {
            roomData = roomSnapshot.data!.first;
            // ✅ 현재 방에 접속 중인 유저 리스트 (실시간 '1' 제거용)
            activeUsers = List<String>.from(roomData['active_users'] ?? []);

            final leftUsers = List<String>.from(roomData['left_users'] ?? []);
            final targetId = widget.targetUser['id'] as String?;
            final partnerLeft =
                targetId != null && leftUsers.contains(targetId);

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
              if (_isUploading) // ✅ 전송 중일 때 상단에 로딩바 표시
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.travelingBlue,
                  ),
                ),
              _buildTypingIndicator(typingUsers),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messageStream,
                  builder: (context, msgSnapshot) {
                    if (!msgSnapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final messages = msgSnapshot.data!;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final String senderId = msg['sender_id'] ?? '';
                        final bool isMe =
                            senderId == supabase.auth.currentUser!.id;

                        final targetId = widget.targetUser['id'] as String?;
                        final bool isRead =
                            (msg['is_read'] == true) ||
                            (isMe &&
                                targetId != null &&
                                activeUsers.contains(targetId));

                        // ✅ 여기를 수정합니다! (파라미터 이름들을 msg 하나로 통일)
                        return _buildMessageBubble(
                          msg: msg, // 메시지 데이터 통째로 전달
                          isMe: isMe,
                          isRead: isRead,
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

  Widget _buildMessageBubble({
    required Map<String, dynamic> msg,
    required bool isMe,
    required bool isRead,
  }) {
    final String text = msg['content'] ?? '';
    final String? type = msg['message_type'];
    final String? imageUrl = msg['image_url'];

    return GestureDetector(
      onLongPress: () => _showReportDialog(msg['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // [내가 보낸 메시지일 때] 숫자 '1' 표시
              if (isMe && !isRead)
                const Padding(
                  padding: EdgeInsets.only(right: 6, bottom: 2),
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // 메시지 버블 (여기가 핵심)
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 250,
                ), // ✅ 최대 가로 폭 고정
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
                // ✅ 이미지일 때와 텍스트일 때 여백 처리를 다르게 해서 크기 고정
                child: type == 'image' && imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: 250, // ✅ 가로 크기 강제 고정 (Overflow 방지)
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 250,
                              height: 200,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            );
                          },
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 신고 팝업 함수
  void _showReportDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "메시지 신고",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text("이 메시지를 부적절한 콘텐츠로 신고하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.reportMessage(
                messageId: messageId,
                roomId: widget.roomId,
                reason: "부적절한 콘텐츠",
              );
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("신고가 접수되었습니다.")));
              }
            },
            child: const Text("신고하기", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(Map<String, dynamic> roomData) {
    // ✅ 데이터 아직 안 왔으면 빈 바 표시
    if (roomData.isEmpty) {
      return Container(height: 40, color: Colors.blue.withOpacity(0.05));
    }
    final scheduleStatus = roomData['schedule_status'] as String? ?? 'none';
    final String? mDate = roomData['meeting_date'];
    final String? mTime = roomData['meeting_time'];

    debugPrint("🔍 roomData: $roomData"); // ✅ 추가
    debugPrint("🔍 schedule_status: ${roomData['schedule_status']}"); // ✅ 추가
    debugPrint("🔍 _isTraveler: $_isTraveler"); // ✅ 추가

    String message;
    String? btnText;
    Color iconColor = Colors.blue;

    switch (scheduleStatus) {
      case 'request_confirm':
        message = _isTraveler ? "📅 $mDate $mTime 투어 요청!" : "승인을 기다리는 중입니다...";
        btnText = _isTraveler ? "최종 확정" : "수정하기";
        iconColor = Colors.orange;
        break;
      case 'confirmed':
        message = "✅ 확정 완료! ($mDate $mTime)";
        btnText = null;
        iconColor = Colors.green;
        break;
      default:
        message = _isTraveler ? "가이드의 일정을 기다리는 중입니다." : "투어 일정을 제안해 보세요.";
        btnText = _isTraveler ? null : "일정 제안";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: iconColor.withOpacity(0.1),
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
              onPressed: () =>
                  _isTraveler && scheduleStatus == 'request_confirm'
                  ? _travelerConfirm(roomData)
                  : _guideSelectDateTime(),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
              ),
              child: Text(btnText),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(List<String> typingUsers) {
    if (typingUsers.contains(widget.targetUser['id'])) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "${widget.targetUser['nickname']}님이 입력 중입니다...",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputArea() {
    if (_isPartnerLeft) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.grey.shade100,
        child: const Center(
          child: Text("상대방이 채팅방을 나갔습니다.", style: TextStyle(color: Colors.grey)),
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
              onPressed: _pickImage, // ✅ 여기에 연결!
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _handleTyping,
                onSubmitted: (_) => _onSend(),
                decoration: InputDecoration(
                  hintText: "메시지 입력...",
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
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.travelingBlue),
              onPressed: _onSend,
            ),
          ],
        ),
      ),
    );
  }
}
