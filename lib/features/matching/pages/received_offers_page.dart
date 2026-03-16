import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:localmate/services/matching_service.dart';
import 'package:localmate/features/chat/pages/chat_room_page.dart';
import 'package:localmate/core/utils/travel_utils.dart';
import 'guide_profile_detail_page.dart';

class ReceivedOffersPage extends StatefulWidget {
  final String requestId;
  final String requestTitle;

  const ReceivedOffersPage({
    super.key,
    required this.requestId,
    required this.requestTitle,
  });

  @override
  State<ReceivedOffersPage> createState() => _ReceivedOffersPageState();
}

class _ReceivedOffersPageState extends State<ReceivedOffersPage> {
  final DiscoverService _discoverService = DiscoverService();
  final MatchingService _matchingService = MatchingService();
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    setState(() {
      _offersFuture = _discoverService.fetchOffersForRequest(widget.requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.requestTitle,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data ?? [];
          final activeOffers = offers
              .where((o) => o['status'] != 'rejected')
              .toList();

          if (activeOffers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("아직 도착한 제안이 없어요.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: activeOffers.length,
            itemBuilder: (context, index) =>
                _buildOfferCard(activeOffers[index]),
          );
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final guide = offer['users'] as Map<String, dynamic>?;
    final nickname = guide?['nickname'] ?? '알 수 없는 가이드';

    final List<dynamic> profileImages =
        guide?['profile_image'] as List<dynamic>? ?? [];
    final String profileUrl = profileImages.isNotEmpty
        ? profileImages[0].toString()
        : 'https://picsum.photos/100';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 👤 1. 가이드 프로필 영역 (클릭 시 상세 정보 이동)
            InkWell(
              onTap: () {
                if (guide != null) {
                  // 💡 드디어 주석 해제! 가이드 상세 페이지로 날아갑니다.
                  debugPrint("🚀 가이드 상세 정보 페이지로 이동: ${guide['id']}");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GuideProfileDetailPage(
                        guideData: guide, // 👈 아까 가져온 가이드 정보 통째로 전달
                      ),
                    ),
                  );
                } else {
                  debugPrint("⚠️ 가이드 데이터가 없어서 이동할 수 없습니다.");
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: NetworkImage(profileUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "$nickname 가이드",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          Text(
                            "${TravelUtils.formatNationality(guide?['nationality'])} • ${guide?['age'] ?? '??'}세",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14, // 가독성을 위해 살짝 조정
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${offer['price'] ?? 0} P",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 32),

            // 💬 2. 가이드 메시지 영역
            const Text(
              "가이드의 한마디",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              offer['message'] ?? "제안 메시지가 없습니다.",
              style: const TextStyle(color: Colors.black87, height: 1.5),
            ),

            const SizedBox(height: 20),

            // 🔘 3. 하단 액션 버튼 (거절 / 수락)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final bool success = await _discoverService.rejectOffer(
                        offer['id'].toString(),
                      );
                      if (success) _loadOffers();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("거절"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (c) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      final roomId = await _discoverService.acceptOffer(
                        requestId: widget.requestId,
                        offerId: offer['id'].toString(),
                        guideId: offer['guide_id'].toString(),
                      );

                      if (mounted) Navigator.pop(context);

                      if (roomId != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomPage(
                              roomId: roomId,
                              targetUser: guide ?? {},
                            ),
                          ),
                        ).then((_) => _loadOffers());

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("🎉 매칭이 완료되어 채팅방이 열렸습니다!"),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.travelingBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "수락하기",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
