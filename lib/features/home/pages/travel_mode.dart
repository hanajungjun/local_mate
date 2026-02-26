import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/request_create_page.dart';

class TravelMode extends StatelessWidget {
  final VoidCallback? onStartRequest;
  const TravelMode({super.key, this.onStartRequest});

  @override
  Widget build(BuildContext context) {
    return Column(
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

        // 1. 여행자용 액션 카드 (블루)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: _buildActionCard(
            title: "가이드 제안 받기",
            subtitle: "나만의 맞춤형 여행 공고 올리기",
            icon: Icons.send_to_mobile_rounded,
            color: AppColors.travelingBlue,
            onTap: () {
              // ✅ 콜백이 있으면 실행하고, 없으면 직접 이동!
              if (onStartRequest != null) {
                onStartRequest!();
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

        // 2. 여행자용 일정 섹션 (블루)
        _buildScheduleSection(AppColors.travelingBlue),

        const SizedBox(height: 100),
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

  Widget _buildScheduleSection(Color color) {
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
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              _buildScheduleCard(
                "3월 15일 (일)",
                "14:00",
                "망원동 노포 투어",
                "가이드 김로컬",
                color,
              ),
              _buildAddCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(
    String date,
    String time,
    String title,
    String partner,
    Color color,
  ) {
    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
          const Spacer(),
          Text(
            partner,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(Icons.add_circle_outline, color: Colors.grey.shade400),
    );
  }
}
