import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:localmate/core/constants/app_colors.dart';

class TravelerDiscoverView extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final CardSwiperController controller;
  final Function(int index) onSwipe;
  final VoidCallback onEnd;
  final Function(Map<String, dynamic> user) onDetailTap;
  final Function(String direction) onActionBtnTap;

  const TravelerDiscoverView({
    super.key,
    required this.users,
    required this.controller,
    required this.onSwipe,
    required this.onEnd,
    required this.onDetailTap,
    required this.onActionBtnTap,
  });

  // ✅ 기본 이미지 경로 (회색 실루엣)
  final String _defaultProfileUrl =
      "https://www.shutterstock.com/image-vector/default-avatar-profile-icon-social-600nw-1677509740.jpg";

  String _formatNationality(String? code) {
    if (code == null || code.isEmpty) return "🌐 지구인";
    if (code.contains(' ')) return code;
    try {
      final country = CountryService().findByCode(code);
      if (country != null) return "${country.flagEmoji} ${country.name}";
    } catch (e) {
      return code;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty)
      return const Center(
        child: Text("주변에 메이트가 없어요!", style: TextStyle(color: Colors.grey)),
      );

    return Stack(
      children: [
        Positioned.fill(
          child: CardSwiper(
            controller: controller,
            cardsCount: users.length,
            numberOfCardsDisplayed: users.length > 1 ? 2 : 1,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            onEnd: onEnd,
            cardBuilder: (context, index, _, __) {
              return GestureDetector(
                onTap: () => onDetailTap(users[index]),
                child: _buildUserCard(users[index]),
              );
            },
            onSwipe: (prev, curr, dir) {
              if (curr != null) onSwipe(curr);
              return true;
            },
          ),
        ),
        Positioned(bottom: 40, left: 0, right: 0, child: _buildActionButtons()),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    // 📸 사진 로직 수정: 리스트가 비어있으면 랜덤이 아닌 기본 실루엣 이미지 사용
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [];
    final String imageUrl = images.isNotEmpty
        ? images[0].toString()
        : _defaultProfileUrl;

    final guideData = user['guides'] ?? {};
    final bool isVerified = guideData['is_verified'] ?? false;
    final List<dynamic> specialties = guideData['specialties'] ?? [];

    // ⭐ 별점 로직 수정: 리뷰가 0개면 "신규"로 표시
    final double rawRating = (guideData['rating_avg'] ?? 0.0).toDouble();
    final int reviewCount = guideData['review_count'] ?? 0;
    final bool isNewMate = reviewCount == 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 배경 이미지 (이미지 없으면 회색 실루엣)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 100, color: Colors.white),
            ),
          ),

          // 2. 가독성을 위한 그라데이션 (조금 더 진하게)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                stops: const [0.4, 1.0],
              ),
            ),
          ),

          // 3. 상단 뱃지 영역 (평점 및 인증)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ 평점/신규 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isNewMate
                        ? Colors.blueAccent.withOpacity(0.9)
                        : Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: isNewMate
                        ? Border.all(color: Colors.white, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isNewMate
                            ? Icons.fiber_new_rounded
                            : Icons.star_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNewMate
                            ? "신규 메이트"
                            : "${rawRating.toStringAsFixed(1)} ($reviewCount)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVerified)
                  const Icon(
                    Icons.verified,
                    color: Colors.blueAccent,
                    size: 35,
                  ),
              ],
            ),
          ),

          // 4. 하단 정보 영역
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 전문 분야 해시태그
                if (specialties.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: specialties
                        .take(3)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.travelingPurple.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "#$s",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // 닉네임, 나이
                Text(
                  "${user['nickname'] ?? '이름 없음'}, ${user['age'] ?? '??'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                // 국적 | MBTI
                Text(
                  "${_formatNationality(user['nationality'])} | ${user['mbti'] ?? 'MBTI'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 12),

                // 한 줄 소개
                Text(
                  guideData['guide_bio'] ?? user['bio'] ?? "안녕하세요! 반갑습니다.",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 100), // 하단 버튼 공간 확보
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 하단 액션 버튼 위젯들 (기존과 동일하게 유지) ---
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleBtn(Icons.close, Colors.red, () => onActionBtnTap('left')),
        const SizedBox(width: 40),
        _circleBtn(Icons.favorite, Colors.green, () => onActionBtnTap('right')),
      ],
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black26)],
        ),
        child: Icon(icon, color: color, size: 35),
      ),
    );
  }
}
