import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

class DiscoverDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(String direction) onSwipeAction;

  const DiscoverDetailPage({
    super.key,
    required this.user,
    required this.onSwipeAction,
  });

  @override
  State<DiscoverDetailPage> createState() => _DiscoverDetailPageState();
}

class _DiscoverDetailPageState extends State<DiscoverDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _getDisplayNationality(String? code) {
    if (code == null || code.isEmpty) return '🌐 지구인';
    if (code.contains(' ')) return code;
    try {
      final country = CountryService().findByCode(code);
      return country != null ? "${country.flagEmoji} ${country.name}" : code;
    } catch (e) {
      return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final guideInfo = user['guides'] ?? {};
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [user['profile_image'] ?? 'https://picsum.photos/600/800'];
    final List<dynamic> travelStyles = user['travel_style'] is List
        ? user['travel_style']
        : [];

    Map<String, dynamic> languages = {};
    if (guideInfo['language_levels'] != null) {
      try {
        languages = guideInfo['language_levels'] is String
            ? jsonDecode(guideInfo['language_levels'])
            : guideInfo['language_levels'];
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoSlider(images),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 이름 및 인증 배지
                      Row(
                        children: [
                          Text(
                            "${user['nickname']}, ${user['age']}",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (guideInfo['is_verified'] == true)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 28,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 2. 핵심 요약
                      Text(
                        "${_getDisplayNationality(user['nationality'])} | ${user['mbti'] ?? 'MBTI'} | 🏠 ${guideInfo['residence_period'] ?? '거주 미정'}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),

                      // 3. 신뢰 점수
                      const SizedBox(height: 20),
                      _buildTrustBlock(guideInfo),
                      const SizedBox(height: 24),

                      // 4. 전문 분야
                      if ((guideInfo['specialties'] as List? ?? [])
                          .isNotEmpty) ...[
                        _buildSectionTitle("전문 분야"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: (guideInfo['specialties'] as List)
                              .map((s) => _buildTag(s, Colors.orangeAccent))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 5. 언어 능력
                      if (languages.isNotEmpty) ...[
                        _buildSectionTitle("언어 능력"),
                        const SizedBox(height: 10),
                        ...languages.entries.map(
                          (e) => _buildLanguageBar(e.key, e.value),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 6. 여행 스타일
                      if (travelStyles.isNotEmpty) ...[
                        _buildSectionTitle("여행 스타일"),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: travelStyles
                              .map((s) => _buildTravelStyleChip(s.toString()))
                              .toList(),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ✅ 7. 소개 - 인스타 감성
                      _buildSectionTitle("소개"),
                      const SizedBox(height: 20),

                      // 가이드 한마디 (강조)
                      if (guideInfo['guide_bio'] != null) ...[
                        _buildInstaGuideBio(guideInfo['guide_bio']),
                        const SizedBox(height: 20),
                      ],

                      // 자기소개 (서브)
                      if (user['bio'] != null) _buildInstaBio(user['bio']),

                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildTopOverlay(),
          _buildBottomActionButtons(),
        ],
      ),
    );
  }

  // ✅ 가이드 한마디 - 인스타 감성 따옴표 강조
  Widget _buildInstaGuideBio(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 따옴표 아이콘
          const Text(
            "❝",
            style: TextStyle(fontSize: 40, color: Colors.blueAccent, height: 1),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.6,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          // 하단 라벨
          Row(
            children: [
              Container(width: 30, height: 2, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text(
                "가이드 한마디",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ 자기소개 - 라이트 서브 스타일
  Widget _buildInstaBio(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("💬", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                "자기소개",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelStyleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Text(
        "✈️ $label",
        style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTrustBlock(Map<String, dynamic> guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("평점", "⭐ ${guide['rating_avg'] ?? '0.0'}"),
          _statItem("진행횟수", "${guide['guide_count'] ?? 0}회"),
          _statItem("리뷰", "${guide['review_count'] ?? 0}개"),
        ],
      ),
    );
  }

  Widget _buildLanguageBar(String lang, dynamic level) {
    int lvl = int.tryParse(level.toString()) ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              lang,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: lvl / 5,
              backgroundColor: Colors.grey[200],
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            lvl == 5
                ? "원어민"
                : lvl >= 3
                ? "유창함"
                : "기초",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );

  Widget _buildTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      "#$label",
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    ),
  );

  Widget _statItem(String label, String value) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    ],
  );

  Widget _buildPhotoSlider(List<dynamic> images) => Stack(
    children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemCount: images.length,
          itemBuilder: (ctx, i) =>
              Image.network(images[i].toString(), fit: BoxFit.cover),
        ),
      ),
      if (_currentPage > 0)
        Positioned(
          left: 10,
          top: 0,
          bottom: 0,
          child: _sliderBtn(
            Icons.chevron_left,
            () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ),
      if (_currentPage < images.length - 1)
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: _sliderBtn(
            Icons.chevron_right,
            () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ),
    ],
  );

  Widget _sliderBtn(IconData icon, VoidCallback onTap) => Center(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    ),
  );

  Widget _buildTopOverlay() => Positioned(
    top: 40,
    left: 20,
    child: CircleAvatar(
      backgroundColor: Colors.black38,
      child: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );

  Widget _buildBottomActionButtons() => Positioned(
    bottom: 40,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(Icons.close, Colors.red, () {
          widget.onSwipeAction('left');
          Navigator.pop(context);
        }),
        const SizedBox(width: 30),
        _circleButton(Icons.favorite, Colors.green, () {
          widget.onSwipeAction('right');
          Navigator.pop(context);
        }),
      ],
    ),
  );

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 75,
          height: 75,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 5),
            ],
          ),
          child: Icon(icon, color: color, size: 40),
        ),
      );
}
