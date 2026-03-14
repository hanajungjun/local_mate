import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:localmate/services/matching_service.dart';

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
          style: const TextStyle(fontSize: 16, color: Colors.black),
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
          // 거절된 제안 필터링
          final activeOffers = offers
              .where((o) => o['status'] != 'rejected')
              .toList();

          if (activeOffers.isEmpty) {
            return const Center(child: Text("아직 도착한 제안이 없어요."));
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
    final guide = offer['users'];
    final List<dynamic> profileImages = guide['profile_image'] ?? [];
    final String profileUrl = profileImages.isNotEmpty
        ? profileImages[0]
        : 'https://picsum.photos/100';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(profileUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${guide['nickname']} 가이드",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${guide['nationality']} • ${guide['age']}세",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${offer['price']} P",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // ❌ 거절 로직
                      final bool success = await _discoverService.rejectOffer(
                        offer['id'].toString(),
                      );
                      if (success) _loadOffers();
                    },
                    style: OutlinedButton.styleFrom(
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
                      // ✅ 수락 로직
                      final String? roomId = await _matchingService
                          .acceptGuideOffer(
                            offerId: offer['id'].toString(),
                            requestId: widget.requestId,
                            guideId: offer['guide_id'].toString(),
                            title: widget.requestTitle,
                          );

                      if (roomId != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("🎉 매칭 성공!")),
                        );
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
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
                      style: TextStyle(color: Colors.white),
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
