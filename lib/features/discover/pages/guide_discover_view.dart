import 'package:flutter/material.dart';
import 'package:localmate/core/constants/app_colors.dart';
import 'package:localmate/services/discover_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuideDiscoverView extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRefresh;

  const GuideDiscoverView({
    super.key,
    required this.requests,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text("현재 올라온 여행 공고가 없어요."));
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(context, requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> req) {
    final writer = req['users'] as Map<String, dynamic>?;

    // ✅ [수정] 서비스에서 가져온 offers 리스트에서 rejected가 아닌 것만 카운트!
    final List<dynamic> offersData = req['offers'] as List<dynamic>? ?? [];
    final int offerCount = offersData
        .where((o) => o['status'] != 'rejected')
        .length;

    final bool isFull = offerCount >= 5;

    // ✅ 2. 프로필 이미지 URL 추출 로직 (안전하게)
    final List<dynamic> profileImages =
        writer?['profile_image'] as List<dynamic>? ?? [];
    final String? profileUrl = profileImages.isNotEmpty
        ? profileImages[0].toString()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ✅ 3. 형님 말씀대로 사진 없으면 회색 배경에 사람 아이콘!
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                      ? NetworkImage(profileUrl)
                      : null,
                  child: (profileUrl == null || profileUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // ✅ 4. 닉네임 null 체크 추가
                    "${writer?['nickname'] ?? '알 수 없는 유저'} • ${req['companion_type'] ?? '기타'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  "${req['budget'] ?? 0} P",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text(
              req['title'] ?? '제목 없음',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              req['content'] ?? '내용이 없습니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isFull ? null : () => _showOfferModal(context, req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFull
                      ? Colors.grey.shade400
                      : AppColors.travelingBlue,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isFull
                      ? "제안 마감 ($offerCount/5)"
                      : "가이드 제안 보내기 ($offerCount/5)",
                  style: const TextStyle(
                    color: Colors.white,
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

  void _showOfferModal(BuildContext context, Map<String, dynamic> req) {
    final TextEditingController priceController = TextEditingController(
      text: req['budget']?.toString(),
    );
    final TextEditingController messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "가이드 제안하기",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "'${req['title']}' 공고에 대한 제안입니다.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "제안 금액 (Point)",
                suffixText: "P",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "여행자에게 보낼 메시지",
                hintText: "어떤 코스로 가이드 해주실 건가요?",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final resultMessage = await DiscoverService().sendOffer(
                    requestId: req['id'],
                    price: int.tryParse(priceController.text) ?? 0,
                    message: messageController.text,
                  );

                  if (resultMessage == null) {
                    if (context.mounted) {
                      try {
                        // ✅ 여기서도 writer 정보가 null일 수 있으니 안전하게 처리
                        final writer = req['users'] as Map<String, dynamic>?;
                        final fcmToken = writer?['fcm_token'];

                        if (fcmToken != null) {
                          await Supabase.instance.client.functions.invoke(
                            'send-push',
                            body: {
                              'targetType': 'token',
                              'targetValue': fcmToken,
                              'title': '📩 새로운 가이드 제안!',
                              'body': "'${req['title']}' 공고에 가이드 제안이 도착했습니다.",
                              'data': {'type': 'offer', 'requestId': req['id']},
                            },
                          );
                          debugPrint("🚀 여행자에게 제안 푸시 발송 성공!");
                        }
                      } catch (e) {
                        debugPrint("❌ 제안 푸시 발송 실패: $e");
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ 제안을 성공적으로 보냈습니다!")),
                      );

                      // ✅ 제안 성공 후 부모 위젯 새로고침 호출 (0/5 -> 1/5 반영)
                      onRefresh();
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(resultMessage)));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.travelingBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "제안 전송하기",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
