import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';

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
    if (users.isEmpty) return const Center(child: Text("주변에 메이트가 없어요!"));

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
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [];
    final String imageUrl = images.isNotEmpty
        ? images[0].toString()
        : 'https://picsum.photos/600/800';

    final guideData = user['guides'];
    final bool isVerified = guideData?['is_verified'] ?? false;
    final List<dynamic> specialties = guideData?['specialties'] ?? [];
    final String rating = guideData?['rating_avg']?.toString() ?? "0.0";
    final int reviewCount = guideData?['review_count'] ?? 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 배경 이미지
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
          ),

          // 2. 가독성을 위한 그라데이션
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                stops: const [0.5, 1.0],
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
                // 평점 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        "$rating ($reviewCount)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
                // 전문 분야 해시태그 (강조)
                if (specialties.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    children: specialties
                        .take(3)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent,
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

                // 한 줄 소개 (guide_bio)
                Text(
                  guideData['guide_bio'] ?? user['bio'] ?? "안녕하세요! 반갑습니다.",
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 100), // 하단 버튼 공간
              ],
            ),
          ),
        ],
      ),
    );
  }

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
