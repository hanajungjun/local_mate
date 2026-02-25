import 'package:flutter/material.dart';
import 'package:local_mate/core/constants/app_colors.dart';

class TravelListPage extends StatefulWidget {
  const TravelListPage({super.key});

  @override
  State<TravelListPage> createState() => _TravelListPageState();
}

class _TravelListPageState extends State<TravelListPage> {
  // 실제로는 HomePage의 모드 상태를 가져와야 하지만, 일단 예시로 여행자 모드라 가정합니다.
  bool _isTravelerMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isTravelerMode ? "가이드 찾기" : "여행자 찾기",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black), // 필터 버튼
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 상단 안내 문구
            Text(
              _isTravelerMode
                  ? "맘에 드는 가이드를 오른쪽으로 밀어보세요!"
                  : "수락하고 싶은 공고를 오른쪽으로 밀어보세요!",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // 🎯 스와이프 카드 영역
            Expanded(
              child: Stack(
                children: [
                  // 배경에 깔린 다음 카드 (예시)
                  _buildMatchingCard(
                    name: _isTravelerMode ? "동네고수" : "서울여행자",
                    desc: "다음 카드가 대기 중입니다.",
                    opacity: 0.5,
                  ),
                  // 실제 위에서 조작하는 카드
                  Dismissible(
                    key: UniqueKey(),
                    onDismissed: (direction) {
                      // 스와이프 방향에 따른 로직 (오른쪽: 매칭, 왼쪽: 패스)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            direction == DismissDirection.startToEnd
                                ? "관심 표시!"
                                : "넘어갔습니다.",
                          ),
                        ),
                      );
                    },
                    background: _buildSwipeBackground(
                      Icons.favorite,
                      Colors.green,
                      Alignment.centerLeft,
                    ),
                    secondaryBackground: _buildSwipeBackground(
                      Icons.close,
                      Colors.red,
                      Alignment.centerRight,
                    ),
                    child: _buildMatchingCard(
                      name: _isTravelerMode ? "망원동 김선생" : "경주 가고픈 여행자",
                      desc: _isTravelerMode
                          ? "망원동 10년 거주. 맛집부터 숨은 카페까지 다 압니다."
                          : "3월 15일 경주 황리단길 가이드 해주실 분 찾아요!",
                      imageColor: _isTravelerMode
                          ? AppColors.travelingBlue
                          : AppColors.travelingPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 하단 조작 버튼
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // 카드 디자인 위젯
  Widget _buildMatchingCard({
    required String name,
    required String desc,
    double opacity = 1.0,
    Color? imageColor,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: (imageColor ?? Colors.grey.shade300).withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.person, size: 100, color: imageColor),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 스와이프 시 나타나는 배경
  Widget _buildSwipeBackground(
    IconData icon,
    Color color,
    Alignment alignment,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  // 하단 버튼들
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _circleButton(Icons.close, Colors.red),
        _circleButton(Icons.favorite, Colors.green),
        _circleButton(Icons.star, Colors.blue),
      ],
    );
  }

  Widget _circleButton(IconData icon, Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Icon(icon, color: color),
    );
  }
}
