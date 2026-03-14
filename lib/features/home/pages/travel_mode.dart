import 'package:flutter/material.dart';
import 'package:localmate/core/utils/date_utils.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/request_create_page.dart';
import 'package:localmate/features/matching/pages/received_offers_page.dart';
import 'package:localmate/services/schedule_service.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TravelMode extends StatefulWidget {
  final VoidCallback? onStartRequest;
  const TravelMode({super.key, this.onStartRequest});

  @override
  State<TravelMode> createState() => _TravelModeState();
}

class _TravelModeState extends State<TravelMode> {
  late Future<List<Map<String, dynamic>>> _schedulesFuture;

  // 🔄 Future를 Stream으로 변경!
  late Stream<List<Map<String, dynamic>>> _requestsStream;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;

    setState(() {
      _schedulesFuture = ScheduleService().getUserSchedules();

      // ✅ 순서 중요: from -> stream -> eq -> order 순서입니다.
      _requestsStream = Supabase.instance.client
          .from('travel_requests')
          .stream(primaryKey: ['id']) // 1. 스트림을 먼저 열고
          .eq('writer_id', myId ?? '') // 2. 그다음에 필터를 겁니다
          .order('created_at', ascending: false); // 3. 정렬 추가
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.travelingBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 27),
              child: Text(
                "어떤 서비스를 이용하시겠어요?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),
            // 1. 공고 올리기 액션 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27),
              child: _buildActionCard(
                title: "가이드 제안 받기",
                subtitle: "나만의 맞춤형 여행 공고 올리기",
                icon: Icons.send_to_mobile_rounded,
                color: AppColors.travelingBlue,
                onTap: () async {
                  // ✅ [수정] 여기는 공고를 '생성'하는 곳입니다!
                  // 1. 공고 생성 페이지로 이동
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RequestCreatePage(), // 👈 생성 페이지로!
                    ),
                  );

                  // 2. 공고 만들고 돌아오면 리스트 새로고침
                  _refresh();
                },
              ),
            ),

            const SizedBox(height: 30),

            // 2. 실시간 제안 현황 (여기는 그대로 두세요)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty)
                  return const SizedBox.shrink();

                return _buildRequestStatusSection(snapshot.data!);
              },
            ),

            // 3. 나의 여행 일정 (기존 코드 동일)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _schedulesFuture,
              builder: (context, snapshot) {
                final schedules = snapshot.data ?? [];
                if (schedules.isEmpty)
                  return _buildEmptyScheduleSection(AppColors.travelingBlue);
                return _buildScheduleSection(
                  AppColors.travelingBlue,
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

  Widget _buildEmptyScheduleSection(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            "나의 여행 일정",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 160,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 27),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.grey.shade300,
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                "예정된 여행 일정이 없습니다.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                child: Text(
                  "새로운 여행 시작하기",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 25,
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: color.withOpacity(0.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "나의 여행 일정",
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
              item['partner_name'] ?? "미정",
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
    String partner,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "가이드",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
              Text(
                partner,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ✅ 실시간 제안 현황 위젯 (가로 스크롤 또는 리스트 형태)
  /// ✅ 실시간 제안 현황 섹션 (이 함수를 통째로 교체하세요)
  Widget _buildRequestStatusSection(List<Map<String, dynamic>> requests) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 27, vertical: 10),
          child: Text(
            "내 여행 공고 상태",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 27),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            // 💡 여기서 각 줄의 데이터(req)를 정의합니다.
            final req = requests[index];

            // 제안 개수 파악 (데이터 구조에 따라 0 처리)
            final int offerCount =
                (req['offers'] != null && (req['offers'] as List).isNotEmpty)
                ? req['offers'][0]['count']
                : 0;

            final bool hasOffers = offerCount > 0;

            return GestureDetector(
              onTap: () async {
                // ✅ 클릭 시 상세 페이지로 이동하고, 돌아오면 새로고침(_refresh) 실행
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceivedOffersPage(
                      requestId: req['id'].toString(), // ID 전달
                      requestTitle: req['title'] ?? '공고 상세', // 제목 전달
                    ),
                  ),
                );
                _refresh(); // 👈 돌아왔을 때 목록 다시 갱신!
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasOffers ? Colors.blue.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasOffers
                        ? Colors.blue.shade200
                        : Colors.grey.shade200,
                    width: hasOffers ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasOffers
                          ? Icons.notifications_active
                          : Icons.hourglass_empty_rounded,
                      color: hasOffers ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['title'] ?? '제목 없음',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasOffers
                                ? "새로운 제안 $offerCount건이 도착했어요!"
                                : "가이드의 제안을 기다리는 중이에요.",
                            style: TextStyle(
                              fontSize: 12,
                              color: hasOffers
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade600,
                              fontWeight: hasOffers
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: hasOffers ? Colors.blue : Colors.grey,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
