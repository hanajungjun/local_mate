import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("알림"),
        content: const Text("해당 기능은 레베뉴캣 연동과 함께 업데이트될 예정입니다!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "상점",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 배너 (가라로 폼 나게)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.travelingBlue, Colors.blue.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "프리미엄 가이드가 되어보세요!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "매칭 확률이 3배 더 올라갑니다.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            _buildSectionTitle("🔥 인기 가이드 아이템"),
            _buildShopItem(
              context,
              "가이드 리스트 상단 고정 (1일)",
              "가이드 검색 시 최상단에 노출됩니다.",
              "5,000원",
            ),
            _buildShopItem(
              context,
              "프로필 강조 효과",
              "내 프로필에 황금색 테두리가 생깁니다.",
              "2,500원",
            ),

            const Divider(thickness: 8, color: Color(0xFFF5F5F5), height: 40),

            _buildSectionTitle("👑 멤버십 구독"),
            _buildShopItem(
              context,
              "로컬메이트 프리미엄 (1개월)",
              "수수료 감면 및 전용 뱃지 제공",
              "9,900원",
              isSubscription: true,
            ),
            _buildShopItem(
              context,
              "로컬메이트 프리미엄 (12개월)",
              "연간 결제 시 20% 할인 혜택",
              "99,000원",
              isSubscription: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 15),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildShopItem(
    BuildContext context,
    String title,
    String desc,
    String price, {
    bool isSubscription = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        desc,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: () => _showComingSoon(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSubscription
              ? AppColors.travelingBlue
              : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          price,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
