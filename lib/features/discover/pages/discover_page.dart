import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart';
import 'guide_detail_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final DiscoverService _discoverService = DiscoverService();
  final CardSwiperController _controller = CardSwiperController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMates();
  }

  Future<void> _loadMates() async {
    try {
      final mates = await _discoverService.fetchMates(limit: 10);
      if (mounted) {
        setState(() {
          _users = mates;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // --- 상단 앱바 수정 (필터 & 상점 버튼) ---
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.storefront, color: Colors.black),
          onPressed: () => print("상점 이동"),
        ),
        title: const Text(
          "발견",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => print("필터 클릭"),
            child: const Text(
              "필터",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
            ? const Center(child: Text("근처에 메이트가 없어요!"))
            : Stack(
                alignment: Alignment.center,
                children: [
                  // 1. 카드 레이어
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
                      child: CardSwiper(
                        controller: _controller,
                        cardsCount: _users.length,
                        numberOfCardsDisplayed: 2,
                        backCardOffset: const Offset(0, 0),
                        padding: EdgeInsets.zero,
                        cardBuilder: (context, index, _, __) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GuideDetailPage(
                                    user: _users[index],
                                    onSwipeAction: (direction) {
                                      if (direction == 'left') {
                                        _controller.swipe(
                                          CardSwiperDirection.left,
                                        );
                                      } else {
                                        _controller.swipe(
                                          CardSwiperDirection.right,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                            child: _buildUserCard(_users[index]),
                          );
                        }, // cardBuilder 닫기
                        onSwipe: (previousIndex, currentIndex, direction) {
                          if (direction == CardSwiperDirection.right) {
                            _discoverService.sendLike(
                              _users[previousIndex]['id'].toString(),
                            );
                            _showLikeSnackBar(
                              _users[previousIndex]['nickname'],
                            );
                          }
                          return true;
                        },
                      ),
                    ),
                  ),

                  // 2. 하단 버튼 레이어
                  Positioned(bottom: 30, child: _buildActionButtons()),
                ],
              ),
      ),
    );
  }

  // --- 좌우 꽉 찬 카드 디자인 ---
  Widget _buildUserCard(Map<String, dynamic> user) {
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : (user['profile_image'] != null ? [user['profile_image']] : []);
    final String imageUrl = images.isNotEmpty
        ? images[0].toString()
        : 'https://picsum.photos/600/800';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        // 좌우를 꽉 채우기 위해 보더 래디우스를 살짝 조절하거나 제거 가능
        borderRadius: BorderRadius.circular(0),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover, // 이미지가 꽉 차도록 설정
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            stops: const [0.5, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(24),
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
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              user['bio'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            // 관심사 태그
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (user['interests'] as List? ?? [])
                  .map(
                    (i) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        i.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20), // 텍스트가 너무 하단에 붙지 않게 여백
          ],
        ),
      ),
    );
  }

  void _showLikeSnackBar(String? nickname) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$nickname님에게 하트 전송! ❤️"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _circleButton(
          Icons.close,
          Colors.red,
          () => _controller.swipe(CardSwiperDirection.left),
        ),
        const SizedBox(width: 25),
        _circleButton(
          Icons.star,
          Colors.blue,
          () => _controller.swipe(CardSwiperDirection.top),
        ),
        const SizedBox(width: 25),
        _circleButton(
          Icons.favorite,
          Colors.green,
          () => _controller.swipe(CardSwiperDirection.right),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 38),
      ),
    );
  }
}
