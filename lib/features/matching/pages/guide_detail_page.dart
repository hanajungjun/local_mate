import 'dart:async';
import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/chat/pages/chat_room_page.dart';
import 'package:localmate/services/chat_service.dart';
import 'package:localmate/services/tour_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuideDetailPage extends StatefulWidget {
  final dynamic scheduleData;
  const GuideDetailPage({super.key, required this.scheduleData});

  @override
  State<GuideDetailPage> createState() => _GuideDetailPageState();
}

class _GuideDetailPageState extends State<GuideDetailPage> {
  final supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  final TourService _tourService = TourService();
  late TextEditingController _memoController;
  Timer? _debounceTimer;

  Map<String, dynamic>? _travelerProfile;
  bool _isLoadingProfile = true;
  bool _isConfirming = false;
  bool _isCancelling = false;
  String _travelerStatus = 'accepted'; // ✅ 여행자의 매칭 상태 저장

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: '');
    _loadLatestData();
    _loadTravelerProfile();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  // 1. 여행자 상태 체크 (버튼 활성화용)
  Future<void> _checkTravelerStatus(String requestId) async {
    try {
      final res = await supabase
          .from('travel_requests')
          .select('status')
          .eq('id', requestId)
          .maybeSingle();
      if (mounted) {
        setState(() => _travelerStatus = res?['status'] ?? 'accepted');
      }
    } catch (e) {
      debugPrint("❌ 여행자 상태 체크 실패: $e");
    }
  }

  // 2. 가이드 최종 종료 확인 실행
  Future<void> _handleConfirmFinish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "투어 종료 확정",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "오늘 투어를 모두 마치셨나요?\n종료를 확정하면 여행자 리뷰가 가이드 점수에 반영됩니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("아니요", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.travelingPurple,
            ),
            child: const Text(
              "종료 확정",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConfirming = true);
    try {
      await _tourService.confirmByGuide(
        guideId: supabase.auth.currentUser!.id,
        guideScheduleId: widget.scheduleData['id'].toString(),
        requestId: _travelerProfile?['request_id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎊 투어가 공식적으로 종료되었습니다! 고생하셨습니다.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ 아직 여행자가 완료 확정을 하지 않았습니다.")),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  // --- 기존 데이터 로드 메서드들 ---

  Future<void> _loadLatestData() async {
    try {
      final res = await supabase
          .from('guide_schedules')
          .select('guide_memo')
          .eq('id', widget.scheduleData['id'])
          .maybeSingle();
      if (mounted) {
        _memoController.text = res?['guide_memo']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint("❌ 메모 로드 실패: $e");
    }
  }

  Future<void> _loadTravelerProfile() async {
    try {
      final guideId = supabase.auth.currentUser?.id;
      final tripDate = widget.scheduleData['trip_date']?.toString();

      if (guideId == null || tripDate == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final userSchedule = await supabase
          .from('user_schedules')
          .select('user_id, id, request_id')
          .eq('guide_id', guideId)
          .eq('trip_date', tripDate)
          .maybeSingle();

      if (userSchedule != null) {
        final profile = await supabase
            .from('users')
            .select('id, nickname, profile_image, fcm_token')
            .eq('id', userSchedule['user_id'])
            .maybeSingle();

        if (mounted) {
          setState(() {
            _travelerProfile = {
              ...?profile,
              'user_schedule_id': userSchedule['id'],
              'request_id': userSchedule['request_id'],
            };
            _isLoadingProfile = false;
          });
          // ✅ 프로필 로드 후 여행자 상태 체크 호출
          _checkTravelerStatus(userSchedule['request_id']);
        }
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint("❌ 여행자 프로필 로드 실패: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- 버튼 및 UI 헬퍼 메서드들 ---

  bool _isTourTimePassed() {
    final tripDateStr = widget.scheduleData['trip_date']?.toString();
    if (tripDateStr == null) return false;
    return DateTime.now().isAfter(DateTime.parse(tripDateStr));
  }

  @override
  Widget build(BuildContext context) {
    final bool isTimePassed = _isTourTimePassed();
    final bool canConfirm = _travelerStatus == 'completed';
    final String title = widget.scheduleData['title']?.toString() ?? '투어';
    final parsed = _parseTripDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "가이드 일정 상세",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isConfirming || _isCancelling
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ [수정] 로딩 중일 때 스켈레톤을 보여줍니다!
                  _isLoadingProfile
                      ? _buildProfileSkeleton()
                      : _buildTravelerHeader(_travelerProfile),

                  const SizedBox(height: 30),
                  _buildInfoSection("투어 제목", title),
                  const SizedBox(height: 20),

                  const Text(
                    "투어 일정",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.travelingPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed['date']!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.travelingPurple,
                          ),
                        ),
                        if (parsed['time']!.isNotEmpty)
                          Text(
                            "${parsed['time']} 시작",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ... 중간 생략 (장소, 메모 입력 TextField 등 기존 UI 유지) ...
                  const Divider(height: 60),

                  // 🏁 하단 버튼 영역
                  const SizedBox(height: 10),

                  // 1. 채팅하기
                  _buildActionButton(
                    text: "여행자와 채팅하기",
                    color: AppColors.travelingPurple,
                    onPressed: _travelerProfile != null ? _goToChat : null,
                  ),
                  const SizedBox(height: 12),

                  // 2. [가이드 전용] 투어 최종 종료 확인 버튼
                  if (isTimePassed)
                    _buildActionButton(
                      text: canConfirm ? "오늘 투어 종료 확정하기" : "여행자의 완료 확정 대기 중...",
                      color: canConfirm ? Colors.green : Colors.grey.shade400,
                      onPressed: canConfirm ? _handleConfirmFinish : null,
                      icon: Icons.verified_user,
                    ),

                  const SizedBox(height: 12),

                  // 3. 취소하기 (여행자가 아직 완료 안 했을 때만)
                  if (!canConfirm)
                    _buildOutlinedButton(
                      text: "투어 취소하기",
                      onPressed: _showCancelDialog,
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // --- 보조 위젯 및 기타 메서드들 ---

  Map<String, String> _parseTripDate() {
    final tripDate = widget.scheduleData['trip_date']?.toString() ?? '';
    if (tripDate.isEmpty) return {'date': '날짜 미정', 'time': '시간 미정'};
    try {
      final dt = DateTime.parse(tripDate).toLocal();
      return {
        'date':
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
        'time':
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      };
    } catch (_) {
      return {'date': tripDate, 'time': ''};
    }
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoSection(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value?.toString() ?? '-',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTravelerHeader(Map<String, dynamic>? traveler) {
    final nickname = traveler?['nickname']?.toString() ?? '여행자';
    final profileImages = traveler?['profile_image'];
    String? profileUrl;
    if (profileImages is List && profileImages.isNotEmpty)
      profileUrl = profileImages[0]?.toString();
    else if (profileImages is String)
      profileUrl = profileImages;

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.travelingPurple.withOpacity(0.2),
          backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
          child: profileUrl == null
              ? const Icon(
                  Icons.person,
                  color: AppColors.travelingPurple,
                  size: 28,
                )
              : null,
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$nickname 님",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "여행자",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveMemo(String text) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      try {
        await supabase
            .from('guide_schedules')
            .update({'guide_memo': text})
            .eq('id', widget.scheduleData['id']);
        debugPrint("✅ 가이드 메모 저장 완료");
      } catch (e) {
        debugPrint("❌ 메모 저장 실패: $e");
      }
    });
  }

  Future<void> _goToChat() async {
    final myId = supabase.auth.currentUser?.id;
    final travelerId = _travelerProfile?['id']?.toString();
    if (myId == null || travelerId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final roomId = await _chatService.getOrCreateRoom(myId, travelerId);
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              roomId: roomId,
              targetUser: {
                'id': travelerId,
                'nickname': _travelerProfile?['nickname'] ?? '여행자',
                'profile_image': _travelerProfile?['profile_image'],
                'is_guide': false,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showCancelDialog() async {
    final TextEditingController reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "투어 취소",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "투어를 취소하면 여행자에게 알림이 전송됩니다.\n취소 사유를 입력해주세요.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "취소 사유 (선택)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("돌아가기", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              "취소하기",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _cancelSchedule(reasonController.text.trim());
  }

  Future<void> _cancelSchedule(String reason) async {
    setState(() => _isCancelling = true);
    try {
      final myId = supabase.auth.currentUser!.id;
      final travelerId = _travelerProfile?['id']?.toString();
      final userScheduleId = _travelerProfile?['user_schedule_id']?.toString();
      final requestId = _travelerProfile?['request_id']?.toString();
      if (travelerId == null || userScheduleId == null || requestId == null)
        throw Exception("취소 정보 누락");
      final chatRoomRes = await supabase
          .from('chat_rooms')
          .select('id')
          .or(
            'and(participant_a.eq.$myId,participant_b.eq.$travelerId),and(participant_a.eq.$travelerId,participant_b.eq.$myId)',
          )
          .maybeSingle();
      await _tourService.cancelSchedule(
        requestId: requestId,
        userScheduleId: userScheduleId,
        guideScheduleId: widget.scheduleData['id'].toString(),
        chatRoomId: chatRoomRes?['id']?.toString() ?? '',
        cancelledByRole: 'guide',
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("투어가 취소되었습니다.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("취소 중 오류: $e")));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _buildProfileSkeleton() {
    return Row(
      children: [
        CircleAvatar(radius: 30, backgroundColor: Colors.grey.shade200),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 80,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
