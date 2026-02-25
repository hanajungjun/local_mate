import 'package:flutter/material.dart';

class ProfileDetailPage extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(String direction) onSwipeAction;

  const ProfileDetailPage({
    super.key,
    required this.user,
    required this.onSwipeAction,
  });

  @override
  Widget build(BuildContext context) {
    // 💡 가이드 정보 추출 (Service에서 Join해서 가져온 데이터)
    final guideInfo = user['guides'];
    final List<dynamic> images = user['profile_image'] is List
        ? user['profile_image']
        : [user['profile_image'] ?? 'https://picsum.photos/600/800'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 스크롤 영역 (사진 + 상세 정보)
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사진 슬라이더
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, index) => Image.network(
                      images[index].toString(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 이름 및 가이드 인증 뱃지 ---
                      Row(
                        children: [
                          Text(
                            "${user['nickname']}, ${user['age']}",
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // 💡 인증된 가이드라면 파란 뱃지 노출
                          if (guideInfo != null &&
                              guideInfo['is_verified'] == true)
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

                      // --- 💡 가이드 전용 점수판 (가이드일 때만 노출) ---
                      if (guideInfo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                "평점",
                                "⭐ ${guideInfo['rating_avg'] ?? '0.0'}",
                              ),
                              _buildStatDivider(),
                              _buildStatItem(
                                "가이드 횟수",
                                "${guideInfo['guide_count'] ?? 0}회",
                              ),
                              _buildStatDivider(),
                              _buildStatItem(
                                "리뷰",
                                "${guideInfo['review_count'] ?? 0}개",
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        "${user['nationality']} | ${user['mbti']} | ${user['location_name']}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 40, thickness: 1),

                      // --- 자기소개 영역 ---
                      Text(
                        guideInfo != null ? "가이드 소개" : "자기소개",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        // 💡 가이드 소개가 따로 있으면 그걸 보여주고, 없으면 일반 bio 노출
                        guideInfo?['guide_bio'] ??
                            user['bio'] ??
                            "안녕하세요! 반갑습니다.",
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 30),
                      const Text(
                        "관심사",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (user['interests'] as List? ?? [])
                            .map(
                              (i) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  i.toString(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 상단 닫기 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. 하단 고정 버튼
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleButton(Icons.close, Colors.red, () {
                  onSwipeAction('left');
                  Navigator.pop(context);
                }),
                const SizedBox(width: 30),
                _circleButton(Icons.favorite, Colors.green, () {
                  onSwipeAction('right');
                  Navigator.pop(context);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 💡 가이드 스탯 위젯 조립 ---
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
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
  }

  Widget _buildStatDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.2));
  }

  Widget _circleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
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
}
