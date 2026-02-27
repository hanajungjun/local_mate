import 'package:flutter/material.dart';
import 'package:localmate/core/utils/date_utils.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/request_create_page.dart';
import 'package:localmate/services/schedule_service.dart';

class TravelMode extends StatefulWidget {
  final VoidCallback? onStartRequest;
  const TravelMode({super.key, this.onStartRequest});

  @override
  State<TravelMode> createState() => _TravelModeState();
}

class _TravelModeState extends State<TravelMode> {
  late Future<List<Map<String, dynamic>>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = ScheduleService().getUserSchedules();
  }

  Future<void> _refresh() async {
    setState(() {
      _schedulesFuture = ScheduleService().getUserSchedules();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.travelingBlue,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(), // RefreshIndicator 작동을 위해 필수
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
                onTap: () {
                  if (widget.onStartRequest != null) {
                    widget.onStartRequest!();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RequestCreatePage(),
                      ),
                    );
                  }
                },
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
}
