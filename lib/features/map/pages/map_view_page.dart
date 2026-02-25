import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';

class MapViewPage extends StatelessWidget {
  const MapViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 지도 배경 (실제 지도가 들어갈 자리입니다)
          Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.map_rounded, size: 100, color: Colors.grey),
            ),
          ),

          // 2. 상단 검색바 및 모드 안내
          _buildTopOverlay(context),

          // 3. 지도 위의 핀들 (임시 위치)
          _buildMapPin(top: 200, left: 100, label: "망원동 고수", isGuide: true),
          _buildMapPin(top: 350, left: 250, label: "맛집 찾는 여행자", isGuide: false),
          _buildMapPin(top: 150, left: 200, label: "연남동 베테랑", isGuide: true),

          // 4. 하단 미리보기 카드 (가장 가까운 가이드/공고)
          _buildBottomPreviewCard(),
        ],
      ),
    );
  }

  // 상단 검색바
  Widget _buildTopOverlay(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Text("지금 어디에 계신가요?", style: TextStyle(color: Colors.grey)),
            Spacer(),
            Icon(Icons.my_location, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  // 지도 핀 위젯
  Widget _buildMapPin({
    required double top,
    required double left,
    required String label,
    required bool isGuide,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Icon(
            Icons.location_on,
            color: isGuide
                ? AppColors.travelingPurple
                : AppColors.travelingBlue,
            size: 35,
          ),
        ],
      ),
    );
  }

  // 하단 퀵 카드
  Widget _buildBottomPreviewCard() {
    return Positioned(
      bottom: 100, // 탭바 높이 고려
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "내 주변 가이드 '김망원'",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    "망원동 로컬 맛집 100군데 섭렵",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
