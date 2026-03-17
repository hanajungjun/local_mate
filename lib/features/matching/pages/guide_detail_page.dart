import 'dart:async';
import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/chat/pages/chat_room_page.dart';
import 'package:localmate/services/chat_service.dart';
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
  late TextEditingController _memoController;
  Timer? _debounceTimer;

  Map<String, dynamic>? _travelerProfile;
  bool _isLoadingProfile = true;

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

  /// guide_schedules에서 최신 데이터 조회 (메모 포함)
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

  /// user_schedules에서 여행자 찾기 → users 테이블로 프로필 조회
  Future<void> _loadTravelerProfile() async {
    try {
      // guide_schedules의 trip_date + guide_id로 매칭된 user_schedules 찾기
      final guideId = supabase.auth.currentUser?.id;
      final tripDate = widget.scheduleData['trip_date']?.toString();

      if (guideId == null || tripDate == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final userSchedule = await supabase
          .from('user_schedules')
          .select('user_id')
          .eq('guide_id', guideId)
          .eq('trip_date', tripDate)
          .maybeSingle();

      if (userSchedule == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final userId = userSchedule['user_id']?.toString();
      if (userId == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final profile = await supabase
          .from('users')
          .select('id, nickname, profile_image')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _travelerProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("❌ 여행자 프로필 로드 실패: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
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

    if (myId == null || travelerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ 여행자 정보를 찾을 수 없습니다.")));
      return;
    }

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
                'is_guide': false, // 상대방이 여행자
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

  Map<String, String> _parseTripDate() {
    final tripDate = widget.scheduleData['trip_date']?.toString() ?? '';
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
    final String title = widget.scheduleData['title']?.toString() ?? '투어';
    final String location = widget.scheduleData['location']?.toString() ?? '';
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 여행자 헤더
            _isLoadingProfile
                ? _buildProfileSkeleton()
                : _buildTravelerHeader(_travelerProfile),
            const SizedBox(height: 30),

            // 투어 제목
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 투어 일정
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

            // 장소
            if (location.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "장소",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.travelingPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(location, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ],

            const Divider(height: 60),

            // 가이드 메모
            Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.orange),
                const SizedBox(width: 5),
                const Text(
                  "투어 준비 메모",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 5,
              onChanged: _saveMemo,
              decoration: InputDecoration(
                hintText: "준비물이나 투어 관련 메모를 적어보세요.",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 여행자와 채팅하기
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _travelerProfile != null ? _goToChat : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingPurple,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "여행자와 채팅하기",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelerHeader(Map<String, dynamic>? traveler) {
    final nickname = traveler?['nickname']?.toString() ?? '여행자';
    final profileImages = traveler?['profile_image'];
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
