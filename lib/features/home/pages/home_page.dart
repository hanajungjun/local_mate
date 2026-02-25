import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onGoToTravel;
  final VoidCallback? onStartRequest;
  final VoidCallback? onStartGuide;

  const HomePage({
    super.key,
    required this.onGoToTravel,
    this.onStartRequest,
    this.onStartGuide,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 현재 모드 상태 (true: 여행자, false: 가이드)
  bool _isTravelerMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 상단 헤더
              _buildCustomHeader(),

              // 2. 모드 전환 토글 탭
              _buildModeToggle(),

              // 3. 메인 서비스 카드 섹션 (배너 및 액션 버튼)
              _buildMainServiceSection(),

              const SizedBox(height: 35),

              // 4. 홈 하단 일정 관리 섹션
              _buildScheduleSection(),

              const SizedBox(height: 100), // 바텀 네비게이션 가려짐 방지 여백
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🎨 주요 구성 섹션들
  // ----------------------------------------------------------------------

  // [1] 상단 헤더
  Widget _buildCustomHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Local Mate",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.travelingBlue,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  // [2] 여행자/가이드 모드 전환 토글
  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 15),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildToggleItem(
              "여행자 모드",
              _isTravelerMode,
              AppColors.travelingBlue,
              () {
                setState(() => _isTravelerMode = true);
              },
            ),
            _buildToggleItem(
              "가이드 모드",
              !_isTravelerMode,
              AppColors.travelingPurple,
              () {
                setState(() => _isTravelerMode = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  // [3] 메인 서비스 카드 섹션 (상황에 따라 배너와 카드가 바뀜)
  Widget _buildMainServiceSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "어떤 서비스를 이용하시겠어요?",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          if (_isTravelerMode) ...[
            // 여행자 모드: 공고 올리기 버튼
            _buildActionCard(
              title: "가이드 제안 받기",
              subtitle: "나만의 맞춤형 여행 공고 올리기",
              icon: Icons.send_to_mobile_rounded,
              color: AppColors.travelingBlue,
              onTap: widget.onStartRequest ?? () {},
            ),
          ] else ...[
            // 가이드 모드: 등록 유도 배너 + 활동 버튼
            _buildGuideRegistrationBanner(),
            const SizedBox(height: 12),
            _buildActionCard(
              title: "동네 가이드 활동",
              subtitle: "내 주변 여행 요청에 제안하기",
              icon: Icons.map_outlined,
              color: AppColors.travelingPurple,
              onTap: widget.onStartGuide ?? () {},
            ),
          ],
        ],
      ),
    );
  }

  // [4] 하단 일정 관리 섹션
  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "나의 여행 일정",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("전체보기", style: TextStyle(color: Colors.grey)),
              ),
            ],
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
                date: "3월 15일 (일)",
                time: "14:00",
                title: "망원동 노포 투어",
                partner: "가이드 김로컬",
                color: AppColors.travelingBlue,
              ),
              _buildScheduleCard(
                date: "3월 20일 (금)",
                time: "11:00",
                title: "행궁동 출사 나들이",
                partner: "가이드 이사진",
                color: AppColors.travelingPurple,
              ),
              _buildAddScheduleCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // 🧩 작은 컴포넌트(위젯)들
  // ----------------------------------------------------------------------

  Widget _buildToggleItem(
    String title,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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

  Widget _buildGuideRegistrationBanner() {
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
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4A00E0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "등록하기",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String date,
    required String time,
    required String title,
    required String partner,
    required Color color,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildAddScheduleCard() {
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
