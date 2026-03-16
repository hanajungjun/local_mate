import 'package:flutter/material.dart';
import 'package:localmate/core/utils/travel_utils.dart';

class GuideProfileDetailPage extends StatefulWidget {
  final Map<String, dynamic> guideData;

  const GuideProfileDetailPage({super.key, required this.guideData});

  @override
  State<GuideProfileDetailPage> createState() => _GuideProfileDetailPageState();
}

class _GuideProfileDetailPageState extends State<GuideProfileDetailPage> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final guideInfo = widget.guideData['guides'] ?? {};
    final List<dynamic> profileImages =
        widget.guideData['profile_image'] as List<dynamic>? ?? [];

    // 데이터 추출
    final Map<String, dynamic> languages = guideInfo['language_levels'] ?? {};
    final List<dynamic> specialties = guideInfo['specialties'] ?? [];
    final List<dynamic> locations = guideInfo['location_names'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. 상단 사진 갤러리 (5장 슬라이드)
          _buildSliverAppBar(profileImages),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 및 기본정보
                    Text(
                      "${widget.guideData['nickname']} 가이드",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${TravelUtils.formatNationality(widget.guideData['nationality'])} • ${widget.guideData['age']}세",
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),

                    const SizedBox(height: 24),

                    // 2. [기존 정보 유지] 평점, 횟수, 거주기간 바
                    _buildStatBar(guideInfo),

                    const Divider(height: 48),

                    // 3. 전문 분야 (Specialties)
                    const Text(
                      "전문 분야",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: specialties
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                "# $s",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // 4. 언어 능력 (Language Levels)
                    const Text(
                      "언어 능력",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...languages.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.translate,
                                    size: 16,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${e.key}: ",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  "${e.value}",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),

                    const Divider(height: 48),

                    // 5. 활동 가능 지역 (Location Names)
                    const Text(
                      "활동 가능 지역",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: locations
                          .map(
                            (loc) => Chip(
                              label: Text(
                                loc.toString(),
                                style: const TextStyle(fontSize: 13),
                              ),
                              backgroundColor: Colors.grey[100],
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 32),

                    // 6. 가이드 소개 (Bio)
                    const Text(
                      "가이드 소개",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      guideInfo['guide_bio'] ?? "안녕하세요! 여행의 즐거움을 더해드릴 가이드입니다.",
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 100), // 하단 여백
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // 상단 슬라이더 바
  Widget _buildSliverAppBar(List<dynamic> images) {
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 50),
              )
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) => Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  // 페이지 인디케이터
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_currentImageIndex + 1} / ${images.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 기존 스탯 바 (평점, 횟수, 거주기간)
  Widget _buildStatBar(Map<String, dynamic> info) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("평점", "⭐ ${info['rating_avg'] ?? '5.0'}"),
          _buildStatItem("가이드", "${info['guide_count'] ?? 0}회"),
          _buildStatItem("거주기간", info['residence_period'] ?? "비공개"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
