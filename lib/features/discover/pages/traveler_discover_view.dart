import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
//가이드찾기

class TravelerDiscoverView extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final CardSwiperController controller;
  final Function(int index) onSwipe;
  final VoidCallback onEnd; // ✅ 추가: 카드가 끝났음을 알리는 콜백
  final Function(Map<String, dynamic> user) onDetailTap;
  final Function(String direction) onActionBtnTap;

  const TravelerDiscoverView({
    super.key,
    required this.users,
    required this.controller,
    required this.onSwipe,
    required this.onEnd, // ✅ 추가
    required this.onDetailTap,
    required this.onActionBtnTap,
  });

  // ✅ 2. 국가 코드를 '이모지 + 이름'으로 바꿔주는 헬퍼 함수
  String _formatNationality(String? code) {
    if (code == null || code.isEmpty) return "🌐 지구인";

    // 만약 이미 '🇰🇷 대한민국'처럼 국기가 포함된 데이터라면 그대로 반환 (하위호환)
    if (code.contains(' ')) return code;

    try {
      // 'KR' 같은 코드를 찾아서 정보를 가져옵니다.
      final country = CountryService().findByCode(code);
      if (country != null) {
        // 나중에 다국어 적용 시 .nameLocalized로 바꾸면 자동 번역됩니다.
        return "${country.flagEmoji} ${country.name}";
      }
    } catch (e) {
      return code; // 에러 시 코드라도 보여줌
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const Center(child: Text("주변에 메이트가 없어요!"));

    return Stack(
      children: [
        // 1. 카드 스와이프 영역
        Positioned.fill(
          child: CardSwiper(
            controller: controller,
            cardsCount: users.length,
            numberOfCardsDisplayed: users.length > 1 ? 2 : 1,
            padding: EdgeInsets.zero,
            onEnd: onEnd, // ✅ 추가: 이제 카드가 다 돌면 discover_page의 _isEnd가 true가 됨
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
        // 2. 하단 액션 버튼
        Positioned(bottom: 40, left: 0, right: 0, child: _buildActionButtons()),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    // 1. 이미지 처리
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [];
    final String imageUrl = images.isNotEmpty
        ? images[0].toString()
        : 'https://picsum.photos/600/800';

    // 2. 가이드 상세 정보 추출 (is_verified, location_names)
    final guideData = user['guides']; // 리스트 형태가 아니라 단일 맵(Map)으로 들어옵니다.
    final bool isVerified = guideData?['is_verified'] ?? false;
    final List<dynamic> locations = guideData?['location_names'] ?? [];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 배경 이미지
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[200]),
        ),
        // 하단 텍스트 가독성을 위한 그라데이션
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
        // 정보 표시 영역
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 닉네임, 나이 + 검증 배지
              Row(
                children: [
                  Text(
                    "${user['nickname'] ?? '이름 없음'}, ${user['age'] ?? '??'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.verified,
                      color: Colors.blueAccent,
                      size: 30,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // ✅ 3. 국적 표시 부분 수정 (헬퍼 함수 적용)
              Text(
                "${_formatNationality(user['nationality'])} | ${user['mbti'] ?? 'MBTI'}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),

              if (locations.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: locations.map((loc) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "#$loc",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // ✅ 활동 지역 해시태그 (location_names)
              if (locations.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: locations.map((loc) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "#$loc",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // 자기소개
              Text(
                user['bio'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 120), // 하단 버튼 공간 확보
            ],
          ),
        ),
      ],
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
