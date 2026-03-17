import 'package:flutter/material.dart';
import 'package:localmate/core/utils/date_utils.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/request_create_page.dart';
import 'package:localmate/features/matching/pages/received_offers_page.dart';
import 'package:localmate/features/matching/pages/tour_detail_page.dart';
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

      _requestsStream = Supabase.instance.client
          .from('travel_requests')
          .stream(primaryKey: ['id'])
          .eq('writer_id', myId ?? '')
          .order('created_at', ascending: false);
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 27),
              child: _buildActionCard(
                title: "가이드 제안 받기",
                subtitle: "나만의 맞춤형 여행 공고 올리기",
                icon: Icons.send_to_mobile_rounded,
                color: AppColors.travelingBlue,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RequestCreatePage(),
                    ),
                  );
                  _refresh();
                },
              ),
            ),
            const SizedBox(height: 30),

            // 실시간 제안 현황
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildRequestStatusSection(snapshot.data!);
              },
            ),

            // 나의 여행 일정
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _schedulesFuture,
              builder: (context, snapshot) {
                final schedules = snapshot.data ?? [];
                if (schedules.isEmpty) {
                  return _buildEmptyScheduleSection(AppColors.travelingBlue);
                }
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
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 27),
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: const Center(
            child: Text(
              "예정된 여행 일정이 없습니다.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
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
                "나의 확정된 여행 일정",
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

            // ✅ user_schedules 컬럼 직접 사용 (조인 없음)
            final String tripDate = item['trip_date'] ?? '';
            String formattedDate = '날짜 미정';
            if (tripDate.isNotEmpty) {
              try {
                final dt = DateTime.parse(tripDate).toLocal();
                final dateStr = DateUtilsHelper.formatScheduleDate(dt);
                final timeStr =
                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                formattedDate = '$dateStr $timeStr';
              } catch (_) {}
            }

            final String title = item['title'] ?? '제목 없음';
            final String partnerName = item['partner_name'] ?? '로컬 메이트';

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TourDetailPage(
                      // ✅ .from()을 사용해 타입을 Map<String, dynamic>으로 강제 변환합니다.
                      tourData: Map<String, dynamic>.from(item),
                    ),
                  ),
                );
              },
              child: _buildVerticalScheduleCard(
                formattedDate,
                title,
                partnerName,
                color,
              ),
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
            final req = requests[index];

            final int offerCount =
                (req['offers'] != null && (req['offers'] as List).isNotEmpty)
                ? req['offers'][0]['count']
                : 0;

            final bool hasOffers = offerCount > 0;

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceivedOffersPage(
                      requestId: req['id'].toString(),
                      requestTitle: req['title'] ?? '공고 상세',
                    ),
                  ),
                );
                _refresh();
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
