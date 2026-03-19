import 'dart:async';
import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/chat/pages/chat_room_page.dart';
import 'package:localmate/services/chat_service.dart';
import 'package:localmate/services/tour_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourDetailPage extends StatefulWidget {
  final dynamic tourData;

  const TourDetailPage({super.key, required this.tourData});

  @override
  State<TourDetailPage> createState() => _TourDetailPageState();
}

class _TourDetailPageState extends State<TourDetailPage> {
  final supabase = Supabase.instance.client;
  final ChatService _chatService = ChatService();
  final TourService _tourService = TourService(); // ✅
  late TextEditingController _memoController;
  Timer? _debounceTimer;

  Map<String, dynamic>? _guideProfile;
  bool _isLoadingProfile = true;
  bool _isCancelling = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController(text: '');
    _loadGuideProfile();
    _loadLatestData();
  }

  Future<void> _loadLatestData() async {
    try {
      final res = await supabase
          .from('user_schedules')
          .select('user_memo,request_id')
          .eq('id', widget.tourData['id'])
          .maybeSingle();
      if (mounted && res != null) {
        setState(() {
          _memoController.text = res['user_memo']?.toString() ?? '';
          // widget.tourData에 request_id가 없을 경우를 대비해 보강
          widget.tourData['request_id'] = res['request_id'];
        });
      }
    } catch (e) {
      debugPrint("❌ 메모 로드 실패: $e");
      _memoController.text = widget.tourData['user_memo']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _memoController.dispose();
    super.dispose();
  }

  // ✅ [추가] 투어 시간이 지났는지 체크하는 로직
  bool _isTourFinished() {
    final tripDateStr = widget.tourData['trip_date']?.toString();
    if (tripDateStr == null) return false;

    try {
      final tripDate = DateTime.parse(tripDateStr).toLocal();
      // 현재 시간이 투어 시작 시간보다 이후면 '완료' 버튼 활성화
      return DateTime.now().isAfter(tripDate);
    } catch (e) {
      return false;
    }
  }

  // ✅ [추가] 여행 완료 및 리뷰 입력 다이얼로그
  Future<void> _showReviewDialog() async {
    int selectedRating = 5; // 기본 별점 5점
    final TextEditingController commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // 별점 실시간 변경을 위해 필요
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🎉 투어가 즐거우셨나요?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("가이드님에게 별점을 남겨주세요."),
              const SizedBox(height: 15),
              // 별점 선택 UI (간단 버전)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "가이드님께 감사의 한마디를 남겨주세요!",
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx); // 다이얼로그 닫기
                await _completeTour(
                  selectedRating,
                  commentController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.travelingBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "확정 및 리뷰 등록",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ [추가] 실제 완료 처리 로직
  Future<void> _completeTour(int rating, String comment) async {
    setState(() => _isCompleting = true);
    try {
      // 가이드 스케줄 ID를 찾기 위한 조회 로직 필요 (취소 로직에 있던 것과 동일)
      final guideScheduleRes = await supabase
          .from('guide_schedules')
          .select('id')
          .eq('guide_id', widget.tourData['guide_id'])
          .eq('trip_date', widget.tourData['trip_date'])
          .maybeSingle();

      if (guideScheduleRes == null) throw Exception("가이드 일정을 찾을 수 없습니다.");

      // 🏆 TourService 호출
      await _tourService.completeByTraveler(
        requestId: widget.tourData['request_id'].toString(),
        userScheduleId: widget.tourData['id'].toString(),
        guideScheduleId: guideScheduleRes['id'].toString(),
        guideId: widget.tourData['guide_id'].toString(),
        rating: rating,
        comment: comment.isEmpty ? "최고의 투어였습니다!" : comment,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎊 투어 확정 및 리뷰가 등록되었습니다!")),
        );
        Navigator.pop(context); // 목록으로 돌아가기
      }
    } catch (e) {
      debugPrint("❌ 완료 처리 에러: $e");
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _loadGuideProfile() async {
    final guideId = widget.tourData['guide_id']?.toString();
    if (guideId == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }
    try {
      final res = await supabase
          .from('users')
          .select('id, nickname, profile_image')
          .eq('id', guideId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _guideProfile = res;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 가이드 프로필 로드 실패: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveMemo(String text) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      try {
        await supabase
            .from('user_schedules')
            .update({'user_memo': text})
            .eq('id', widget.tourData['id']);
        debugPrint("✅ 메모 저장 완료");
      } catch (e) {
        debugPrint("❌ 메모 저장 실패: $e");
      }
    });
  }

  Future<void> _goToChat() async {
    final myId = supabase.auth.currentUser?.id;
    final guideId = widget.tourData['guide_id']?.toString();
    if (myId == null || guideId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final roomId = await _chatService.getOrCreateRoom(myId, guideId);
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              roomId: roomId,
              targetUser: {
                'id': guideId,
                'nickname': _guideProfile?['nickname'] ?? '가이드',
                'profile_image': _guideProfile?['profile_image'],
                'is_guide': true,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("❌ 채팅방 이동 실패: $e");
    }
  }

  // ✅ 취소 확인 다이얼로그
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
              "투어를 취소하면 가이드에게 알림이 전송됩니다.\n취소 사유를 입력해주세요.",
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

  // ✅ 실제 취소 처리
  Future<void> _cancelSchedule(String reason) async {
    setState(() => _isCancelling = true);

    try {
      final guideId = widget.tourData['guide_id']?.toString();
      final tripDate = widget.tourData['trip_date']?.toString();
      final requestId = widget.tourData['request_id']?.toString();
      if (guideId == null || tripDate == null || requestId == null) {
        throw Exception("일정 정보(ID 등)가 부족하여 취소할 수 없습니다.");
      }

      // guide_schedules 찾기
      final guideScheduleRes = await supabase
          .from('guide_schedules')
          .select('id')
          .eq('guide_id', guideId)
          .eq('trip_date', tripDate)
          .maybeSingle();

      if (guideScheduleRes == null) {
        throw Exception("가이드 일정을 찾을 수 없습니다.");
      }

      // chat_room 찾기
      final myId = supabase.auth.currentUser!.id;
      final chatRoomRes = await supabase
          .from('chat_rooms')
          .select('id')
          .or(
            'and(participant_a.eq.$myId,participant_b.eq.$guideId),and(participant_a.eq.$guideId,participant_b.eq.$myId)',
          )
          .maybeSingle();

      // ✅ DiscoverService.cancelSchedule 호출
      await _tourService.cancelSchedule(
        requestId: requestId,
        userScheduleId: widget.tourData['id'].toString(),
        guideScheduleId: guideScheduleRes['id'].toString(),
        chatRoomId: chatRoomRes?['id']?.toString() ?? '',
        cancelledByRole: 'traveler',
        reason: reason.isEmpty ? null : reason,
      );

      // 가이드에게 푸시 알림
      final guideUser = await supabase
          .from('users')
          .select('fcm_token')
          .eq('id', guideId)
          .maybeSingle();

      if (guideUser?['fcm_token'] != null) {
        await supabase.functions.invoke(
          'send-push',
          body: {
            'targetType': 'token',
            'targetValue': guideUser!['fcm_token'],
            'title': '투어가 취소되었습니다 😢',
            'body': reason.isEmpty ? '여행자가 투어를 취소했습니다.' : '취소 사유: $reason',
            'data': {'type': 'cancel'},
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("투어가 취소되었습니다.")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ 취소 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("취소 중 오류가 발생했습니다: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Map<String, String> _parseTripDate() {
    final tripDate = widget.tourData['trip_date']?.toString() ?? '';
    if (tripDate.isEmpty) return {'date': '날짜 미정', 'time': '시간 미정'};
    try {
      final dt = DateTime.parse(tripDate).toLocal();
      final date =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return {'date': date, 'time': time};
    } catch (_) {
      return {'date': tripDate, 'time': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.tourData['title']?.toString() ?? '투어';
    final bool isFinished = _isTourFinished(); // ✅ 여기서 체크
    final parsed = _parseTripDate();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "확정된 투어 정보",
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
      body: _isCancelling
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isLoadingProfile
                      ? _buildProfileSkeleton()
                      : _buildGuideHeader(_guideProfile),
                  const SizedBox(height: 30),

                  const Text(
                    "투어 제목",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),

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
                      color: AppColors.travelingBlue.withOpacity(0.05),
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
                            color: AppColors.travelingBlue,
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
                  const Divider(height: 60),

                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.orange),
                      const SizedBox(width: 5),
                      const Text(
                        "나만의 투어 메모",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    maxLines: 5,
                    onChanged: _saveMemo,
                    decoration: InputDecoration(
                      hintText: "준비물이나 가이드님께 물어볼 내용을 적어보세요.",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. 가이드와 채팅하기 버튼 (항상 노출)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _goToChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.travelingBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "가이드와 채팅하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ 2. [완료 확정] 버튼: 투어 시간이 지났을 때만 노출
                  if (isFinished) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _showReviewDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // 완료는 초록색!
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "투어 완료 확정 & 리뷰 쓰기",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. 취소하기 버튼 (필요에 따라 완료 후엔 숨길 수도 있음)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton(
                      onPressed: _showCancelDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        "투어 취소하기",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildGuideHeader(Map<String, dynamic>? guide) {
    final nickname = guide?['nickname']?.toString() ?? '로컬 메이트';
    final profileImages = guide?['profile_image'];
    String? profileUrl;
    if (profileImages is List && profileImages.isNotEmpty) {
      profileUrl = profileImages[0]?.toString();
    } else if (profileImages is String) {
      profileUrl = profileImages;
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blueAccent,
          backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
          child: profileUrl == null
              ? const Icon(Icons.person, color: Colors.white, size: 28)
              : null,
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$nickname 메이트",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              "현지 전문 가이드",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
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
