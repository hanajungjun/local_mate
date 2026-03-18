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

    // 1. 제안 개수 및 내 지원 여부 확인
    final List<dynamic> offersData = req['offers'] as List<dynamic>? ?? [];
    final int offerCount = offersData
        .where((o) => o['status'] != 'rejected')
        .length;

    // ✅ 서비스(DiscoverService)에서 가공해서 넘겨준 is_applied 사용
    final bool isApplied = req['is_applied'] ?? false;
    final bool isFull = offerCount >= 5;

    // 2. 작성자 프로필 이미지 처리
    final List<dynamic> profileImages =
        writer?['profile_image'] as List<dynamic>? ?? [];
    final String? profileUrl = profileImages.isNotEmpty
        ? profileImages[0].toString()
        : null;

    // 3. 날짜 및 시간 파싱 (travel_at 대응)
    final String travelAtRaw = req['travel_at'] ?? '';
    String displayDate = '날짜 미정';
    String displayTime = '';

    if (travelAtRaw.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(travelAtRaw).toLocal();
        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        displayDate =
            "${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} (${weekdays[dt.weekday - 1]})";
        displayTime =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (e) {
        displayDate = '날짜 형식 오류';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 유저 정보 및 예산
            Row(
              children: [
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
            const Divider(height: 24),

            // 위치 및 날짜/시간 정보 태그
            Row(
              children: [
                _buildInfoTag(
                  Icons.location_on_outlined,
                  req['location_name'] ?? '위치 미정',
                  Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildInfoTag(
                  Icons.calendar_today_outlined,
                  "$displayDate ${displayTime.isNotEmpty ? '· $displayTime' : ''}",
                  AppColors.travelingBlue,
                ),
              ],
            ),

            const SizedBox(height: 12),
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

            // 제안 버튼 (이미 지원했으면 오렌지색으로 잠금)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isFull || isApplied)
                    ? null
                    : () => _showOfferModal(context, req),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApplied
                      ? Colors.orange
                      : (isFull
                            ? Colors.grey.shade400
                            : AppColors.travelingBlue),
                  disabledBackgroundColor: isApplied
                      ? Colors.orange.withOpacity(0.5)
                      : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isApplied
                      ? "이미 제안을 보낸 공고입니다"
                      : (isFull
                            ? "제안 마감 ($offerCount/5)"
                            : "가이드 제안 보내기 ($offerCount/5)"),
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

  Widget _buildInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                        }
                      } catch (e) {
                        debugPrint("❌ 제안 푸시 발송 실패: $e");
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ 제안을 성공적으로 보냈습니다!")),
                      );
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
