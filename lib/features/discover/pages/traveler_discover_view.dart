import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [];
    final String imageUrl = images.isNotEmpty
        ? images[0].toString()
        : 'https://picsum.photos/600/800';

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[200]),
        ),
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
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${user['nickname'] ?? '이름 없음'}, ${user['age'] ?? '??'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${user['nationality'] ?? '지구인'} | ${user['mbti'] ?? 'MBTI'}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                user['bio'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 2,
              ),
              const SizedBox(height: 120),
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
