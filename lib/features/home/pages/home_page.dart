import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

import 'travel_mode.dart';
import 'guide_mode.dart';

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
  // ✅ 현재 모드 상태 (true: 여행자, false: 가이드)
  bool _isTravelerMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. [고정] 상단 헤더
            _buildCustomHeader(),

            // 2. [고정] 모드 전환 토글 탭
            _buildModeToggle(),

            // 3. [가변] 모드에 따라 스위칭되는 메인 뷰
            Expanded(
              child: SingleChildScrollView(
                child: _isTravelerMode
                    ? TravelMode(onStartRequest: widget.onStartRequest)
                    : GuideMode(onStartGuide: widget.onStartGuide),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 헤더
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

  // 여행자/가이드 모드 전환 토글
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
              () => setState(() => _isTravelerMode = true),
            ),
            _buildToggleItem(
              "가이드 모드",
              !_isTravelerMode,
              AppColors.travelingPurple,
              () => setState(() => _isTravelerMode = false),
            ),
          ],
        ),
      ),
    );
  }

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
}
