import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/features/matching/pages/guide_registration_page.dart';

class GuideMode extends StatelessWidget {
  final VoidCallback? onStartGuide;
  const GuideMode({super.key, this.onStartGuide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            "가이드 활동 관리",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),

        // 1. 가이드 전용 배너 (퍼플 그라데이션)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: _buildGuideRegistrationBanner(context),
        ),

        const SizedBox(height: 12),

        // 2. 가이드용 액션 카드 (퍼플)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: _buildActionCard(
            title: "동네 가이드 활동",
            subtitle: "내 주변 여행 요청에 제안하기",
            icon: Icons.map_outlined,
            color: AppColors.travelingPurple,
            onTap: onStartGuide ?? () {},
          ),
        ),

        const SizedBox(height: 35),

        // 3. 가이드용 일정 섹션 (퍼플)
        _buildScheduleSection(AppColors.travelingPurple),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildGuideRegistrationBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "가이드 미등록 상태",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "활동을 위해 프로필을 등록하세요!",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // ✅ 등록하기 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuideRegistrationPage(),
                ),
              );
            },
            child: const Text(
              "등록하기",
              style: TextStyle(fontWeight: FontWeight.bold),
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
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.grey,
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
            "가이드 일정",
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
                "3월 20일 (금)",
                "11:00",
                "행궁동 출사 나들이",
                "여행자 이사진",
                color,
              ),
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
}
