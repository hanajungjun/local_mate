import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/guide_registration_page.dart';
import 'package:localmate/services/schedule_service.dart';
import 'package:localmate/services/profile_service.dart';
import 'package:localmate/core/utils/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 추가

class GuideMode extends StatefulWidget {
  final VoidCallback? onStartGuide;
  const GuideMode({super.key, this.onStartGuide});

  @override
  State<GuideMode> createState() => _GuideModeState();
}

class _GuideModeState extends State<GuideMode> {
  // ✅ 1. 일정도 실시간으로 보고 싶다면 Stream으로 관리 (선택사항)
  late Future<List<Map<String, dynamic>>> _schedulesFuture;

  // ✅ 2. 프로필 상태 실시간 감시용 Stream
  late Stream<Map<String, dynamic>?> _profileStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    setState(() {
      _schedulesFuture = ScheduleService().getGuideSchedules();

      // 🚀 프로필 테이블의 guide_status를 실시간으로 지켜봅니다.
      _profileStream = Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', myId ?? '')
          .map((data) => data.isNotEmpty ? data.first : null);
    });
  }

  Future<void> _refresh() async {
    _initStreams();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.travelingPurple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27),
              child: Column(
                children: [
                  // ✅ 3. StreamBuilder로 배너를 감쌉니다.
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: _profileStream,
                    builder: (context, snapshot) {
                      final status = snapshot.data?['guide_status'] ?? 'none';
                      return _buildGuideStatusBanner(context, status);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    title: "동네 가이드 활동",
                    subtitle: "내 주변 여행 요청에 제안하기",
                    icon: Icons.map_outlined,
                    color: AppColors.travelingPurple,
                    onTap: widget.onStartGuide ?? () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _schedulesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final schedules = snapshot.data ?? [];
                if (schedules.isEmpty) {
                  return _buildEmptyScheduleSection(AppColors.travelingPurple);
                }
                return _buildScheduleSection(
                  AppColors.travelingPurple,
                  schedules,
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ✅ 4. 파라미터로 status를 받도록 수정된 배너
  Widget _buildGuideStatusBanner(BuildContext context, String status) {
    String message = "활동을 위해 가이드 프로필을 등록하세요!";
    String buttonText = "등록";
    bool showButton = true;
    IconData icon = Icons.info_outline;

    if (status == 'pending') {
      message = "가이드 승인 대기 중입니다. ✨";
      showButton = false;
      icon = Icons.hourglass_top_rounded;
    } else if (status == 'approved') {
      message = "축하합니다! 공식 가이드로 활동 중입니다. 🏆";
      showButton = false;
      icon = Icons.verified_user_rounded;
    } else if (status == 'rejected') {
      message = "가이드 승인이 거절되었습니다. 서류를 확인해주세요.";
      buttonText = "재등록";
      showButton = true;
      icon = Icons.error_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.travelingPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showButton)
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuideRegistrationPage(),
                  ),
                );
                // 돌아오면 스트림 재설정 (사실 스트림이라 안 해도 되지만 확실히 하기 위해)
                _initStreams();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(60, 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: AppColors.travelingPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: color.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(
    Color color,
    List<Map<String, dynamic>> schedules,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "가이드 일정",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "총 ${schedules.length}건",
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 27, right: 27, bottom: 40),
          itemCount: schedules.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = schedules[index];
            final DateTime tripDate = DateTime.parse(item['trip_date']);
            final String formattedDate = DateUtilsHelper.formatScheduleDate(
              tripDate,
            );
            return _buildVerticalScheduleCard(
              formattedDate,
              item['title'] ?? "제목 없음",
              (item['current_people'] ?? 0) > 0 ? "예약됨" : "모집 중",
              color,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVerticalScheduleCard(
    String date,
    String title,
    String status,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyScheduleSection(Color color) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: Colors.grey.shade300,
              size: 50,
            ),
            const SizedBox(height: 15),
            const Text(
              "확정된 가이드 일정이 없습니다.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
